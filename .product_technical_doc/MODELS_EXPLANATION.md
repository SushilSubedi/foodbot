# Foodbot Application Models Explained

This document provides an overview of the key models within the Foodbot application, outlining their purpose, main attributes, and relationships with other parts of the database. Each model generally corresponds to a table in the database and encapsulates specific data and business logic.

---

### 1. `User` Model (`app/models/user.rb`)

*   **Purpose:** This is the central model representing individual users of the Foodbot application. It stores all personal information, preferences, goals, and interaction history for each user. It's the core entity around which much of the application's functionality revolves.
*   **Key Attributes (from `db/schema.rb`):**
    *   `telegram_id` (Bigint, `null: false`, `unique`): The unique identifier for the user as provided by the Telegram platform.
    *   `first_name`, `last_name`, `username`: Basic identifying information for the user.
    *   `language` (String, `default: "en"`): The user's preferred language for bot interactions.
    *   `activity_level` (String, `default: "sedentary"`): Describes the user's physical activity level, crucial for calculating personalized calorie needs.
    *   `age`, `gender`, `height_cm` (Decimal), `weight_kg` (Decimal): Biometric data used in various nutritional and health calculations.
    *   `health_goal` (String, `default: "maintain"`): The user's primary objective (e.g., "lose weight", "gain muscle", "maintain weight").
    *   `daily_calorie_goal` (Integer, `default: 2000`): The user's target daily calorie intake.
    *   `calorie_goal_mode` (String, `default: "manual"`): Indicates whether the calorie goal is set manually or calculated automatically.
    *   `dietary_preferences` (JSON, `default: {}`): Stores various user preferences such as vegetarian/vegan status, specific food allergies, or dislikes.
    *   `portion_modifier` (Decimal, `default: 1.0`): A factor applied to estimated portion sizes during AI analysis, allowing users to indicate if they typically eat larger or smaller portions.
    *   `intermittent_fasting_enabled` (Boolean, `default: false`): A flag indicating if the user practices intermittent fasting.
    *   `fasting_schedule` (String, `default: "16_8"`): Specifies the intermittent fasting pattern (e.g., "16_8" for 16 hours fasting, 8 hours eating).
    *   `meal_reminders_enabled` (Boolean, `default: false`): Flag to enable/disable meal reminder notifications.
    *   `meal_reminder_settings` (JSON, `default: {}`): Configures specific times for meal reminders.
    *   `ai_context` (Text): Custom notes or context provided by the user, which the AI considers during its analysis to personalize results.
    *   `daily_limit` (Integer): The maximum number of AI photo analyses a user can perform in a day (often related to premium features).
    *   `images_processed_count` (Integer): Counter for the number of images processed for the user on the current day.
    *   `last_process_date` (Date): The last date when user images were processed.
    *   `last_seen_at` (Datetime): Timestamp recording the user's last activity, used for greetings and activity tracking.
    *   `profile_completed_at` (Datetime): Timestamp indicating when the user finished setting up their initial profile.
*   **Key Relationships:** A `User` `has_many` `meals`, `nutrition_trends`, `promo_code_redemptions`, `user_daily_stats`, and `user_food_stats`. This signifies that many records in these tables belong to a single user.

#### 2. `Meal` Model (`app/models/meal.rb`)

*   **Purpose:** Represents a single meal event logged by a user. It captures the details of what was eaten at a specific time.
*   **Key Attributes (from `db/schema.rb`):**
    *   `user_id` (Integer, `null: false`): Foreign key linking this meal record to the specific `User` who logged it.
    *   `eaten_at` (Datetime): The timestamp when the meal was consumed.
    *   `meal_type` (String): Categorization of the meal (e.g., "breakfast", "lunch", "dinner", "snack", or "unknown").
    *   `input_type` (String): Indicates how the meal was logged (e.g., "image" for photo analysis, "text" for manual input).
    *   `image_url` (Text): If logged via an image, the URL where the image is stored.
    *   `raw_input` (Text): The original text caption or user input accompanying the meal log.
    *   `estimated_calories` (Integer): The AI's estimation of the total calorie content for this meal.
    *   `confidence_score` (Float): A value from 0.0 to 1.0 representing the AI's certainty in its analysis for this meal.
    *   `health_rating` (Float): An AI-generated rating (1.0-10.0) reflecting the perceived healthiness of the meal.
    *   `user_rating` (Integer): An optional rating provided by the user for this meal.
