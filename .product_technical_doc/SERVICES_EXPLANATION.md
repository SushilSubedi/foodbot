# Foodbot Application Services Explained

This document provides a detailed explanation of each service within the `foodbot` application, outlining its purpose, key methods, and how it interacts with other components like models, controllers, and external APIs. Services are crucial for encapsulating specific business logic, promoting modularity, and keeping the codebase clean and maintainable.

---

### Core Services (`app/services/`)

#### 1. `CalorieGoalService` (`app/services/calorie_goal_service.rb`)

*   **Purpose:** Responsible for calculating a user's recommended daily calorie intake and breaking down their macronutrient targets (protein, carbs, fat) based on their health goals and personal data. It centralizes nutritional calculation logic.
*   **Key Methods:**
    *   `recommended_calories`: Determines the daily calorie target, either manually set by the user or automatically calculated from their TDEE with adjustments for their health goal (e.g., deficit for weight loss, surplus for muscle gain).
    *   `macro_targets`: Calculates the specific gram targets for protein, carbohydrates, and fats based on the recommended calories and health goal.
*   **Interactions:**
    *   **Models:** `User` (reads `health_goal`, `calorie_goal_mode`, `daily_calorie_goal`, `tdee_calories`).
    *   **Other Services:** `TdeeCalculatorService` (delegates TDEE calculation if needed).
    *   **Usage:** Used by other services (e.g., `TrendAnalysisService`) and command handlers (`SetGoalCommand`) for goal tracking and personalized advice.

#### 2. `DailyLogService` (`app/services/daily_log_service.rb`)

*   **Purpose:** Generates a comprehensive summary of a user's meals and nutritional intake for a specific day. This service powers reports like the `/today` command.
*   **Key Methods:**
    *   `call`: Fetches all meals and their food items logged by the user for a given date, then formats them into a daily summary.
    *   `format_daily_summary`: Groups meals by type, calculates daily totals for calories and macros, and presents the information alongside the user's calorie goal and progress.
*   **Interactions:**
    *   **Models:** `User` (reads language, calorie goal), `Meal`, `FoodItem` (fetches meal data).
    *   **Other Services:** `TranslationService` (for localized messages).
    *   **Usage:** Called by `TelegramController` to respond to the `/today` command.

#### 3. `FoodRecommendationService` (`app/services/food_recommendation_service.rb`)

*   **Purpose:** Provides personalized food suggestions, healthier alternatives, and dietary advice tailored to a user's eating habits and health goals.
*   **Key Methods:**
    *   `suggest_alternatives`: Identifies frequently consumed, less healthy foods and suggests better alternatives, providing reasons for the recommendations.
    *   `goal_aligned_suggestions`: Generates advice and food suggestions based on how well the user's recent macronutrient intake aligns with their health goals.
    *   `format_suggestions_message`: Combines all generated suggestions into a single, Markdown-formatted message for the chatbot.
*   **Interactions:**
    *   **Models:** `User` (reads preferences, health goals), `UserFoodStat` (reads frequent foods), `Meal`, `FoodItem` (reads recent meal data).
    *   **Other Services:** `CalorieGoalService` (to determine macro targets).
    *   **Usage:** Called by `Telegram::Commands::SuggestCommand`.

#### 4. `ImageAnalysisService` (`app/services/image_analysis_service.rb`)

*   **Purpose:** The core AI component for image-based food recognition. It analyzes user-provided food images to extract nutritional information, identify food items, and generate dietary advice using a large language model.
*   **Key Methods:**
    *   `call`: Orchestrates the image download and AI analysis process.
    *   `analyze_image`: Constructs a highly detailed prompt for the **OpenAI GPT-4o Mini** model, including extensive Nepali food context and dynamic user preferences. It sends the image and prompt to OpenAI, validates the JSON response, and includes retry logic for failed validations.
    *   `download_image`: Downloads the image from Telegram's servers.
    *   `build_user_context`: Dynamically generates a summary of user preferences for personalized AI prompting.
