class User < ApplicationRecord
  # Associations
  has_many :meals, dependent: :destroy
  has_many :user_daily_stats, dependent: :destroy

  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :language, inclusion: { in: %w[en ne], allow_nil: true }
  validates :timezone, presence: true

  def pending_context_data
    return nil if pending_context.blank?
    JSON.parse(pending_context, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  def set_pending_context(data)
    update!(pending_context: data.to_json)
  end

  def clear_pending_context
    update!(pending_context: nil)
  end

  def has_pending_context?
    pending_context.present?
  end
end
