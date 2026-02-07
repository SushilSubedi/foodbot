class UserFoodStat < ApplicationRecord
  belongs_to :user

  validates :normalized_name, presence: true, uniqueness: { scope: :user_id }
  validates :times_eaten, numericality: { greater_than_or_equal_to: 0 }
  validates :health_score, numericality: { in: 1..100 }, allow_nil: true

  scope :frequently_eaten, -> { where("times_eaten >= ?", 3).order(times_eaten: :desc) }
  scope :recently_eaten, -> { order(last_eaten_at: :desc) }
  scope :recent, -> { where("last_eaten_at > ?", 30.days.ago) }
  scope :healthy, -> { where("health_score >= ?", 70) }
  scope :needs_improvement, -> { where("health_score < ?", 60) }

  def display_name
    normalized_name.to_s.titleize
  end

  def health_category
    case health_score
    when 80..100 then "🟢 Excellent"
    when 60...80 then "🟡 Good"
    when 40...60 then "🟠 Fair"
    else "🔴 Needs improvement"
    end
  end

  def summary
    "#{display_name}: eaten #{times_eaten}x, avg #{avg_calories&.round}cal #{health_category}"
  end

  def update_from_food_item(food_item, meal_type:)
    now = Time.current
    new_count = times_eaten + 1

    self.avg_calories = rolling_average(:avg_calories, food_item.calories, new_count)
    self.avg_protein_g = rolling_average(:avg_protein_g, food_item.protein_g, new_count)
    self.avg_carbs_g = rolling_average(:avg_carbs_g, food_item.carbs_g, new_count)
    self.avg_fat_g = rolling_average(:avg_fat_g, food_item.fat_g, new_count)

    self.times_eaten = new_count
    self.last_eaten_at = now
    self.first_eaten_at ||= now

    update_most_common_meal_type(meal_type)
    add_portion_variation(food_item.quantity)
    calculate_health_score

    save!
  end

  private

  def rolling_average(field, new_value, new_count)
    return new_value if new_count == 1
    current = send(field) || 0
    ((current * (new_count - 1)) + (new_value || 0)) / new_count.to_f
  end

  def update_most_common_meal_type(meal_type)
    return unless meal_type.present?

    @meal_type_counts ||= {}
    @meal_type_counts[meal_type] = (@meal_type_counts[meal_type] || 0) + 1
    self.most_common_meal_type = @meal_type_counts.max_by { |_, v| v }&.first || meal_type
  end

  def add_portion_variation(quantity)
    return unless quantity.present?

    variations = portion_variations || []
    variations << quantity unless variations.include?(quantity)
    self.portion_variations = variations.last(10)
  end

  def calculate_health_score
    return unless avg_calories && avg_protein_g && avg_carbs_g && avg_fat_g

    score = 50

    # Protein density bonus (higher protein per calorie = better)
    protein_ratio = avg_calories > 0 ? (avg_protein_g * 4 / avg_calories) * 100 : 0
    score += [protein_ratio * 2, 20].min

    # Penalize very high calorie items
    score -= 10 if avg_calories > 500
    score -= 20 if avg_calories > 800

    # Balance bonus
    total_macro_cals = (avg_protein_g * 4) + (avg_carbs_g * 4) + (avg_fat_g * 9)
    if total_macro_cals > 0
      fat_ratio = (avg_fat_g * 9) / total_macro_cals
      score -= 10 if fat_ratio > 0.40
    end

    self.health_score = [[score.round, 1].max, 100].min
  end
end
