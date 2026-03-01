module Embeddings
  class UpsertService
    def initialize(openai_client: OpenaiClient.new)
      @openai_client = openai_client
    end

    def upsert(record:, kind:)
      content = TextBuilder.for(record, kind: kind)
      embedding_record = Embedding.find_or_initialize_for(record: record, kind: kind)

      return embedding_record unless embedding_record.new_record? || embedding_record.content_changed?(content)

      embedding_vector = @openai_client.embed(content)
      metadata = build_metadata(record, kind)

      embedding_record.update_embedding!(
        content: content,
        embedding_vector: embedding_vector,
        metadata: metadata
      )

      embedding_record
    end

    def upsert_batch(records:, kind:)
      records_with_content = records.map do |record|
        {
          record: record,
          content: TextBuilder.for(record, kind: kind)
        }
      end

      records_needing_update = records_with_content.select do |item|
        embedding = Embedding.find_or_initialize_for(record: item[:record], kind: kind)
        embedding.new_record? || embedding.content_changed?(item[:content])
      end

      return [] if records_needing_update.empty?

      texts = records_needing_update.map { |item| item[:content] }
      embedding_vectors = @openai_client.embed_batch(texts)

      records_needing_update.zip(embedding_vectors).map do |item, vector|
        record = item[:record]
        content = item[:content]
        embedding_record = Embedding.find_or_initialize_for(record: record, kind: kind)
        metadata = build_metadata(record, kind)

        embedding_record.update_embedding!(
          content: content,
          embedding_vector: vector,
          metadata: metadata
        )

        embedding_record
      end
    end

    private

    def build_metadata(record, kind)
      case kind
      when "food_catalog"
        {
          name: record.name,
          is_nepali: record.is_nepali?,
          calories: record.calories_per_serving
        }
      when "user_food_stat"
        {
          user_id: record.user_id,
          normalized_name: record.normalized_name,
          times_eaten: record.times_eaten,
          health_score: record.health_score
        }
      when "user_profile"
        {
          user_id: record.id,
          health_goal: record.health_goal,
          allergies: record.allergies,
          dislikes: record.dislikes
        }
      when "user_memory"
        {
          user_id: record.user_id,
          source: record.source,
          source_message_id: record.source_message_id
        }
      else
        {}
      end
    end
  end
end
