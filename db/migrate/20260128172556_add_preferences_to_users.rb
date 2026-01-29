class AddPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dietary_preferences, :json, default: {}
    add_column :users, :portion_modifier, :decimal, precision: 3, scale: 2, default: 1.0
    add_column :users, :ai_context, :text
  end
end
