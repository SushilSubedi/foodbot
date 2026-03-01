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

      Valid health_goal values: maintain, weight_loss, muscle_gain, diabetic_friendly
      Valid activity_level values: sedentary, light, moderate, very_active, extremely_active
      Valid portion_modifier range: 0.5 to 2.0

      If no preference signals are found, return {"signals": []}.

      Respond with valid JSON matching this schema:
      {
        "signals": [
          {
            "op": "set|add|remove",
            "field": "dietary_preferences.vegetarian|dietary_preferences.vegan|dietary_preferences.allergies|dietary_preferences.dislikes|health_goal|portion_modifier|activity_level",
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
    parts.join("\n")
  end
end
