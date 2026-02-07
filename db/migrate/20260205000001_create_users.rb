class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.bigint :telegram_id, null: false
      t.string :username
      t.string :first_name, null: false
      t.string :last_name
      t.string :language, default: "en"
      t.string :timezone, default: "Asia/Kathmandu"
      t.integer :daily_calorie_goal, default: 2000
      t.integer :daily_limit
      t.boolean :is_premium, default: false
      t.integer :images_processed_count
      t.date :last_process_date
      t.text :pending_context
      t.text :ai_context
      t.datetime :last_seen_at
      t.datetime :last_reminder_sent_at
      t.json :dietary_preferences, default: {}
      t.integer :age
      t.string :gender
      t.decimal :weight_kg, precision: 5, scale: 2
      t.decimal :height_cm, precision: 5, scale: 1
      t.string :activity_level, default: "sedentary", null: false
      t.string :health_goal, default: "maintain", null: false
      t.string :calorie_goal_mode, default: "manual", null: false
      t.integer :tdee_calories
      t.datetime :profile_completed_at
      t.boolean :intermittent_fasting_enabled, default: false, null: false
      t.string :fasting_schedule, default: "16_8"
      t.time :eating_window_start_local
      t.time :eating_window_end_local
      t.boolean :meal_reminders_enabled, default: false, null: false
      t.json :meal_reminder_settings, default: {}, null: false
      t.json :meal_timing_preferences, default: {}, null: false
      t.decimal :portion_modifier, precision: 3, scale: 2, default: 1.0
      t.timestamps
    end

    add_index :users, :telegram_id, unique: true
    add_index :users, :activity_level
    add_index :users, :health_goal
    add_index :users, :intermittent_fasting_enabled
  end
end
