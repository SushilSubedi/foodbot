class RefreshUserProfileEmbeddingJob < ApplicationJob
  queue_as :embeddings

  def perform(user_id:)
    user = User.find_by(id: user_id)
    return unless user

    Embeddings::UpsertService.new.upsert(record: user, kind: "user_profile")
  end
end
