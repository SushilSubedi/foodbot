class TextClarificationService
  def initialize(text:, image_url:, possible_foods:, calorie_range:)
    @text = text
    @image_url = image_url
    @possible_foods = possible_foods
    @calorie_range = calorie_range
  end

  def call
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    system_prompt = <<~SYSTEM
      You are a food nutrition analysis AI. The user previously sent a food image that was unclear.
      You identified possible foods: #{@possible_foods.join(', ')}
      Estimated calorie range: #{@calorie_range['min']}-#{@calorie_range['max']} kcal

      The user has now clarified with: "#{@text}"

      Based on this clarification, provide a complete nutrition analysis.
      Return STRICT JSON only, no markdown or extra text.

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
        "advice": "<one short helpful sentence>",
        "confidence": <number between 0.0 and 1.0>,
        "assumptions": ["<assumption>"]
      }
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
end
