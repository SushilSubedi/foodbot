class CreateNutritionTrends < ActiveRecord::Migration[8.1]
  def change
    create_table :nutrition_trends do |t|
      t.references :user, null: false, foreign_key: true
      t.string :period_type, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :total_meals_logged
      t.decimal :avg_daily_calories, precision: 7, scale: 2
      t.decimal :avg_daily_protein_g, precision: 6, scale: 2
      t.decimal :avg_daily_carbs_g, precision: 6, scale: 2
      t.decimal :avg_daily_fat_g, precision: 6, scale: 2
      t.integer :days_met_calorie_goal
      t.integer :days_met_protein_goal
      t.decimal :goal_adherence_percentage, precision: 5, scale: 2
      t.json :top_foods, default: [], null: false
      t.json :meal_type_breakdown, default: {}, null: false
      t.json :day_of_week_breakdown, default: {}, null: false
      t.timestamps
    end

    add_index :nutrition_trends, :period_start
    add_index :nutrition_trends, [:user_id, :period_start, :period_type], unique: true, name: "index_trends_on_user_period"
  end
end
