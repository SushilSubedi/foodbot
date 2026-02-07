# Foodbot: Application Overview and Phased Roadmap

This document provides a comprehensive overview of the Foodbot application, including its end-to-end workflow, a summary of potential issues and areas for improvement, and a recommended, phased roadmap for what to focus on to make the application more robust, scalable, and user-friendly.

---

### Part 1: The Complete Application Workflow

The application operates in two main flows: an **Interactive Flow** (real-time user interaction) and a **Background Flow** (automated, scheduled tasks).

#### 1.1 The Interactive Flow: Logging a Meal

This is the primary workflow, triggered when a user sends a message or photo to the chatbot.

**Step 1: Input and Routing (`TelegramController` / `WhatsappController`)**

*   All communication from a user hits a **webhook** in the appropriate controller (e.g., `telegram/webhook`).
*   The controller first determines the input type:
    *   **Command (`/start`, `/profile`):** Simple commands are handled directly, while complex ones are delegated to the `Telegram::CommandRouter`.
    *   **Photo Message:** This is the most common and complex path. The controller calls a handler like `handle_photo_message`.
    *   **Text Message:** Handled by a text message handler.

**Step 2: Photo Analysis (`ImageAnalysisService`)**

*   The controller delegates the photo to the `ImageAnalysisService`.
*   **AI Prompting:** This service constructs a highly detailed prompt for the **OpenAI GPT-4o Mini** model. This prompt is the "secret sauce" and includes:
    *   **Cultural Context:** An extensive guide to Nepali cuisine and typical calorie counts.
    *   **User Preferences:** The user's specific allergies, dietary needs, and portion size settings are dynamically injected into the prompt.
    *   **Strict Instructions:** The AI is ordered to return its analysis in a specific JSON format, which is validated by `Ai::FoodResponseValidator`.
*   **API Call:** The service sends the image and the detailed prompt to the OpenAI API for analysis.

**Step 3: Handling the AI Response (`TelegramController`)**

The controller's `handle_analysis_response` method inspects the AI's response `status`:

*   **`status: 'success'`:**
    *   The analysis was successful and confident.
    *   `save_meal` is called, creating the `Meal` and `FoodItem` records in the database.
    *   A confirmation message with the nutritional breakdown is formatted (using `TranslationService`) and sent to the user (via `TelegramService`).
    *   The `CalculateDailyStatsJob` background job is triggered to update the user's daily totals immediately.

*   **`status: 'uncertain'`:**
    *   The AI was not confident. The response contains a list of `possible_foods`.
    *   The controller **saves this context** to the `User` model (`user.set_pending_context`).
    *   A message is sent back to the user asking for clarification (e.g., "Hmm, I'm not sure. Is this momo or samosa?").

*   **`status: 'not_food'` or `'failed'`:**
    *   A friendly error message is sent to the user, prompting them to try again.

**Step 4: Handling Text Clarification (`TextClarificationService`)**

*   If the user replies to an "uncertain" query, the `handle_text_message` method in the controller detects the pending context.
*   It then calls `TextClarificationService`, which sends a new prompt to OpenAI containing the **original context** (what the AI first thought) and the **user's new clarifying text**.
*   This service gets a definitive `success` JSON response, and the workflow proceeds to save the meal as normal.

---

#### 1.2 The Background Flow: Generating Statistics and Trends

This workflow runs automatically without direct user interaction.

**Step 1: Daily Stat Updates (`CalculateDailyStatsJob`)**

*   **Trigger:** This job is triggered *every time* a meal is successfully logged.
*   **Action:** It recalculates the user's total calories, protein, carbs, and fat for the current day and updates the `user_daily_stats` table. This ensures that the `/today` command always shows up-to-date information.

**Step 2: Weekly Trend Analysis (`GenerateWeeklyTrendsJob`)**

*   **Trigger:** This job is designed to be run on a schedule (e.g., once a week).
*   **Action:** It loops through all users and, for each active user, calls the `TrendAnalysisService`.

**Step 3: Calculating the Trends (`TrendAnalysisService`)**

*   This service is the calculation engine for user reports. It does not use AI.
*   **Action:** It fetches all the user's meals for the past week, performs a comprehensive analysis (average daily nutrition, behavioral patterns, top foods, goal adherence), and saves this aggregated report to the `nutrition_trends` table. This data powers the `/trends` and `/week` commands.

---

### Part 2: Potential Issues and Areas for Improvement

Based on the analysis, here are the key challenges to consider as the application scales:

1.  **Cost and API Dependency:** The app's core function relies on making an API call to OpenAI for **every image and text clarification**, which can become very expensive with more users.

