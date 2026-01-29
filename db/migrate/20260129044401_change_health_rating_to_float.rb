class ChangeHealthRatingToFloat < ActiveRecord::Migration[8.1]
  def change
    change_column :meals, :health_rating, :float
  end
end