*   **Interactions:**
    *   **External APIs:** OpenAI API (for AI vision).
    *   **Models:** `User` (reads preferences).
    *   **Other Services:** `Ai::FoodResponseValidator` (for AI response schema validation).
    *   **Usage:** Called by `TelegramController` to process user-uploaded photos.

#### 5. `MealReminderService` (`app/services/meal_reminder_service.rb`)

*   **Purpose:** Manages and sends meal reminders to users. It intelligently determines when a reminder is due, considering user preferences, fasting schedules, and whether a meal has already been logged.
*   **Key Methods:**
    *   `should_send_reminder?(meal_type)`: Checks multiple conditions (e.g., reminders enabled, not recently reminded, not in fasting window, meal not logged, time passed) to decide if a reminder should be sent.
    *   `send_reminder(meal_type)`: Constructs and sends a personalized reminder message (including a goal-specific tip) to the user via Telegram.
    *   `check_and_send_all_reminders`: Iterates through all meal types to check and send any overdue reminders for a user.
*   **Interactions:**
    *   **Models:** `User` (reads reminder settings, fasting status, health goals), `Meal` (checks logged meals).
    *   **Other Services:** `TelegramService` (sends Telegram messages).
    *   **Usage:** Typically called by a background job on a schedule (e.g., every hour) to check reminders for all active users.

#### 6. `TdeeCalculatorService` (`app/services/tdee_calculator_service.rb`)

*   **Purpose:** Calculates a user's Total Daily Energy Expenditure (TDEE), an estimate of the calories burned daily, using biometric data and activity level. This is fundamental for setting accurate calorie goals.
*   **Key Methods:**
    *   `calculate`: Takes user's age, gender, weight, height, and activity level to compute BMR (Basal Metabolic Rate) using the Mifflin-St Jeor equation, and then TDEE by applying an activity multiplier. The calculated TDEE is saved to the `User` model.
*   **Interactions:**
    *   **Models:** `User` (reads and updates biometric data, `activity_level`, `tdee_calories`).
    *   **Usage:** Primarily called by `CalorieGoalService` and `Telegram::Commands::SetActivityCommand` / `SetBioCommand`.

#### 7. `TelegramService` (`app/services/telegram_service.rb`)

*   **Purpose:** Acts as the dedicated client for interacting with the Telegram Bot API. It centralizes all logic for sending and editing messages, answering callbacks, and retrieving file URLs from Telegram.
*   **Key Methods:**
    *   `get_file_url(file_id)`: Retrieves the direct download URL for a file (e.g., user-uploaded photo) from Telegram.
    *   `send_message(chat_id:, text:, reply_markup: nil)`: Sends a text message to a specific Telegram chat.
    *   `edit_message_text(chat_id:, message_id:, text:, reply_markup: nil)`: Modifies an existing message, crucial for updating "processing" messages with analysis results.
    *   `answer_callback_query(callback_query_id:, text: nil)`: Responds to inline keyboard callback queries.
*   **Interactions:**
    *   **External APIs:** Telegram Bot API (via `Faraday`).
    *   **Usage:** Used extensively by `TelegramController`, command classes, and background jobs for all Telegram communications.

#### 8. `TextClarificationService` (`app/services/text_clarification_service.rb`)

*   **Purpose:** Resolves ambiguities in food image analysis. When `ImageAnalysisService` is "uncertain," this service processes the user's clarifying text to obtain a definitive AI analysis.
*   **Key Methods:**
    *   `call`: Constructs an AI prompt combining the previous uncertain image context with the user's new clarifying text and personal preferences. It sends this to OpenAI (without the image) to get a final, structured JSON analysis.
*   **Interactions:**
    *   **External APIs:** OpenAI API.
    *   **Models:** `User` (reads preferences).
    *   **Other Services:** `Ai::FoodResponseValidator` (for AI response schema validation).
    *   **Usage:** Called by `TelegramController` when handling text responses after an "uncertain" image analysis.

#### 9. `TranslationService` (`app/services/translation_service.rb`)

