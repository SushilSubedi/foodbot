class CreateFoodItems < ActiveRecord::Migration[8.1]
  def change
    create_table :food_items do |t|
      t.references :meal, null: false, foreign_key: true
      t.string :name
      t.string :normalized_name
      t.string :quantity
      t.integer :calories
      t.float :protein_g
      t.float :carbs_g
      t.float :fat_g
      t.integer :glycemic_index
      t.string :glycemic_load
      t.boolean :diabetic_friendly, default: true
      t.boolean :vegetarian, default: true
      t.boolean :vegan, default: false
      t.string :food_category
      t.datetime :created_at
    end

    add_index :food_items, :normalized_name
    add_index :food_items, :food_category
    add_index :food_items, :glycemic_index
    add_index :food_items, :diabetic_friendly
  end
end
