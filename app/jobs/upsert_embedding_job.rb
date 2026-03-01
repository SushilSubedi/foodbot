class UpsertEmbeddingJob < ApplicationJob
  queue_as :embeddings

  def perform(record_type:, record_id:, kind:)
    record = record_type.constantize.find_by(id: record_id)
    return unless record

    Embeddings::UpsertService.new.upsert(record: record, kind: kind)
  end
end
