class UserMemory < ApplicationRecord
  include Embeddable

  belongs_to :user

  def self.embedding_kind
    "user_memory"
  end

  def self.embedding_trigger_attributes
    %w[text]
  end

  validates :text, presence: true
  validates :source_message_id, uniqueness: { scope: :user_id }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :with_changes, -> { where("applied_changes != '{}'::jsonb") }
  scope :for_user, ->(user) { where(user: user) }

  def has_applied_changes?
    applied_changes.present? && applied_changes != {}
  end

  def display_text
    text.truncate(200)
  end
end
