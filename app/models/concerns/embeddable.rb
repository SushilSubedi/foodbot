module Embeddable
  extend ActiveSupport::Concern

  included do
    after_commit :schedule_embedding_update, on: [:create, :update], if: :should_update_embedding?
  end

  class_methods do
    def embedding_kind
      raise NotImplementedError, "Subclass must define embedding_kind"
    end

    def embedding_trigger_attributes
      []
    end
  end

  def schedule_embedding_update
    UpsertEmbeddingJob.perform_later(
      record_type: self.class.name,
      record_id: id,
      kind: self.class.embedding_kind
    )
  end

  def embedding_record
    Embedding.find_by(
      record_type: self.class.name,
      record_id: id,
      kind: self.class.embedding_kind
    )
  end

  private

  def should_update_embedding?
    return true if previously_new_record?

    trigger_attrs = self.class.embedding_trigger_attributes
    return true if trigger_attrs.empty?

    trigger_attrs.any? { |attr| saved_change_to_attribute?(attr) }
  end
end
