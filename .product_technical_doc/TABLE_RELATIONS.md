```mermaid
erDiagram
    food_catalogs {
        int calories_per_serving
        float carbs_g
        datetime created_at
        string default_serving
        float fat_g
        boolean is_nepali
        string name PK "unique"
        float protein_g
    }

    food_items {
        int calories
        float carbs_g
        datetime created_at
        boolean diabetic_friendly
        float fat_g
        string food_category
        int glycemic_index
        string glycemic_load
        int meal_id FK
        string name
        string normalized_name
        float protein_g
        string quantity
        boolean vegan
        boolean vegetarian
    }

    meals {
        float confidence_score
        datetime created_at
        datetime eaten_at
        int estimated_calories
        float health_rating
        text image_url
        string input_type
        string meal_type
        text raw_input
        datetime updated_at
        int user_id FK
        int user_rating
    }

    nutrition_trends {
        decimal avg_daily_calories
        decimal avg_daily_carbs_g
        decimal avg_daily_fat_g
        decimal avg_daily_protein_g
        datetime created_at
        json day_of_week_breakdown
        int days_met_calorie_goal
        int days_met_protein_goal
        decimal goal_adherence_percentage
        json meal_type_breakdown
        date period_end
        date period_start PK "unique with user_id, period_type"
        string period_type PK "unique with user_id, period_start"
        json top_foods
        int total_meals_logged
        datetime updated_at
        int user_id FK PK "unique with period_start, period_type"
    }

    promo_code_redemptions {
        datetime created_at
        int promo_code_id FK
        datetime updated_at
        int user_id FK
    }

    promo_codes {
        boolean active
        string code
        datetime created_at
        datetime expires_at
        int limit_increase
        int max_uses
        datetime updated_at
        int uses_count
    }

    user_daily_stats {
        datetime created_at
        date date PK "unique with user_id"
        int total_calories
        float total_carbs_g
        float total_fat_g
        float total_protein_g
        datetime updated_at
        int user_id FK PK "unique with date"
    }

    user_food_stats {
        decimal avg_calories
        decimal avg_carbs_g
        decimal avg_fat_g
        decimal avg_fiber_g
        decimal avg_protein_g
        datetime created_at
        datetime first_eaten_at
        int health_score
        datetime last_eaten_at
        string most_common_meal_type
        string normalized_name
        json portion_variations
        int times_eaten
        datetime updated_at
        int user_id FK
    }

    users {
        string activity_level
        int age
        text ai_context
        string calorie_goal_mode
        datetime created_at
        int daily_calorie_goal
        int daily_limit
        json dietary_preferences
        time eating_window_end_local
        time eating_window_start_local
        string fasting_schedule
        string first_name
        string gender
        string health_goal
        decimal height_cm
        int images_processed_count
        boolean intermittent_fasting_enabled
        boolean is_premium
        string language
        string last_name
        date last_process_date
        datetime last_reminder_sent_at
        datetime last_seen_at
        json meal_reminder_settings
        boolean meal_reminders_enabled
        json meal_timing_preferences
        text pending_context
        decimal portion_modifier
        datetime profile_completed_at
        int tdee_calories
        bigint telegram_id PK "unique"
        string timezone
        datetime updated_at
        string username
        decimal weight_kg
    }

    food_items ||--|{ meals : "meal_id"
    meals ||--|{ users : "user_id"
    nutrition_trends ||--|{ users : "user_id"
    promo_code_redemptions ||--|{ promo_codes : "promo_code_id"
    promo_code_redemptions ||--|{ users : "user_id"
    user_daily_stats ||--|{ users : "user_id"
    user_food_stats ||--|{ users : "user_id"
```

## How the Database Tables are Connected (Simplified):

This document shows a map of our database, like a blueprint, using something called a Mermaid ER Diagram. It helps us see all the different lists of information (called "tables") and how they are linked together.

### What the Diagram Means:

*   **Tables:** Each box is a table, like a spreadsheet, storing specific kinds of information (e.g., `users` for user details, `meals` for meal records).
*   **Columns:** Inside each table box, you see the items of information it holds (like `name`, `age`, `calories`).
    *   `PK`: This means "Primary Key." It's a special item that uniquely identifies each row in a table. Think of it like an ID number that's different for every person in a list.
    *   `FK`: This means "Foreign Key." It's an item that links to a `PK` in another table. This is how tables "talk" to each other.
*   **Lines between Tables (Relationships):** The lines show how tables are connected.
    *   `||--|{`: This symbol means "one-to-many." The `||` side is the "one," and the `|{` side is the "many." For example, a line from `users` to `meals` that looks like `users ||--|{ meals` means one user can have many meals.

### A Look at Each Table and Its Connections:

Here's what each main table does and how it's linked:

1.  **`users`**:
    *   **What it is:** This table keeps all the details about people using the app, like their name, health goals, and preferences. Each user has a unique ID (`telegram_id`).
    *   **Connections:**
        *   A `user` can log many `meals`.
        *   A `user` can have many `nutrition_trends` (their eating patterns over time).
        *   A `user` can use many `promo_codes`.
        *   A `user` has many `user_daily_stats` (daily summaries of their eating).
        *   A `user` has many `user_food_stats` (details about specific foods they eat often).

2.  **`meals`**:
    *   **What it is:** This table stores information about each meal a user logs, like when they ate it, how many calories it had, and maybe a picture.
    *   **Connections:**
        *   Each `meal` belongs to one `user`.
        *   Each `meal` can contain many `food_items` (the individual foods in that meal).

3.  **`food_items`**:
    *   **What it is:** This table lists the specific foods that make up a `meal`, along with their nutrition facts.
    *   **Connections:**
        *   Each `food_item` belongs to one `meal`.

4.  **`food_catalogs`**:
    *   **What it is:** This is like a dictionary of different foods, showing their standard nutrition values per serving. It's used as a reference.
    *   **Connections:** It's a lookup list, so other tables don't directly link to it with a foreign key in this diagram, but they might use its information.

5.  **`user_daily_stats`**:
    *   **What it is:** This table summarizes a user's total nutrition (calories, carbs, etc.) for each day.
    *   **Connections:**
        *   Each daily summary belongs to one `user`.

6.  **`user_food_stats`**:
    *   **What it is:** This table tracks how often a user eats certain foods and the average nutrition of those foods for that user.
    *   **Connections:**
        *   Each food statistic belongs to one `user`.

7.  **`promo_codes`**:
    *   **What it is:** This table holds details about promotional codes, like their code, when they expire, and how many times they can be used.
    *   **Connections:**
        *   One `promo_code` can be used in many `promo_code_redemptions`.

8.  **`promo_code_redemptions`**:
    *   **What it is:** This table records each time a user successfully uses a promotional code.
    *   **Connections:**
        *   Each redemption is for one `promo_code`.
        *   Each redemption is done by one `user`.

9.  **`nutrition_trends`**:
    *   **What it is:** This table stores calculated trends and summaries of a user's eating habits over longer periods (like a week or month).
    *   **Connections:**
        *   Each trend record belongs to one `user`.

This simplified guide helps you understand how all the pieces of information in the Foodbot app are organized and connected in the database.