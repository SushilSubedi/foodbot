class UserDailyStat < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :date, presence: true, uniqueness: { scope: :user_id }
  validates :total_calories, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
