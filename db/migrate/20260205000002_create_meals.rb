class CreateMeals < ActiveRecord::Migration[8.1]
  def change
    create_table :meals do |t|
      t.references :user, null: false, foreign_key: true
      t.text :raw_input
      t.string :input_type
      t.text :image_url
      t.string :meal_type
      t.datetime :eaten_at
      t.integer :estimated_calories
      t.float :health_rating
      t.float :confidence_score
      t.integer :user_rating
      t.timestamps
    end

    add_index :meals, :eaten_at
  end
end