2.  **Performance and User Experience Latency:** When a user sends a photo, the app **synchronously** waits for the image to download and for the OpenAI API to respond. This can result in a noticeable delay before the user gets a reply.

3.  **AI Accuracy and Correctability:** The app's value depends on the AI's accuracy. If the AI makes a mistake, the user has no way to **correct** the logged meal; they can only delete it with `/undo`. This can lead to inaccurate logs and reduce user trust.

4.  **Scalability and Rate Limiting:** The app frequently calls external APIs (Telegram, OpenAI, Twilio), which have rate limits. A sudden spike in user activity could hit these limits and cause errors.

5.  **Rigidity of AI Prompts:** The detailed AI "system prompts" are hardcoded directly into the service files. Any change to these instructions requires a full code deployment, making it inflexible to iterate on or update the AI's behavior.

---

### Part 3: Recommended Focus and Phased Roadmap

To make the application more robust and ready for real-world use, here is a recommended, phased roadmap.

#### Phase 1: Immediate Stability and User Experience (The "Workable" Phase)

This phase addresses the most critical, user-facing issue: performance.

*   **Primary Focus:** **Move the AI analysis into a background job.**
*   **Why It's Critical:** This single change makes the app *feel* instantaneous to the user. They get an immediate "Analyzing..." message and are not left waiting for a slow network request. It also makes your application more reliable and is a prerequisite for scaling.
*   **Action Plan:**
    1.  **Create a New Background Job:** For example, `ProcessMealAnalysisJob`.
    2.  **Modify the Controller (`TelegramController`):** Instead of calling `ImageAnalysisService` directly, enqueue the new job. Pass it all necessary information (`chat_id`, `file_id`, `caption`, the `message_id` of the "Analyzing..." message, and the `user_id`).
    3.  **Implement the Job:** The job's `perform` method will contain the logic that is currently in the controller: it will call `ImageAnalysisService`, handle the AI's response, save the meal, and then use `TelegramService` to **edit the original "Analyzing..." message** with the final result.

#### Phase 2: User Trust and Data Quality

This phase focuses on improving the reliability of the core data and building user trust.

*   **Primary Focus:** **Implement a user correction mechanism.**
*   **Why It's Important:** Users will trust the app more if they can fix its mistakes. This also dramatically improves the quality of their logged data, making all downstream stats and trends more accurate.
*   **Action Plan:**
    1.  **Add a "Correct" Button:** After a meal is successfully logged, include an inline keyboard button on the response message, such as "✍️ Correct".
    2.  **Create a Correction Flow:** When a user clicks "Correct," initiate a conversation. Ask them, "What was incorrect? You can correct the food name, quantity, or calories." This could be a new, dedicated command handler class in `app/services/telegram/commands/`.
    3.  **Update the Data:** Update the `Meal` and `FoodItem` records with the user's corrections.
    4.  **(Future Enhancement):** Log these corrections. Over time, this data can be used to identify common AI errors and potentially fine-tune the AI prompts.

#### Phase 3: Long-Term Viability and Scalability

This phase addresses cost and robustness for future growth.

*   **Primary Focus:** **Cost Management and API Robustness.**
*   **Action Plan:**
    1.  **Cost Optimization:** Investigate strategies to reduce API calls.
        *   **Caching:** For very common, generic food images (e.g., a simple photo of rice), consider caching the AI's analysis to avoid re-processing identical images.
        *   **Model Tiering:** Experiment with using smaller, cheaper AI models for "easy" images and reserving the more powerful `gpt-4o-mini` for complex or multi-item meals.
    2.  **Rate-Limiting Handling:** Implement proper error handling for HTTP 429 ("Too Many Requests") responses from external APIs. When a rate limit is hit, the background job should automatically wait and retry the request using an exponential backoff strategy.

#### Phase 4: Maintainability and Iteration Speed

This phase focuses on making the application easier to update and maintain.

*   **Primary Focus:** **Decouple the AI prompts from the application code.**
*   **Why It's Important:** This will allow you to tweak the AI's behavior, update food context, or add new rules without needing a full code deployment.
*   **Action Plan:**
    1.  **Refactor AI Prompts:** Move the large, hardcoded "system prompt" strings from `ImageAnalysisService` and `TextClarificationService` into a more manageable format.
    2.  **Store Prompts Externally:** Store these prompts in a separate location, such as:
        *   YAML configuration files (`config/prompts/en.yml`).
        *   The existing `config/locales` structure for i18n-based prompts.
        *   A dedicated database table, which would allow for dynamic updates through an admin interface.
    3.  **Load Prompts Dynamically:** Update the services to load the prompt content from these external sources instead of having it hardcoded.

By following this phased roadmap, you can systematically enhance the Foodbot application from a functional prototype into a scalable, reliable, and user-friendly service.