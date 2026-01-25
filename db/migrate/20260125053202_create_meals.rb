class CreateMeals < ActiveRecord::Migration[8.1]
  def change
    create_table :meals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :meal_type
      t.string :input_type
      t.text :image_url
      t.text :raw_input
      t.integer :estimated_calories
      t.float :confidence_score
      t.datetime :eaten_at

      t.timestamps
    end

    add_index :meals, :eaten_at
  end
end
