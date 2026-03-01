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

ActiveRecord::Schema[8.1].define(version: 2026_02_10_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "embeddings", force: :cascade do |t|
    t.text "content", null: false
    t.string "content_sha", null: false
    t.datetime "created_at", null: false
    t.integer "dimensions", null: false
    t.datetime "embedded_at"
    t.vector "embedding", limit: 1536, null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "model", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["content_sha"], name: "index_embeddings_on_content_sha"
    t.index ["embedding"], name: "idx_embeddings_food_catalog_hnsw", opclass: :vector_cosine_ops, where: "((kind)::text = 'food_catalog'::text)", using: :hnsw
    t.index ["embedding"], name: "idx_embeddings_user_food_stat_hnsw", opclass: :vector_cosine_ops, where: "((kind)::text = 'user_food_stat'::text)", using: :hnsw
    t.index ["embedding"], name: "idx_embeddings_user_memory_hnsw", opclass: :vector_cosine_ops, where: "((kind)::text = 'user_memory'::text)", using: :hnsw
    t.index ["embedding"], name: "idx_embeddings_user_profile_hnsw", opclass: :vector_cosine_ops, where: "((kind)::text = 'user_profile'::text)", using: :hnsw
    t.index ["kind"], name: "index_embeddings_on_kind"
    t.index ["record_type", "record_id", "kind"], name: "idx_embeddings_on_record_and_kind", unique: true
  end

  create_table "food_catalogs", force: :cascade do |t|
    t.jsonb "aliases", default: [], null: false
    t.integer "calories_per_serving"
    t.float "carbs_g"
    t.datetime "created_at"
    t.jsonb "cuisine_tags", default: [], null: false
    t.string "default_serving"
    t.text "description"
    t.float "fat_g"
    t.boolean "is_nepali", default: false
    t.string "name"
    t.string "name_nepali"
    t.string "name_romanized"
    t.float "protein_g"
    t.index ["name"], name: "index_food_catalogs_on_name", unique: true
    t.index ["name_nepali"], name: "index_food_catalogs_on_name_nepali"
    t.index ["name_romanized"], name: "index_food_catalogs_on_name_romanized"
  end

  create_table "food_items", force: :cascade do |t|
    t.integer "calories"
    t.float "carbs_g"
    t.datetime "created_at"
    t.boolean "diabetic_friendly", default: true
    t.float "fat_g"
    t.string "food_category"
    t.integer "glycemic_index"
    t.string "glycemic_load"
    t.bigint "meal_id", null: false
    t.string "name"
    t.string "normalized_name"
    t.float "protein_g"
    t.string "quantity"
    t.boolean "vegan", default: false
    t.boolean "vegetarian", default: true
    t.index ["diabetic_friendly"], name: "index_food_items_on_diabetic_friendly"
    t.index ["food_category"], name: "index_food_items_on_food_category"
    t.index ["glycemic_index"], name: "index_food_items_on_glycemic_index"
    t.index ["meal_id"], name: "index_food_items_on_meal_id"
    t.index ["normalized_name"], name: "index_food_items_on_normalized_name"
  end

  create_table "meals", force: :cascade do |t|
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.datetime "eaten_at"
    t.integer "estimated_calories"
    t.float "health_rating"
    t.text "image_url"
    t.string "input_type"
    t.string "meal_type"
    t.text "raw_input"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "user_rating"
    t.index ["eaten_at"], name: "index_meals_on_eaten_at"
    t.index ["user_id"], name: "index_meals_on_user_id"
  end

  create_table "nutrition_trends", force: :cascade do |t|
    t.decimal "avg_daily_calories", precision: 7, scale: 2
    t.decimal "avg_daily_carbs_g", precision: 6, scale: 2
    t.decimal "avg_daily_fat_g", precision: 6, scale: 2
    t.decimal "avg_daily_protein_g", precision: 6, scale: 2
    t.datetime "created_at", null: false
    t.json "day_of_week_breakdown", default: {}, null: false
    t.integer "days_met_calorie_goal"
    t.integer "days_met_protein_goal"
    t.decimal "goal_adherence_percentage", precision: 5, scale: 2
    t.json "meal_type_breakdown", default: {}, null: false
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.string "period_type", null: false
    t.json "top_foods", default: [], null: false
    t.integer "total_meals_logged"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["period_start"], name: "index_nutrition_trends_on_period_start"
    t.index ["user_id", "period_start", "period_type"], name: "index_trends_on_user_period", unique: true
    t.index ["user_id"], name: "index_nutrition_trends_on_user_id"
  end

  create_table "promo_code_redemptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "promo_code_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["promo_code_id"], name: "index_promo_code_redemptions_on_promo_code_id"
    t.index ["user_id"], name: "index_promo_code_redemptions_on_user_id"
  end

  create_table "promo_codes", force: :cascade do |t|
    t.boolean "active"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.integer "limit_increase"
    t.integer "max_uses"
    t.datetime "updated_at", null: false
    t.integer "uses_count"
  end

  create_table "user_daily_stats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.integer "total_calories"
    t.float "total_carbs_g"
    t.float "total_fat_g"
    t.float "total_protein_g"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["date"], name: "index_user_daily_stats_on_date"
    t.index ["user_id", "date"], name: "index_user_daily_stats_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_user_daily_stats_on_user_id"
  end

  create_table "user_food_stats", force: :cascade do |t|
    t.decimal "avg_calories", precision: 7, scale: 2
    t.decimal "avg_carbs_g", precision: 6, scale: 2
    t.decimal "avg_fat_g", precision: 6, scale: 2
    t.decimal "avg_fiber_g", precision: 6, scale: 2
    t.decimal "avg_protein_g", precision: 6, scale: 2
    t.datetime "created_at", null: false
    t.datetime "first_eaten_at"
    t.integer "health_score"
    t.datetime "last_eaten_at"
    t.string "most_common_meal_type"
    t.string "normalized_name", null: false
    t.json "portion_variations", default: [], null: false
    t.integer "times_eaten", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["health_score"], name: "index_user_food_stats_on_health_score"
    t.index ["user_id", "last_eaten_at"], name: "index_user_food_stats_on_user_id_and_last_eaten_at"
    t.index ["user_id", "normalized_name"], name: "index_user_food_stats_on_user_id_and_normalized_name", unique: true
    t.index ["user_id", "times_eaten"], name: "index_user_food_stats_on_user_id_and_times_eaten", order: { times_eaten: :desc }
    t.index ["user_id"], name: "index_user_food_stats_on_user_id"
  end

  create_table "user_memories", force: :cascade do |t|
    t.jsonb "applied_changes", default: {}
    t.decimal "confidence", precision: 3, scale: 2
    t.datetime "created_at", null: false
    t.jsonb "extraction", default: {}
    t.string "language"
    t.string "source", default: "telegram"
    t.string "source_message_id"
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_user_memories_on_created_at"
    t.index ["user_id", "source_message_id"], name: "idx_user_memories_on_user_id_and_source_message_id", unique: true, where: "(source_message_id IS NOT NULL)"
    t.index ["user_id"], name: "index_user_memories_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "activity_level", default: "sedentary", null: false
    t.integer "age"
    t.text "ai_context"
    t.string "calorie_goal_mode", default: "manual", null: false
    t.datetime "created_at", null: false
    t.integer "daily_calorie_goal", default: 2000
    t.integer "daily_limit"
    t.json "dietary_preferences", default: {}
    t.time "eating_window_end_local"
    t.time "eating_window_start_local"
    t.string "fasting_schedule", default: "16_8"
    t.string "first_name", null: false
    t.string "gender"
    t.string "health_goal", default: "maintain", null: false
    t.decimal "height_cm", precision: 5, scale: 1
    t.integer "images_processed_count"
    t.boolean "intermittent_fasting_enabled", default: false, null: false
    t.boolean "is_premium", default: false
    t.string "language", default: "en"
    t.string "last_name"
    t.date "last_process_date"
    t.datetime "last_reminder_sent_at"
    t.datetime "last_seen_at"
    t.json "meal_reminder_settings", default: {}, null: false
    t.boolean "meal_reminders_enabled", default: false, null: false
    t.json "meal_timing_preferences", default: {}, null: false
    t.text "pending_context"
    t.decimal "portion_modifier", precision: 3, scale: 2, default: "1.0"
    t.datetime "profile_completed_at"
    t.integer "tdee_calories"
    t.bigint "telegram_id", null: false
    t.string "timezone", default: "Asia/Kathmandu"
    t.datetime "updated_at", null: false
    t.string "username"
    t.decimal "weight_kg", precision: 5, scale: 2
    t.index ["activity_level"], name: "index_users_on_activity_level"
    t.index ["health_goal"], name: "index_users_on_health_goal"
    t.index ["intermittent_fasting_enabled"], name: "index_users_on_intermittent_fasting_enabled"
    t.index ["telegram_id"], name: "index_users_on_telegram_id", unique: true
  end

  add_foreign_key "food_items", "meals"
  add_foreign_key "meals", "users"
  add_foreign_key "nutrition_trends", "users"
  add_foreign_key "promo_code_redemptions", "promo_codes"
  add_foreign_key "promo_code_redemptions", "users"
  add_foreign_key "user_daily_stats", "users"
  add_foreign_key "user_food_stats", "users"
  add_foreign_key "user_memories", "users"
end
