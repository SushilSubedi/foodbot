class FoodCatalog < ApplicationRecord
  include Embeddable

  validates :name, presence: true, uniqueness: true
  validates :calories_per_serving, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :nepali_foods, -> { where(is_nepali: true) }
  scope :by_name, ->(query) { where("name ILIKE ?", "%#{query}%") }
  scope :by_any_name, ->(query) {
    where(
      "name ILIKE :q OR name_nepali ILIKE :q OR name_romanized ILIKE :q",
      q: "%#{query}%"
    )
  }

  def self.embedding_kind
    "food_catalog"
  end

  def self.embedding_trigger_attributes
    %w[name name_nepali name_romanized aliases description cuisine_tags
       calories_per_serving protein_g carbs_g fat_g is_nepali]
  end

  def all_names
    [name, name_nepali, name_romanized, *aliases].compact.uniq
  end
end
