class FoodCatalog < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :calories_per_serving, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :nepali_foods, -> { where(is_nepali: true) }
  scope :by_name, ->(query) { where("name ILIKE ?", "%#{query}%") }
end
