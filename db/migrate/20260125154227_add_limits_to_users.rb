class AddLimitsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :daily_limit, :integer
    add_column :users, :images_processed_count, :integer
    add_column :users, :last_process_date, :date
  end
end
