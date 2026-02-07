class CreateUserDailyStats < ActiveRecord::Migration[8.1]
  def change
    create_table :user_daily_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date
      t.integer :total_calories
      t.float :total_protein_g
      t.float :total_carbs_g
      t.float :total_fat_g
      t.timestamps
    end

    add_index :user_daily_stats, :date
    add_index :user_daily_stats, [:user_id, :date], unique: true
  end
end
