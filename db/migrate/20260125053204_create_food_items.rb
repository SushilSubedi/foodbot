class CreateFoodItems < ActiveRecord::Migration[8.1]
  def change
    create_table :food_items do |t|
      t.references :meal, null: false, foreign_key: true
      t.string :name
      t.string :quantity
      t.integer :calories
      t.float :protein_g
      t.float :carbs_g
      t.float :fat_g

      t.timestamp :created_at
    end
  end
end