*   **Key Relationships:** A `Meal` `belongs_to` a `User` and `has_many` `food_items`.

#### 3. `FoodItem` Model (`app/models/food_item.rb`)

*   **Purpose:** Represents an individual food component within a `Meal`. A single meal can consist of multiple distinct food items (e.g., a "Dal Bhat" meal might have "Dal", "Bhat", and "Tarkari" as separate food items).
*   **Key Attributes (from `db/schema.rb`):**
    *   `meal_id` (Integer, `null: false`): Foreign key linking this food item to its parent `Meal`.
    *   `name` (String): The recognized name of the food item (e.g., "Momo", "Dal", "Steamed Rice").
    *   `normalized_name` (String): A standardized or simplified version of the food name used for consistent data aggregation and analysis.
    *   `quantity` (String): A human-readable description of the portion size (e.g., "8 pieces", "1 plate", "small bowl").
    *   `calories` (Integer): Estimated calorie content for this specific food item.
    *   `protein_g` (Float), `carbs_g` (Float), `fat_g` (Float): Estimated macronutrient content (protein, carbohydrates, fat) in grams.
    *   `food_category` (String): A general classification of the food (e.g., "appetizer", "main course", "beverage").
    *   `glycemic_index` (Integer), `glycemic_load` (String): Data points related to how a food affects blood sugar levels.
    *   `diabetic_friendly` (Boolean, `default: true`), `vegan` (Boolean, `default: false`), `vegetarian` (Boolean, `default: true`): Flags indicating suitability for various dietary restrictions.
*   **Key Relationships:** A `FoodItem` `belongs_to` a `Meal`.

#### 4. `FoodCatalog` Model (`app/models/food_catalog.rb`)

*   **Purpose:** Serves as a reference database of common food items, providing their standard nutritional values per serving. This acts as a lookup table that helps inform AI estimations and ensures consistency.
*   **Key Attributes (from `db/schema.rb`):**
    *   `name` (String, `unique`): The canonical name of the food item in the catalog.
    *   `calories_per_serving` (Integer): The typical calorie count for a standard serving size.
    *   `default_serving` (String): A description of the standard serving size for this item.
    *   `protein_g` (Float), `carbs_g` (Float), `fat_g` (Float): Standard macronutrient values per serving.
    *   `is_nepali` (Boolean, `default: false`): A flag indicating if the food item is commonly found in Nepali cuisine.
*   **Key Relationships:** This model typically serves as a lookup table and does not have explicit foreign key relationships defined *from* other models in the `db/schema.rb`, though other models might indirectly reference its data.

#### 5. `UserDailyStat` Model (`app/models/user_daily_stat.rb`)

*   **Purpose:** Aggregates and stores a user's total nutritional intake for a specific calendar day. This pre-calculated summary makes retrieving daily statistics much faster than recalculating from individual meals every time.
*   **Key Attributes (from `db/schema.rb`):**
    *   `user_id` (Integer, `null: false`): Foreign key linking these daily statistics to the `User`.
    *   `date` (Date, `unique` with `user_id`): The specific day for which these statistics are recorded. The combination of `user_id` and `date` forms a unique record.
    *   `total_calories` (Integer), `total_carbs_g` (Float), `total_fat_g` (Float), `total_protein_g` (Float): The sum of all corresponding nutritional values from meals logged on that day.
*   **Key Relationships:** A `UserDailyStat` `belongs_to` a `User`.

#### 6. `UserFoodStat` Model (`app/models/user_food_stat.rb`)

