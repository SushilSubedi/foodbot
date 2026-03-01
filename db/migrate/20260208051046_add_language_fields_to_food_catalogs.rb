class AddLanguageFieldsToFoodCatalogs < ActiveRecord::Migration[8.1]
  def change
    add_column :food_catalogs, :name_nepali, :string
    add_column :food_catalogs, :name_romanized, :string
    add_column :food_catalogs, :aliases, :jsonb, null: false, default: []
    add_column :food_catalogs, :description, :text
    add_column :food_catalogs, :cuisine_tags, :jsonb, null: false, default: []

    add_index :food_catalogs, :name_nepali
    add_index :food_catalogs, :name_romanized
  end
end