*   **Purpose:** Centralizes all application text strings for internationalization (i18n), allowing the bot to communicate in multiple languages (English and Nepali). It also provides dynamic, randomized messages for a more engaging user experience.
*   **Key Methods:**
    *   `self.t(key, lang = 'en', params = {})`: The core translation method that retrieves messages based on a key and language, supporting dynamic content and parameter interpolation.
    *   `self.random_encouragement(lang = 'en')`, `self.random_analyzing(lang = 'en')`: Provide random messages from predefined lists.
*   **Interactions:**
    *   **Models:** `User` (to determine preferred language).
    *   **Usage:** Used pervasively throughout the application (controllers, other services, jobs) for all user-facing text.

#### 10. `TrendAnalysisService` (`app/services/trend_analysis_service.rb`)

*   **Purpose:** Analyzes a user's food consumption data over specific periods (e.g., weekly, monthly) to calculate nutritional trends, identify eating patterns, and measure goal adherence. It generates comprehensive reports.
*   **Key Methods:**
    *   `generate_report`: Defines the analysis period, fetches relevant meal data, calculates daily average macros, analyzes patterns by day of week and meal type, identifies top foods, and tracks goal achievement. It then saves these results to the `NutritionTrend` model.
    *   `summary_message`: Formats the generated `NutritionTrend` data into a human-readable text summary for the chatbot.
*   **Interactions:**
    *   **Models:** `User`, `Meal`, `FoodItem`, `NutritionTrend`.
    *   **Other Services:** `CalorieGoalService` (to get macro targets).
    *   **Usage:** Called by background jobs (`GenerateWeeklyTrendsJob`) and command handlers (`Telegram::Commands::TrendsCommand`).

#### 11. `TwilioService` (`app/services/twilio_service.rb`)

*   **Purpose:** Integrates the application with the Twilio API, primarily for sending messages to users via WhatsApp. It abstracts away the direct interaction with the Twilio SDK.
*   **Key Methods:**
    *   `send_message(to:, body:)`: Sends a text message to a specified recipient via Twilio.
*   **Interactions:**
    *   **External APIs:** Twilio API.
    *   **Usage:** Likely used by `WhatsappController` to communicate with WhatsApp users.

#### 12. `UserFoodStatsUpdaterService` (`app/services/user_food_stats_updater_service.rb`)

*   **Purpose:** Maintains and updates a user's personalized `UserFoodStat` records. It tracks how often specific foods are eaten, calculates running average nutritional content for those foods, and assigns a health score based on consumption patterns.
*   **Key Methods:**
    *   `update_stats`: Normalizes food names, increments `times_eaten`, updates `first_eaten_at` and `last_eaten_at`, calculates incremental running averages for macros, tracks portion variations, and assigns a health score to the food for that user.
*   **Interactions:**
    *   **Models:** `FoodItem`, `Meal`, `User`, `UserFoodStat`.
    *   **Usage:** Likely triggered automatically whenever a new `FoodItem` is created or updated (e.g., after a successful AI analysis).

#### 13. `WeeklySummaryService` (`app/services/weekly_summary_service.rb`)

*   **Purpose:** Generates a quick, easy-to-read summary of a user's calorie intake over the past seven days, providing a snapshot of daily totals against their goals.
*   **Key Methods:**
    *   `call`: Calculates the total estimated calories for each of the past seven days, then formats this data into a weekly summary message.
    *   `format_weekly_summary`: Creates a daily breakdown with calorie totals and a status emoji (`calorie_status`) indicating goal alignment, along with a weekly average.
*   **Interactions:**
    *   **Models:** `User` (reads language, calorie goals), `Meal` (queries for daily calorie totals).
    *   **Other Services:** `TranslationService` (for localized output).
    *   **Usage:** Called by `TelegramController` for the `/week` command.

---

### AI-Specific Services (`app/services/ai/`)

#### 14. `Ai::FoodAnalysisContract` (`app/services/ai/food_analysis_contract.rb`)

*   **Purpose:** Defines a strict schema and validation rules for the JSON responses expected from the OpenAI AI models (`gpt-4o-mini`). It ensures that all AI outputs are consistently structured and conform to predefined data types and constraints. This is crucial for application stability and data integrity.
*   **Key Features:** Uses `dry-validation` to specify required fields, data types, value ranges, and conditional validations based on the AI's `status` (e.g., `success`, `uncertain`, `failed`).
*   **Interactions:**
    *   **Other Services:** Used by `Ai::FoodResponseValidator` to perform the actual validation.
    *   **Usage:** Critical for `ImageAnalysisService` and `TextClarificationService` to process AI responses reliably.

