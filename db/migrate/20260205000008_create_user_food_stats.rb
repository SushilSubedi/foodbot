class CreateUserFoodStats < ActiveRecord::Migration[8.1]
  def change
    create_table :user_food_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.string :normalized_name, null: false
      t.integer :times_eaten, default: 0, null: false
      t.datetime :first_eaten_at
      t.datetime :last_eaten_at
      t.string :most_common_meal_type
      t.decimal :avg_calories, precision: 7, scale: 2
      t.decimal :avg_protein_g, precision: 6, scale: 2
      t.decimal :avg_carbs_g, precision: 6, scale: 2
      t.decimal :avg_fat_g, precision: 6, scale: 2
      t.decimal :avg_fiber_g, precision: 6, scale: 2
      t.integer :health_score
      t.json :portion_variations, default: [], null: false
      t.timestamps
    end

    add_index :user_food_stats, [:user_id, :normalized_name], unique: true
    add_index :user_food_stats, [:user_id, :times_eaten], order: { times_eaten: :desc }
    add_index :user_food_stats, [:user_id, :last_eaten_at]
    add_index :user_food_stats, :health_score
  end
end
