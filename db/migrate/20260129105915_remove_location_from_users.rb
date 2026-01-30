class RemoveLocationFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :city, :string
    remove_column :users, :area, :string
  end
end