#### 15. `Ai::FoodResponseValidator` (`app/services/ai/food_response_validator.rb`)

*   **Purpose:** Acts as a "gatekeeper" for all AI responses. It takes the raw text output from the OpenAI API, parses it as JSON, and then rigorously validates it against the `Ai::FoodAnalysisContract` schema.
*   **Key Methods:**
    *   `self.call(raw_json)`: Parses the raw AI output string, validates it using `FoodAnalysisContract`, and returns a success/failure hash with error details if validation fails. It also handles `JSON::ParserError`.
*   **Interactions:**
    *   **Other Services:** Uses `Ai::FoodAnalysisContract` for validation rules.
    *   **Usage:** Called by `ImageAnalysisService` and `TextClarificationService` to ensure AI responses are usable before further processing.

---

### Telegram Command Services (`app/services/telegram/`)

#### 16. `Telegram::CommandRouter` (`app/services/telegram/command_router.rb`)

*   **Purpose:** A central dispatcher for handling complex Telegram commands, callback queries, and multi-step text responses. It routes incoming user interactions to specific, dedicated command handler classes, promoting a modular and extensible architecture.
*   **Key Features:**
    *   `COMMANDS`: Maps command strings (e.g., `/setgoal`) to their respective handler classes.
    *   `CALLBACK_PREFIXES`: Maps callback data prefixes to handler classes, allowing interactive buttons to trigger specific actions.
    *   `route_command(text)`: Delegates command execution to the appropriate command class's `execute` method.
    *   `route_callback(callback_data)`: Delegates callback handling to the appropriate command class's `handle_callback` method.
    *   `route_text_response(text)`: Manages multi-step conversations by using `user.pending_context_data` to route text replies to the correct command class's response handler.
*   **Interactions:**
    *   **Controllers:** Used by `TelegramController` to process new commands and callbacks.
    *   **Models:** `User` (manages `pending_context_data`).
    *   **Other Services:** Works directly with all `Telegram::Commands::*` classes.

---

### Individual Telegram Command Handlers (`app/services/telegram/commands/`)

#### 17. `Telegram::Commands::ProfileCommand` (`app/services/telegram/commands/profile_command.rb`)

*   **Purpose:** Generates and displays a comprehensive profile summary for the user, including health goals, biometrics, fasting status, dietary preferences, and profile completion progress. It also provides an interactive keyboard for quick access to other profile-related commands.
*   **Key Methods:**
    *   `execute`: Assembles the `profile_message` from various user data points and creates an `action_keyboard` for further interactions.
*   **Interactions:**
    *   **Models:** Heavily interacts with the `User` model to retrieve all profile information (e.g., `health_goal`, `activity_level`, `age`, `tdee_calories`).
    *   **Other Services:** Output is sent via `TelegramService` after being routed by `Telegram::CommandRouter`.

#### 18. `Telegram::Commands::RemindersCommand` (`app/services/telegram/commands/reminders_command.rb`)

*   **Purpose:** Provides an interactive interface for users to manage their meal reminder settings, allowing them to enable/disable reminders globally or for specific meal types.
*   **Key Methods:**
    *   `execute`: Displays current reminder settings and an interactive `reminders_keyboard`.
    *   `handle_callback(callback_data)`: Processes user interactions with the reminder keyboard (e.g., "enable all", "disable all", "toggle breakfast").
    *   `enable_all_reminders`, `disable_all_reminders`, `toggle_meal_reminder`: Update the user's `meal_reminders_enabled` and `meal_reminder_settings` in the `User` model.
*   **Interactions:**
    *   **Models:** `User` (reads and updates reminder settings).
    *   **Other Services:** `TelegramService` (sends messages).

#### 19. `Telegram::Commands::SetActivityCommand` (`app/services/telegram/commands/set_activity_command.rb`)

