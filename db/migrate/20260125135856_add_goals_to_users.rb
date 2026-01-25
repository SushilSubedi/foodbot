class AddGoalsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :daily_calorie_goal, :integer, default: 2000
  end
end
