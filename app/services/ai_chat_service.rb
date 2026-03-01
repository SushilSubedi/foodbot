class AiChatService
  def initialize(user:, message:)
    @user = user
    @message = message
  end

  def call
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: @message }
        ],
        temperature: 0.7,
        max_tokens: 500
      }
    )

    response.dig("choices", 0, "message", "content")
  rescue StandardError => e
    Rails.logger.error("[AiChatService] Error: #{e.message}")
    nil
  end

  private

  def system_prompt
    target_language = @user.language == "ne" ? "Nepali (Devanagari script)" : "English"

    <<~SYSTEM
      You are a friendly nutrition assistant for a Nepali food tracking app.
      
      LANGUAGE: Respond in #{target_language}.
      
      #{build_rag_context}
      
      GUIDELINES:
      - Be helpful, friendly, and culturally aware of Nepali cuisine
      - Give practical, actionable nutrition advice
      - Reference the user's eating history when relevant
      - NEVER recommend foods the user is allergic to
      - Respect dietary restrictions (vegetarian, vegan, etc.)
      - Align advice with user's health goal
      - Keep responses concise (2-3 short paragraphs max)
      - For food recommendations, suggest Nepali options when appropriate
      
      CAPABILITIES:
      - Answer nutrition questions
      - Suggest meals based on user preferences and history
      - Provide healthier alternatives
      - Explain benefits/risks of foods
      - Help with meal planning
      
      If asked about something outside nutrition/food, politely redirect to food topics.
    SYSTEM
  end

  def build_rag_context
    return basic_context unless semantic_search_enabled?

    builder = RagContextBuilder.new(user: @user)
    builder.build_for_recommendation(query: @message, limit: 5)
  rescue StandardError => e
    Rails.logger.warn("[AiChatService] RAG context failed: #{e.message}")
    basic_context
  end

  def basic_context
    return "" unless @user

    <<~CONTEXT
      USER CONTEXT:
      #{@user.ai_context_summary}
    CONTEXT
  end

  def semantic_search_enabled?
    Embedding.exists? && @user.present?
  end
end