*   **Purpose:** Guides the user through setting their physical activity level, which is a key input for calorie expenditure calculations.
*   **Key Methods:**
    *   `execute`: Prompts the user to select their activity level and provides an `activity_keyboard`.
    *   `handle_callback(callback_data)`: Updates the user's `activity_level` in the `User` model and, if biometric data is complete, recalculates their TDEE.
*   **Interactions:**
    *   **Models:** `User` (reads/updates `activity_level`, `tdee_calories`).
    *   **Other Services:** Implicitly uses `TdeeCalculatorService` via `User#update_tdee!`.

#### 20. `Telegram::Commands::SetBioCommand` (`app/services/telegram/commands/set_bio_command.rb`)

*   **Purpose:** Manages a multi-step conversational flow to collect the user's biometric data (age, gender, weight, height). This data is fundamental for personalized nutritional calculations.
*   **Key Methods:**
    *   `execute`: Initiates the conversation, setting `user.pending_context` and asking for age.
    *   `handle_response(text)`: Processes text inputs for age, weight, and height based on the current `pending_context_data`.
    *   `handle_callback(callback_data)`: Processes gender selection from an inline keyboard.
    *   `finish_setup`: Clears `pending_context`, records profile completion, and triggers TDEE calculation.
*   **Interactions:**
    *   **Models:** `User` (reads/updates biometric data, `pending_context`).
    *   **Other Services:** Implicitly uses `TdeeCalculatorService` via `User#update_tdee!`.

#### 21. `Telegram::Commands::SetFastingCommand` (`app/services/telegram/commands/set_fasting_command.rb`)

*   **Purpose:** Allows users to set up, modify, or disable their intermittent fasting schedules, offering both preset options and a custom eating window configuration.
*   **Key Methods:**
    *   `execute`: Presents fasting options via an `intro_message` and `schedule_keyboard`.
    *   `handle_callback(callback_data)`: Processes selections for preset schedules or initiates custom setup/disabling.
    *   `handle_time_input(text)`: Manages the multi-step collection of start and end times for custom fasting windows.
*   **Interactions:**
    *   **Models:** `User` (reads/updates `intermittent_fasting_enabled`, `fasting_schedule`, `eating_window_start_local`, `eating_window_end_local`, `pending_context`).

#### 22. `Telegram::Commands::SetGoalCommand` (`app/services/telegram/commands/set_goal_command.rb`)

*   **Purpose:** Enables users to define their primary health goal (e.g., weight loss, muscle gain, maintenance, diabetic-friendly). This goal informs calorie recommendations and macro targets.
*   **Key Methods:**
    *   `execute`: Prompts the user to select a health goal and provides a `goal_keyboard`.
    *   `handle_callback(callback_data)`: Updates the user's `health_goal` and recalculates calorie targets if `calorie_goal_mode` is "auto."
*   **Interactions:**
    *   **Models:** `User` (reads/updates `health_goal`).
    *   **Other Services:** Implicitly uses `TdeeCalculatorService` and `CalorieGoalService` via `User#update_tdee!` and `User#macro_targets`.

#### 23. `Telegram::Commands::SuggestCommand` (`app/services/telegram/commands/suggest_command.rb`)

*   **Purpose:** Triggers the `FoodRecommendationService` to generate and display personalized food suggestions and dietary advice to the user.
*   **Key Methods:**
    *   `execute`: Instantiates `FoodRecommendationService` and calls its `format_suggestions_message` to get the advice.
*   **Interactions:**
    *   **Other Services:** `FoodRecommendationService` (delegates advice generation).

#### 24. `Telegram::Commands::TrendsCommand` (`app/services/telegram/commands/trends_command.rb`)

*   **Purpose:** Allows users to view their nutritional trends over selectable periods (e.g., weekly, monthly).
*   **Key Methods:**
    *   `execute`: Prompts the user to select an analysis period and provides a `period_keyboard`.
    *   `handle_callback(callback_data)`: Instantiates `TrendAnalysisService` for the selected period and calls its `summary_message` to get the trend report.
*   **Interactions:**
    *   **Other Services:** `TrendAnalysisService` (delegates trend calculation and summary generation).