*   **Purpose:** Tracks user-specific statistics for individual food items they consume. This model provides insights into a user's personal dietary patterns for specific foods, like how often they eat something and its average nutrition for them.
*   **Key Attributes (from `db/schema.rb`):**
    *   `user_id` (Integer, `null: false`): Foreign key linking these food statistics to the `User`.
    *   `normalized_name` (String, `null: false`, `unique` with `user_id`): The standardized name of the food item being tracked, unique per user.
    *   `times_eaten` (Integer, `default: 0`): A count of how many times the user has logged this specific food.
    *   `avg_calories` (Decimal), `avg_carbs_g` (Decimal), `avg_fat_g` (Decimal), `avg_protein_g` (Decimal), `avg_fiber_g` (Decimal): Average nutritional values calculated for this food item based on the user's logging history.
    *   `first_eaten_at` (Datetime), `last_eaten_at` (Datetime): Timestamps marking the first and most recent consumption of this food by the user.
    *   `health_score` (Integer): An aggregated health score for this particular food, possibly derived from user's overall diet.
    *   `portion_variations` (JSON, `default: []`): Stores information about the different portion sizes or quantities of this food the user has logged.
*   **Key Relationships:** A `UserFoodStat` `belongs_to` a `User`.

#### 7. `PromoCode` Model (`app/models/promo_code.rb`)

*   **Purpose:** Manages promotional codes within the application. These codes can be used to offer users benefits, such as an increase in their daily AI analysis limit.
*   **Key Attributes (from `db/schema.rb`):**
    *   `code` (String): The unique alphanumeric string representing the promotional code.
    *   `active` (Boolean): A flag indicating if the promo code is currently valid for redemption.
    *   `expires_at` (Datetime): The date and time when the promo code ceases to be valid.
    *   `limit_increase` (Integer): The amount by which a user's daily limit is increased upon successful redemption of this code.
    *   `max_uses` (Integer): The total number of times this specific promo code can be redeemed across all users.
    *   `uses_count` (Integer): A counter tracking how many times the code has been redeemed so far.
*   **Key Relationships:** A `PromoCode` `has_many` `promo_code_redemptions`.

#### 8. `PromoCodeRedemption` Model (`app/models/promo_code_redemption.rb`)

*   **Purpose:** Records each instance when a specific user successfully redeems a particular promotional code. This ensures a code can only be used once per user (or tracks multiple uses if allowed).
*   **Key Attributes (from `db/schema.rb`):**
    *   `user_id` (Integer, `null: false`): Foreign key linking to the `User` who performed the redemption.
    *   `promo_code_id` (Integer, `null: false`): Foreign key linking to the `PromoCode` that was redeemed.
*   **Key Relationships:** A `PromoCodeRedemption` `belongs_to` a `User` and `belongs_to` a `PromoCode`.

#### 9. `NutritionTrend` Model (`app/models/nutrition_trend.rb`)

*   **Purpose:** Stores aggregated and analyzed nutritional trends for a user over predefined periods (e.g., weekly, monthly). This model generates the summary reports that provide users with insights into their long-term eating habits.
*   **Key Attributes (from `db/schema.rb`):**
    *   `user_id` (Integer, `null: false`): Foreign key linking these trends to the `User`.
    *   `period_start` (Date, `null: false`): The start date of the reporting period for these trends.
    *   `period_end` (Date, `null: false`): The end date of the reporting period.
    *   `period_type` (String, `null: false`): Specifies the type of period (e.g., "week", "month"). The combination of `user_id`, `period_start`, and `period_type` is unique.
    *   `total_meals_logged` (Integer): The total number of meals logged by the user within this period.
    *   `avg_daily_calories` (Decimal), `avg_daily_carbs_g` (Decimal), `avg_daily_fat_g` (Decimal), `avg_daily_protein_g` (Decimal): The calculated average daily intake of these nutrients over the period.
    *   `days_met_calorie_goal` (Integer), `days_met_protein_goal` (Integer): Counts of days within the period where the user met their respective calorie or protein goals.
    *   `goal_adherence_percentage` (Decimal): An overall percentage indicating how well the user adhered to their nutritional goals during the period.
    *   `meal_type_breakdown` (JSON): A JSON object containing statistics broken down by meal type (e.g., how many calories from breakfast, lunch, etc.).
    *   `day_of_week_breakdown` (JSON): A JSON object showing eating patterns and statistics per day of the week.
    *   `top_foods` (JSON): A list of the most frequently consumed foods during the period.
*   **Key Relationships:** A `NutritionTrend` `belongs_to` a `User`.

---

This comprehensive set of models collectively enables the Foodbot application to manage user profiles, track individual meals and their components, aggregate daily and long-term nutritional data, and handle promotional activities, forming the robust data foundation for all its features.