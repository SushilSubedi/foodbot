class NutritionTrend < ApplicationRecord
  belongs_to :user

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :period_type, presence: true, inclusion: { in: %w[week month] }
  validates :period_start, uniqueness: { scope: [:user_id, :period_type] }

  scope :weekly, -> { where(period_type: "week") }
  scope :monthly, -> { where(period_type: "month") }
  scope :recent, -> { order(period_start: :desc) }

  def period_days
    (period_end - period_start).to_i + 1
  end

  def logging_consistency_percentage
    return 0 unless total_meals_logged && period_days > 0
    expected_meals = period_days * 3
    [(total_meals_logged.to_f / expected_meals * 100).round, 100].min
  end

  def top_food_names(limit = 5)
    (top_foods || []).first(limit).map { |f| f["name"] || f[:name] }
  end

  def macro_balance
    total = (avg_daily_protein_g || 0) * 4 +
            (avg_daily_carbs_g || 0) * 4 +
            (avg_daily_fat_g || 0) * 9
    return {} if total.zero?

    {
      protein_pct: ((avg_daily_protein_g || 0) * 4 / total * 100).round(1),
      carbs_pct: ((avg_daily_carbs_g || 0) * 4 / total * 100).round(1),
      fat_pct: ((avg_daily_fat_g || 0) * 9 / total * 100).round(1)
    }
  end
end
