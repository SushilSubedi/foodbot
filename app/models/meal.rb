class Meal < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :food_items, dependent: :destroy

  # Validations
  validates :meal_type, presence: true, inclusion: { in: %w[breakfast lunch dinner snack unknown] }
  validates :input_type, presence: true, inclusion: { in: %w[image text] }
  validates :eaten_at, presence: true
  validates :estimated_calories, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
