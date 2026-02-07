# Foodbot Application Controllers and Webhooks Explained

This document details the controllers within the `foodbot` application, focusing on their role as entry points for user interaction and their webhook functionalities. Controllers are responsible for receiving incoming requests, processing them, and orchestrating the appropriate responses by interacting with models and services.

---

### 1. `ApplicationController` (`app/controllers/application_controller.rb`)

*   **Purpose:** This is the base controller for the entire application. All other controllers in a Rails application inherit from `ApplicationController`. It serves as a central place to define methods, filters, or configurations that are common across multiple controllers.
*   **Key Features:**
    *   **API-Centric:** It inherits from `ActionController::API`. This signifies that the application is designed primarily as an API backend, meaning its controllers are optimized to handle requests and respond with structured data (like JSON), rather than rendering traditional HTML views. This architecture is typical for applications that serve as a backend for chatbots, mobile apps, or single-page applications.
*   **Interactions:** All other controllers (`TelegramController`, `WhatsappController`) implicitly inherit from `ApplicationController` and benefit from any shared logic or setup defined here.

---

### 2. `TelegramController` (`app/controllers/telegram_controller.rb`)

*   **Purpose:** This controller is the primary interface for users interacting with the Foodbot via Telegram. It acts as a **webhook receiver**, processing all incoming updates from the Telegram API (messages, callback queries, photos) and delegating tasks to appropriate services or internal handlers. It is the "receptionist" and "dispatcher" for all Telegram interactions.
*   **Webhook (`webhook` action):**
    *   **Endpoint:** This is the single public endpoint configured with Telegram where all updates from the bot arrive (e.g., `https://your-app.com/telegram/webhook`).
    *   **Processing:** It receives a `params` hash from Telegram containing either a `message` (for text or photos) or a `callback_query` (for inline button presses).
    *   **Acknowledgement:** It immediately responds with `head :ok` to Telegram to acknowledge receipt, preventing timeouts, and then processes the request. Error handling ensures `head :ok` is always returned.
*   **Key Functionality:**
    *   **User Identification:** Uses `find_or_create_user` to ensure a `User` record exists for every interacting Telegram user.
    *   **Input Classification:** Differentiates between incoming messages (text or photo) and callback queries (from interactive buttons).
    *   **Command Handling:**
        *   Handles simpler, predefined commands (e.g., `/start`, `/help`, `/today`, `/week`, `/undo`) directly within its methods.
        *   Delegates newer or more complex personalization commands (e.g., `/setgoal`, `/profile`) to the `Telegram::CommandRouter` service for modular handling.
    *   **Photo Processing (`handle_photo_message`):**
        *   Sends an immediate "Analyzing..." message to the user for a better user experience.
        *   Calls `process_image` to orchestrate the AI analysis workflow for the photo.
    *   **Text Message Processing (`handle_text_message`):**
        *   Checks if the user is in the middle of a multi-step conversation (via `Telegram::CommandRouter` or `user.has_pending_context?`).
        *   If it's a clarification (e.g., after an "uncertain" AI analysis), it calls `handle_followup_text` which then uses `TextClarificationService`.
        *   Otherwise, it prompts the user to send a photo.
    *   **AI Analysis Workflow:** It's responsible for the overall flow of AI analysis:
        *   `process_image`: Retrieves the image URL via `TelegramService`, performs daily limit checks, and invokes `ImageAnalysisService`.
        *   `handle_analysis_response`: Interprets the AI's response status (`success`, `uncertain`, `not_food`, `failed`) and directs to the appropriate handler.
        *   `save_meal`: Creates `Meal` and `FoodItem` records upon successful AI analysis and triggers the `CalculateDailyStatsJob` background job.
    *   **Messaging Utilities:** Provides private helper methods (`send_message`, `edit_message`, `send_or_edit_message`) to streamline communication with users using `TelegramService`.
*   **Interactions:**
    *   **Models:** `User`, `Meal`, `PromoCode`, `PromoCodeRedemption`.
    *   **Services:** `TelegramService`, `Telegram::CommandRouter`, `ImageAnalysisService`, `TextClarificationService`, `DailyLogService`, `WeeklySummaryService`, `TranslationService`.
    *   **Jobs:** Triggers `CalculateDailyStatsJob`.

---

### 3. `WhatsappController` (`app/controllers/whatsapp_controller.rb`)

*   **Purpose:** This controller serves as the primary interface for users interacting with the Foodbot via WhatsApp. It acts as a **webhook receiver** for incoming WhatsApp messages and media, primarily focusing on processing food images. It's the "receptionist" for WhatsApp interactions.
*   **Webhook (`receive` action):**
    *   **Endpoint:** This is the public endpoint configured with Twilio where all incoming WhatsApp messages and media are sent (e.g., `https://your-app.com/whatsapp/receive`).
    *   **Acknowledgement:** It uses `head :ok` to immediately acknowledge receipt to Twilio.
*   **Key Functionality:**
    *   **Media Detection:** Checks `params[:NumMedia]` to determine if the incoming message contains an image attachment.
    *   **Image Processing:**
        *   If an image is present, it extracts the image URL (`params[:MediaUrl0]`).
        *   It then directly calls `ImageAnalysisService.new(image_url, nil).call` to analyze the image.
        *   The AI's response is formatted by `format_response` and sent back to the user via `TwilioService`.
    *   **Simple Text Handling:** If no media is detected, it sends a generic prompt in Nepali asking the user to send a food photo.
    *   **Streamlined Logic:** Compared to the `TelegramController`, this controller has a much simpler logic flow. It currently focuses almost exclusively on image analysis and basic text responses, without the extensive command handling, multi-step conversations, or user-specific preference management found in its Telegram counterpart.
*   **Interactions:**
    *   **Services:** `ImageAnalysisService` (for AI image processing), `TwilioService` (for sending WhatsApp messages).

---
