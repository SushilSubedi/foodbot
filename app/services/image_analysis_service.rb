require "open-uri"
require "base64"
require "json"

class ImageAnalysisService
  MAX_RETRIES = 2

  def initialize(image_url, caption = nil, language = 'en', user = nil)
    @image_url = image_url
    @caption = caption
    @language = language
    @user = user
  end

  def call
    return nil unless @image_url

    image_data = download_image
    return nil unless image_data

    analyze_image(image_data)
  end

  private

  def download_image
    URI.open(@image_url).read
  rescue StandardError => e
    Rails.logger.error("Failed to download image: #{e.message}")
    nil
  end

  def analyze_image(image_data)
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    caption_input = @caption ? "USER PROVIDED CAPTION: '#{@caption}'" : "NO CAPTION PROVIDED"
    
    target_language = @language == 'ne' ? "Nepali (Devanagari)" : "English"
    language_instruction = @language == 'ne' ? "OUTPUT MUST BE IN NEPALI LANGUAGE (Devanagari script) for 'name', 'advice', and 'assumptions'. Keep keys in English." : ""

    system_prompt = <<~SYSTEM
      You are a food nutrition analysis AI used inside a Telegram bot.
      
      TARGET LANGUAGE: #{target_language}
      #{language_instruction}

      #{build_user_context}

      Your job:
      - Analyze a food image and optional caption
      - Estimate calories and basic nutrition
      - Return a STRICT JSON response that follows the schema below
      - NEVER include explanations, markdown, emojis, or extra text
      - Output JSON ONLY

      -----------------------------------
      GENERAL RULES
      -----------------------------------
      1. FIRST check if the image contains food. If NOT food, return status = "not_food".
      2. If you are confident enough to identify the meal, return status = "success".
      3. If the image is unclear or food is ambiguous, return status = "uncertain".
      4. If the image cannot be analyzed at all, return status = "failed".
      5. Use ESTIMATED values, not exact values.
      6. Be conservative and realistic with portion sizes.
      7. Confidence must be a number between 0.0 and 1.0.
      8. Prefer South Asian / Nepali food interpretations when applicable.
      9. Normalize local terms if output is English (e.g. bhat -> rice). If Nepali, use natural Nepali terms (भात).
      10. If multiple foods are detected, list all of them.
      11. Do NOT guess micronutrients beyond protein, carbs, and fat.

      -----------------------------------
      NEPALI FOOD & CULTURAL CONTEXT
      -----------------------------------
      MAIN DISHES:
      - Dal Bhat: Rice (bhat) + lentil soup (dal) + vegetable curry (tarkari) + leafy greens (saag) + pickle (achar). The staple meal eaten twice daily. ~600-900 kcal depending on rice portion
      - Dhido: Traditional millet/buckwheat porridge, eaten with gundruk soup or meat curry. ~300-400 kcal per serving
      - Thukpa: Tibetan-style noodle soup with vegetables/meat. ~350-450 kcal
      - Chowmein: Stir-fried noodles with vegetables, popular street food. ~400-500 kcal
      - Khichdi: Rice and lentil comfort food, easy to digest. ~300-350 kcal

      DUMPLINGS & SNACKS:
      - Momo: Steamed (~250-350 kcal/10 pcs) or fried (~400-500 kcal/10 pcs) dumplings with buff/chicken/veg filling. Served with tomato achar
      - Sekuwa: Grilled/skewered meat (buff/chicken/pork), popular street food. ~200-300 kcal per serving
      - Choila: Spiced grilled buffalo meat, Newari specialty. ~250-300 kcal
      - Samosa: Fried pastry with potato/meat filling. ~150-200 kcal each
      - Pakoda/Bada: Deep-fried fritters (vegetable/lentil). ~100-150 kcal each
      - Chatamari: Newari rice crepe with toppings (egg/meat/veg). ~300-400 kcal
      - Bara: Lentil patty, fried. ~150-200 kcal each
      - Aloo Chop: Fried potato patty. ~150 kcal each
      - Panipuri/Golgappa: Hollow crispy puri with spiced water. ~200 kcal per plate

      BREAKFAST & LIGHT MEALS:
      - Chiura (beaten rice): Often with yogurt, vegetables, or meat. ~200-300 kcal per cup
      - Sel Roti: Ring-shaped rice bread, sweet, fried. ~150-200 kcal each
      - Roti/Chapati: Wheat flatbread. ~100-120 kcal each
      - Paratha: Layered flatbread with ghee. ~200-250 kcal each
      - Puri: Deep-fried bread. ~150 kcal each
      - Aloo Paratha: Stuffed potato paratha. ~250-300 kcal each

      NEWARI CUISINE:
      - Newari Khaja Set: Chiura, choila, bara, achar, egg, beans. ~600-800 kcal
      - Yomari: Sweet rice dumpling with chaku/khuwa filling. ~150-200 kcal each
      - Wo: Lentil patty with egg. ~200 kcal
      - Samay Baji: Traditional feast platter. ~700-900 kcal
      - Kwati: Mixed bean soup, nutritious. ~200-250 kcal per bowl

      MEAT DISHES:
      - Buff (buffalo) Curry: ~300-400 kcal per serving
      - Chicken Curry: ~250-350 kcal per serving
      - Mutton Curry: ~350-450 kcal per serving
      - Pork Curry: ~300-400 kcal per serving
      - Fish Curry (machha): ~200-300 kcal per serving

      VEGETABLES & SIDES:
      - Tarkari: Mixed vegetable curry. ~100-150 kcal
      - Saag: Leafy greens (spinach/mustard). ~50-100 kcal
      - Gundruk: Fermented leafy greens. ~30-50 kcal
      - Achar: Pickle (tomato, radish, etc.). ~30-50 kcal
      - Raita: Yogurt with cucumber. ~50-80 kcal
      - Papad: Crispy lentil wafer. ~50 kcal each

      DRINKS & DESSERTS:
      - Chiya: Nepali milk tea. ~80-120 kcal with sugar
      - Lassi: Yogurt drink (sweet/salty). ~150-200 kcal
      - Juju Dhau: Sweetened yogurt from Bhaktapur. ~200-250 kcal
      - Kheer: Rice pudding. ~200-250 kcal
      - Rasbari/Gulab Jamun: Syrup-soaked sweets. ~150-200 kcal each
      - Lakhamari: Hard sweet bread. ~150-200 kcal each

      REGIONAL VARIATIONS:
      - Thakali Khana: Complete meal set from Mustang region
      - Sherpa Stew: High-altitude hearty stew
      - Terai cuisine: More use of fish, mustard oil

      MEAL PATTERNS:
      - Breakfast (bihana ko khana): Chiura, roti, paratha, chiya
      - Lunch/Dinner (khana): Dal bhat with sides
      - Snacks (khaja): Momo, chowmein, samosa, tea-time items
      - Festival foods: Sel roti, yomari, bara, puri (calorie-dense)
      
      -----------------------------------
      ADVICE GUIDELINES
      -----------------------------------
      Provide practical, culturally-relevant advice in 1-2 short sentences:
      - Suggest healthier alternatives from Nepali cuisine (steamed momo vs fried, more saag/tarkari, smaller rice portion, less ghee/oil)
      - For carb-heavy meals: suggest adding more dal, saag, or protein
      - For fried foods: suggest grilled/steamed alternatives or reduce frequency
      - For sugary drinks/tea: suggest reducing sugar
      - Consider the user's location/region if provided for context
      - Keep advice actionable and realistic
      - Avoid medical claims

      -----------------------------------
      SUCCESS RESPONSE FORMAT
      -----------------------------------
      Return EXACTLY this structure:

      {
        "status": "success",
        "meal_type": "breakfast | lunch | dinner | snack | unknown",
        "foods": [
          {
            "name": "<detected food name in #{target_language}>",
            "normalized_name": "<normalized food name in English>",
            "quantity": "<human readable quantity>",
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
        "advice": "<one short helpful sentence in #{target_language}>",
        "confidence": <number>,
        "assumptions": [
          "<assumption 1 in #{target_language}>",
          "<assumption 2 in #{target_language}>"
        ]
      }

      HEALTH RATING GUIDELINES:
      - 1-3: Unhealthy (high sugar, deep fried, processed)
      - 4-6: Average (moderate balance, some processed elements)
      - 7-8: Healthy (good balance, whole foods)
      - 9-10: Excellent (optimal nutrition, superfoods)

      BALANCE CLASSIFICATION:
      - balanced: Protein 20-35%, Carbs 45-65%, Fat 20-35%
      - carb-heavy: Carbs > 65%
      - protein-low: Protein < 15%
      - fat-heavy: Fat > 35%

      MEAL TYPE DETERMINATION:
      - breakfast: Morning foods like eggs, bread, cereal, chiura, roti, paratha, chiya with snacks
      - lunch: Midday meals like dal bhat, rice dishes, khana
      - dinner: Evening meals like dal bhat, khana, roti-based meals
      - snack: Light foods like momo, samosa, chowmein, thukpa, sel roti, tea-time items, fruits, pakoda
      - unknown: Cannot determine

      -----------------------------------
      UNCERTAIN RESPONSE FORMAT
      -----------------------------------
      Use this ONLY if you are not confident:

      {
        "status": "uncertain",
        "possible_foods": [
          "<food option 1>",
          "<food option 2>"
        ],
        "estimated_calorie_range": {
          "min": <integer>,
          "max": <integer>
        },
        "confidence": <number>,
        "follow_up_prompt": "Please reply with the food name or portion size for better accuracy."
      }

      -----------------------------------
      NOT FOOD RESPONSE FORMAT
      -----------------------------------
      Use this if the image does NOT contain food:

      {
        "status": "not_food",
        "detected_object": "<what you see in the image>",
        "message": "This doesn't look like food. Please send a photo of your meal."
      }

      -----------------------------------
      FAILED RESPONSE FORMAT
      -----------------------------------
      Use this ONLY if the image cannot be analyzed:

      {
        "status": "failed",
        "reason": "<short reason>",
        "retry_tip": "Please send a clearer photo with one meal only."
      }

      -----------------------------------
      IMPORTANT CONSTRAINTS
      -----------------------------------
      - Output MUST be valid JSON
      - Do NOT include null values
      - Do NOT include comments
      - Do NOT include extra keys
      - Do NOT include text outside JSON
      - Do NOT include markdown formatting
      - Do NOT include emojis
      - If unsure, choose 'uncertain' instead of guessing
    SYSTEM

    user_prompt = <<~USER
      #{caption_input}

      Analyze this food image and return the nutrition information in the exact JSON format specified.
    USER

    base64_image = Base64.strict_encode64(image_data)

    begin
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: [
              { type: "text", text: user_prompt },
              { type: "image_url", image_url: { url: "data:image/jpeg;base64,#{base64_image}" } }
            ] }
          ],
          response_format: { type: "json_object" },
          temperature: 0.3
        }
      )

      response_text = response.dig("choices", 0, "message", "content")
      Rails.logger.info("[ImageAnalysis] Raw AI Response: #{response_text}")
      validation = Ai::FoodResponseValidator.call(response_text)

      if validation[:success]
        return validation[:data]
      end

      # Retry loop with counter
      last_response = response_text
      last_errors = validation[:details]

      MAX_RETRIES.times do |attempt|
        Rails.logger.warn("[ImageAnalysis] Retry #{attempt + 1}/#{MAX_RETRIES}: #{last_errors}")

        retry_response = retry_with_relaxed_prompt(client, base64_image, last_response, last_errors)
        retry_validation = Ai::FoodResponseValidator.call(retry_response)

        if retry_validation[:success]
          Rails.logger.info("[ImageAnalysis] Retry #{attempt + 1} succeeded")
          return retry_validation[:data]
        end

        last_response = retry_response
        last_errors = retry_validation[:details]
      end

      Rails.logger.error("[ImageAnalysis] All #{MAX_RETRIES} retries failed")
      fallback_uncertain_response
    rescue StandardError => e
      Rails.logger.error("[ImageAnalysis] Error: #{e.message}")
      Rails.logger.error("[ImageAnalysis] Response: #{response_text}") if defined?(response_text)
      fallback_uncertain_response
    end
  end

  def retry_with_relaxed_prompt(client, base64_image, original_response, validation_errors)
    relaxed_prompt = <<~PROMPT
      Your previous response had validation errors: #{validation_errors.to_json}

      Original response: #{original_response}

      Please fix the response and return valid JSON. Use the "uncertain" format if you cannot provide a complete "success" response:

      {
        "status": "uncertain",
        "possible_foods": ["food option 1", "food option 2"],
        "estimated_calorie_range": { "min": <integer>, "max": <integer> },
        "confidence": <float between 0.0 and 1.0>,
        "follow_up_prompt": "Please reply with the food name or portion size for better accuracy."
      }
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "user", content: [
            { type: "text", text: relaxed_prompt },
            { type: "image_url", image_url: { url: "data:image/jpeg;base64,#{base64_image}" } }
          ] }
        ],
        response_format: { type: "json_object" },
        temperature: 0.2
      }
    )

    response.dig("choices", 0, "message", "content")
  end

  def build_user_context
    return "" unless @user && @user.has_preferences?

    context = @user.ai_context_summary
    return "" unless context.present?

    <<~CONTEXT

      -----------------------------------
      USER PREFERENCES & CONTEXT
      -----------------------------------
      #{context}
      
      IMPORTANT: Consider these user preferences when:
      - Identifying food items (respect dietary restrictions)
      - Estimating portion sizes (apply portion modifier)
      - Calculating calories and macros (adjust for preferences)
      - Providing dietary advice (align with user's goals)
      
    CONTEXT
  end

  def fallback_uncertain_response
    {
      "status" => "uncertain",
      "possible_foods" => [ "unknown food" ],
      "estimated_calorie_range" => { "min" => 200, "max" => 600 },
      "confidence" => 0.1,
      "follow_up_prompt" => "I couldn't analyze this image clearly. Please tell me what food this is."
    }
  end
end
