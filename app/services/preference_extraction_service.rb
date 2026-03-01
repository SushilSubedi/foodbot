class PreferenceExtractionService
  EXTRACTION_SCHEMA = {
    type: "object",
    properties: {
      signals: {
        type: "array",
        items: {
          type: "object",
          properties: {
            op: { type: "string", enum: %w[set add remove] },
            field: { type: "string", enum: %w[
              dietary_preferences.vegetarian
              dietary_preferences.vegan
              dietary_preferences.allergies
              dietary_preferences.dislikes
              health_goal
              portion_modifier
              activity_level
              language
              age
              weight_kg
              height_cm
              gender
              daily_calorie_goal
              intermittent_fasting
            ] },
            value: {},
            confidence: { type: "number" },
            evidence: { type: "string" }
          },
          required: %w[op field value confidence evidence]
        }
      }
    },
    required: %w[signals]
  }.freeze

  CONFIDENCE_THRESHOLD = 0.7

  def initialize(user:, message:)
    @user = user
    @message = message
  end

  def call
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: @message }
        ],
        temperature: 0.1,
        max_tokens: 500,
        response_format: { type: "json_object" }
      }
    )

    raw = response.dig("choices", 0, "message", "content")
    return { "signals" => [] } unless raw

    parsed = JSON.parse(raw)
    filter_by_confidence(parsed)
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error("[PreferenceExtractionService] Error: #{e.message}")
    { "signals" => [] }
  end

  private

  def client
    @client ||= OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  end

  def filter_by_confidence(result)
    signals = result["signals"] || []
    result["signals"] = signals.select { |s| (s["confidence"] || 0) >= CONFIDENCE_THRESHOLD }
    result
  end

  def system_prompt
    <<~PROMPT
      You are a preference extraction system for a Nepali food tracking bot.
      Analyze the user's message and extract any dietary preferences, health goals, or lifestyle signals.

      Current user profile:
      #{current_profile_summary}

      RULES:
      - Only extract CLEAR, PERMANENT preference signals (not transient statements)
      - "I'm not eating rice today" is transient - do NOT extract
      - "I don't eat meat" is permanent - extract as vegetarian=true
      - "I'm allergic to peanuts" - extract as allergy add
      - "I hate onions" - extract as dislike add
      - "I want to lose weight" - extract as health_goal=weight_loss
      - "I eat big portions" - extract as portion_modifier=1.3
      - "I'm very active" - extract as activity_level=very_active
      - "I'm no longer vegetarian" - extract as vegetarian=false (remove)
      - "I can eat dairy now" - extract as allergy remove for dairy
      - Handle Nepali language messages too (e.g., "म मासु खाँदिन" = I don't eat meat)
      - Be conservative: if unsure, don't extract
      - Set confidence between 0.0 and 1.0

      BIOMETRICS:
      - "I'm 25 years old" or "मेरो उमेर २५ वर्ष हो" - extract as age=25
      - "I weigh 70 kg" or "मेरो तौल ७० केजी" - extract as weight_kg=70
      - "I'm 175 cm tall" or "5 feet 8 inches" - extract as height_cm (convert feet/inches to cm)
      - "I'm male/female" or "म पुरुष/महिला हुँ" - extract as gender=male/female/other

      LANGUAGE:
      - If the ENTIRE message is written in Nepali (Devanagari script), extract language="ne"
      - If the ENTIRE message is written in English, extract language="en"
      - Only extract if user's current language doesn't match the message language

      CALORIE GOAL:
      - "I want to eat 1800 calories a day" - extract as daily_calorie_goal=1800
      - "My daily target is 2000 kcal" - extract as daily_calorie_goal=2000
      - Valid range: 800-5000

      INTERMITTENT FASTING:
      - "I do 16:8 fasting" - extract as intermittent_fasting with value {"enabled": true, "schedule": "16_8"}
      - "I do intermittent fasting, eating from 12 to 8" - extract as intermittent_fasting with value {"enabled": true, "schedule": "custom", "start": "12:00", "end": "20:00"}
      - "I stopped fasting" - extract as intermittent_fasting with value {"enabled": false}
      - Valid schedules: 16_8, 14_10, 18_6, 20_4, custom

      Valid health_goal values: maintain, weight_loss, muscle_gain, diabetic_friendly
      Valid activity_level values: sedentary, light, moderate, very_active, extremely_active
      Valid portion_modifier range: 0.5 to 2.0
      Valid gender values: male, female, other

      If no preference signals are found, return {"signals": []}.

      Respond with valid JSON matching this schema:
      {
        "signals": [
          {
            "op": "set|add|remove",
            "field": "one of the valid field names listed above",
            "value": "<value>",
            "confidence": 0.0-1.0,
            "evidence": "relevant quote from message"
          }
        ]
      }
    PROMPT
  end

  def current_profile_summary
    parts = []
    parts << "Vegetarian: #{@user.is_vegetarian?}"
    parts << "Vegan: #{@user.is_vegan?}"
    parts << "Allergies: #{@user.allergies.join(', ')}" if @user.allergies.any?
    parts << "Dislikes: #{@user.dislikes.join(', ')}" if @user.dislikes.any?
    parts << "Health goal: #{@user.health_goal}"
    parts << "Activity level: #{@user.activity_level}"
    parts << "Portion modifier: #{@user.portion_modifier}"
    parts << "Language: #{@user.language || 'en'}"
    parts << "Age: #{@user.age || 'Not set'}"
    parts << "Weight: #{@user.weight_kg ? "#{@user.weight_kg}kg" : 'Not set'}"
    parts << "Height: #{@user.height_cm ? "#{@user.height_cm}cm" : 'Not set'}"
    parts << "Gender: #{@user.gender || 'Not set'}"
    parts << "Daily calorie goal: #{@user.daily_calorie_goal || 2000}"
    parts << "Intermittent fasting: #{@user.intermittent_fasting_enabled? ? "enabled (#{@user.fasting_schedule})" : 'disabled'}"
    parts.join("\n")
  end
end
