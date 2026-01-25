class CalculateDailyStatsJob < ApplicationJob
  queue_as :default

  def perform(user_id, date)
    user = User.find(user_id)
    meals = user.meals.includes(:food_items).where('DATE(eaten_at) = ?', date)
    
    return if meals.empty?
    
    total_calories = meals.sum(:estimated_calories)
    
    # Sum from food_items for accurate macro totals
    all_food_items = meals.flat_map(&:food_items)
    total_protein = all_food_items.sum(&:protein_g)
    total_carbs = all_food_items.sum(&:carbs_g)
    total_fat = all_food_items.sum(&:fat_g)
    
    # Find or create daily stat record
    stat = user.user_daily_stats.find_or_initialize_by(date: date)
    stat.update!(
      total_calories: total_calories,
      total_protein_g: total_protein,
      total_carbs_g: total_carbs,
      total_fat_g: total_fat
    )
    
    Rails.logger.info("[CalculateDailyStats] Updated stats for user #{user_id} on #{date}: #{total_calories} kcal")
  end
end
