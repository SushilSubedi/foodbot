namespace :user_food_stats do
  desc "Backfill user food stats from existing meals"
  task backfill: :environment do
    count = 0
    Meal.includes(:food_items).find_each do |meal|
      meal.food_items.each do |food_item|
        UserFoodStatsUpdaterService.new(food_item).update_stats
        count += 1
      end
    end

    puts "Backfilled user food stats from #{count} food items."
  end
end
