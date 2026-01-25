require "open-uri"
require "base64"
require "json"

class ImageAnalysisService
  MAX_RETRIES = 2

  def initialize(image_url, caption = nil)
    @image_url = image_url
    @caption = caption
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

    system_prompt = <<~SYSTEM
      You are a food nutrition analysis AI used inside a Telegram bot.

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
      5. Be conservative and realistic with portion sizes.
      6. Confidence must be a number between 0.0 and 1.0.
      7. Prefer South Asian / Nepali food interpretations when applicable.
      8. Normalize local terms:
         - bhat → rice
         - dal bhat → dal bhat
         - tarkari → vegetable curry
         - achar → pickle
      9. If multiple foods are detected, list all of them.
      10. Do NOT guess micronutrients beyond protein, carbs, and fat.

      -----------------------------------
      SUCCESS RESPONSE FORMAT
      -----------------------------------
      Return EXACTLY this structure:

      {
        "status": "success",
        "meal_type": "breakfast | lunch | dinner | snack | unknown",
        "foods": [
          {
            "name": "<detected food name>",
            "normalized_name": "<normalized food name>",
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
        "advice": "<one short helpful sentence>",
        "confidence": <number>,
        "assumptions": [
          "<assumption 1>",
          "<assumption 2>"
        ]
      }

      BALANCE CLASSIFICATION:
      - balanced: Protein 20-35%, Carbs 45-65%, Fat 20-35%
      - carb-heavy: Carbs > 65%
      - protein-low: Protein < 15%
      - fat-heavy: Fat > 35%

      MEAL TYPE DETERMINATION:
      - breakfast: Morning foods like eggs, bread, cereal, chiura
      - lunch: Midday meals like dal bhat, rice dishes
      - dinner: Evening meals, similar to lunch
      - snack: Light foods like momo, samosa, fruits
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
