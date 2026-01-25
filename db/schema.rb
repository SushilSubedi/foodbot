# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_25_140809) do
  create_table "food_catalogs", force: :cascade do |t|
    t.integer "calories_per_serving"
    t.float "carbs_g"
    t.datetime "created_at"
    t.string "default_serving"
    t.float "fat_g"
    t.boolean "is_nepali", default: false
    t.string "name"
    t.float "protein_g"
    t.index ["name"], name: "index_food_catalogs_on_name", unique: true
  end

  create_table "food_items", force: :cascade do |t|
    t.integer "calories"
    t.float "carbs_g"
    t.datetime "created_at"
    t.float "fat_g"
    t.integer "meal_id", null: false
    t.string "name"
    t.float "protein_g"
    t.string "quantity"
    t.index ["meal_id"], name: "index_food_items_on_meal_id"
  end

  create_table "meals", force: :cascade do |t|
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.datetime "eaten_at"
    t.integer "estimated_calories"
    t.integer "health_rating"
    t.text "image_url"
    t.string "input_type"
    t.string "meal_type"
    t.text "raw_input"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "user_rating"
    t.index ["eaten_at"], name: "index_meals_on_eaten_at"
    t.index ["user_id"], name: "index_meals_on_user_id"
  end

  create_table "user_daily_stats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.integer "total_calories"
    t.float "total_carbs_g"
    t.float "total_fat_g"
    t.float "total_protein_g"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["date"], name: "index_user_daily_stats_on_date"
    t.index ["user_id", "date"], name: "index_user_daily_stats_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_user_daily_stats_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "daily_calorie_goal", default: 2000
    t.string "first_name", null: false
    t.boolean "is_premium", default: false
    t.string "language", default: "en"
    t.string "last_name"
    t.datetime "last_seen_at"
    t.text "pending_context"
    t.bigint "telegram_id", null: false
    t.string "timezone", default: "Asia/Kathmandu"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["telegram_id"], name: "index_users_on_telegram_id", unique: true
  end

  add_foreign_key "food_items", "meals"
  add_foreign_key "meals", "users"
  add_foreign_key "user_daily_stats", "users"
end
