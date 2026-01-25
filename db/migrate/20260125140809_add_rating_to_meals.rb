class AddRatingToMeals < ActiveRecord::Migration[8.1]
  def change
    add_column :meals, :health_rating, :integer
    add_column :meals, :user_rating, :integer
  end
end
