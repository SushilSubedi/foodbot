class TextClarificationService
  def initialize(text:, image_url:, possible_foods:, calorie_range:, user: nil)
    @text = text
    @image_url = image_url
    @possible_foods = possible_foods
    @calorie_range = calorie_range
    @user = user
  end

  def call
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    system_prompt = <<~SYSTEM
      You are a food nutrition analysis AI. The user previously sent a food image that was unclear.
      You identified possible foods: #{@possible_foods.join(', ')}
      Estimated calorie range: #{@calorie_range['min']}-#{@calorie_range['max']} kcal

      The user has now clarified with: "#{@text}"

      #{build_user_context}

      Based on this clarification, provide a complete nutrition analysis.
      Return STRICT JSON only, no markdown or extra text.
      
      IMPORTANT: BEVERAGES (drinks) are valid food items to analyze!
      - If user mentions beverages (tea, coffee, water, beer, juice, soft drinks, etc.), analyze them
      - Beverages should have status = "success", NOT "not_food"
      - Use meal_type = "snack" for beverages unless clearly part of a meal
      
      IMPORTANT BEVERAGE CONTEXT:
      - If user mentions alcohol (beer, raksi, tongba, chhyang, whiskey, wine, etc.): health_rating must be 2-4 (very unhealthy)
      - Soft drinks/soda: health_rating 3-4 (unhealthy, high sugar)
      - Water: 0 calories, health_rating 10 (most healthy)
      - Chiya with sugar: ~80-120 kcal, without sugar: ~40-60 kcal
      - For alcohol, advise limiting/avoiding consumption in your advice
      - Suggest healthy drink alternatives: water, buttermilk, coconut water

      Return this exact structure:
      {
        "status": "success",
        "meal_type": "breakfast | lunch | dinner | snack | unknown",
        "foods": [
          {
            "name": "<food name>",
            "normalized_name": "<normalized name>",
            "quantity": "<quantity>",
            "portion_size": "small | medium | large | unknown",
            "calories": <integer>,
            "protein_g": <number>,
            "carbs_g": <number>,
            "fat_g": <number>
          }
        ],
        "total": {
          "calories": <integer>,
          "protein_g": <number>,
          "carbs_g": <number>,
          "fat_g": <number>
        },
        "balance": "balanced | carb-heavy | protein-low | fat-heavy",
        "health_rating": <number between 1.0 and 10.0>,
        "advice": "<one short helpful sentence>",
        "confidence": <number between 0.0 and 1.0>,
        "assumptions": ["<assumption>"]
      }

      HEALTH RATING GUIDELINES:
      - 1-3: Unhealthy (alcohol, high sugar drinks, deep fried, processed)
      - 4-6: Average (moderate balance, some processed elements)
      - 7-8: Healthy (good balance, whole foods)
      - 9-10: Excellent (optimal nutrition, superfoods)
      
      SPECIFIC RULES:
      - Alcoholic beverages: 2-4 rating (very unhealthy)
      - Soft drinks/soda: 3-4 rating (unhealthy)
      - Water/herbal tea: 9-10 rating (very healthy)
    SYSTEM

    begin
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: "Analyze the food based on user clarification: #{@text}" }
          ],
          response_format: { type: "json_object" },
          temperature: 0.3
        }
      )

      response_text = response.dig("choices", 0, "message", "content")
      validation = Ai::FoodResponseValidator.call(response_text)

      if validation[:success]
        validation[:data]
      else
        Rails.logger.error("TextClarification validation failed: #{validation[:details]}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("TextClarificationService failed: #{e.message}")
      nil
    end
  end

  private

  def build_user_context
    return "" unless @user

    rag_context = build_rag_context
    return "" if rag_context.blank?

    <<~CONTEXT

      USER CONTEXT (RAG-Enhanced):
      #{rag_context}
      
      IMPORTANT: 
      - NEVER suggest foods the user is allergic to
      - Respect dietary restrictions (vegetarian, vegan, etc.)
      - Consider user's health goal when giving advice
      - Reference similar foods from user's history if relevant
      
    CONTEXT
  end

  def build_rag_context
    return @user.ai_context_summary unless semantic_search_enabled?

    builder = RagContextBuilder.new(user: @user)
    query = [@text, @possible_foods].flatten.compact.join(" ")

    builder.build(
      query: query,
      semantic_results: fetch_semantic_results(query),
      include_eating_patterns: true
    )
  rescue StandardError => e
    Rails.logger.warn("[TextClarification] RAG context failed: #{e.message}")
    @user.ai_context_summary
  end

  def fetch_semantic_results(query)
    return [] unless semantic_search_enabled?

    SemanticFoodSearch.new(user: @user).search(
      query: query,
      limit: 5,
      include_catalog: true,
      include_personal: true
    )
  rescue StandardError => e
    Rails.logger.warn("[TextClarification] Semantic search failed: #{e.message}")
    []
  end

  def semantic_search_enabled?
    Embedding.exists? && @user.present?
  end
end
