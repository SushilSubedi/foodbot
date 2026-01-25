class FoodItem < ApplicationRecord
  # Associations
  belongs_to :meal

  # Validations
  validates :name, presence: true
  validates :calories, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
