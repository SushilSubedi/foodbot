class CreateFoodCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :food_catalogs do |t|
      t.string :name
      t.string :default_serving
      t.integer :calories_per_serving
      t.float :protein_g
      t.float :carbs_g
      t.float :fat_g
      t.boolean :is_nepali, default: false

      t.timestamp :created_at
    end
    add_index :food_catalogs, :name, unique: true
  end
end
