class Embedding < ApplicationRecord
  SUPPORTED_KINDS = %w[food_catalog user_food_stat user_profile user_memory].freeze
  DEFAULT_MODEL = "text-embedding-3-small".freeze
  DEFAULT_DIMENSIONS = 1536

  belongs_to :record, polymorphic: true, optional: true

  validates :record_type, presence: true
  validates :record_id, presence: true
  validates :kind, presence: true, inclusion: { in: SUPPORTED_KINDS }
  validates :model, presence: true
  validates :dimensions, presence: true
  validates :content, presence: true
  validates :content_sha, presence: true
  validates :embedding, presence: true

  has_neighbors :embedding

  scope :for_kind, ->(kind) { where(kind: kind) }
  scope :for_user, ->(user_id) { where("metadata->>'user_id' = ?", user_id.to_s) }

  def self.find_or_initialize_for(record:, kind:)
    find_or_initialize_by(
      record_type: record.class.name,
      record_id: record.id,
      kind: kind
    )
  end

  def self.nearest_for_kind(embedding_vector, kind:, limit: 10, user_id: nil)
    scope = for_kind(kind)
    scope = scope.for_user(user_id) if user_id.present?
    scope.nearest_neighbors(:embedding, embedding_vector, distance: "cosine").limit(limit)
  end

  def content_changed?(new_content)
    compute_sha(new_content) != content_sha
  end

  def update_embedding!(content:, embedding_vector:, metadata: {})
    self.content = content
    self.content_sha = compute_sha(content)
    self.embedding = embedding_vector
    self.model = DEFAULT_MODEL
    self.dimensions = DEFAULT_DIMENSIONS
    self.metadata = metadata
    self.embedded_at = Time.current
    save!
  end

  private

  def compute_sha(text)
    Digest::SHA256.hexdigest("#{text}:#{DEFAULT_MODEL}:#{DEFAULT_DIMENSIONS}")
  end
end
