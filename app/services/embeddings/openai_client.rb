module Embeddings
  class OpenaiClient
    MODEL = "text-embedding-3-small".freeze
    DIMENSIONS = 1536

    def initialize
      @client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
    end

    def embed(text)
      response = @client.embeddings(
        parameters: {
          model: MODEL,
          input: text,
          dimensions: DIMENSIONS
        }
      )

      response.dig("data", 0, "embedding")
    end

    def embed_batch(texts)
      return [] if texts.empty?

      response = @client.embeddings(
        parameters: {
          model: MODEL,
          input: texts,
          dimensions: DIMENSIONS
        }
      )

      response["data"].sort_by { |d| d["index"] }.map { |d| d["embedding"] }
    end
  end
end
