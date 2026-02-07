class UpdateUserFoodStatsJob < ApplicationJob
  queue_as :default

  def perform(meal_id)
    meal = Meal.find_by(id: meal_id)
    return unless meal

    meal.food_items.each do |food_item|
      UserFoodStatsUpdaterService.new(food_item).update_stats
    end
  rescue StandardError => e
    Rails.logger.error("Failed to update food stats for meal #{meal_id}: #{e.message}")
  end
end
