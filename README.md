# 🍛 KhanaAI - AI Nutrition Tracker

A Ruby on Rails Telegram bot that analyzes food photos and estimates calories and macronutrients using OpenAI GPT-4o Vision. Optimized for **Nepali cuisine**.

## Features

- **AI Vision Analysis**: GPT-4o-mini analyzes food images and returns nutrition estimates
- **Nepali Food Support**: Recognizes local dishes like Momo, Dal Bhat, Tarkari
- **Smart Validation**: Dry-validation contracts ensure consistent AI responses
- **Conversation Context**: Handles follow-up clarifications for uncertain results
- **Meal Logging**: Tracks meals and daily nutrition stats

## Tech Stack

- Ruby on Rails 8 (API-only)
- OpenAI GPT-4o-mini (vision)
- Telegram Bot API
- Dry-validation for response contracts
- PostgreSQL + pgvector (vector search)

## Setup

1. **Install dependencies:**
   ```bash
   bundle install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   ```
   
   Required variables:
   - `OPENAI_API_KEY` - OpenAI API key
   - `TELEGRAM_BOT_TOKEN` - Telegram bot token from @BotFather

3. **Setup database:**
   ```bash
   bin/rails db:setup
   ```

4. **Run server:**
   ```bash
   bin/rails server
   ```

## Webhook Setup

For local development, use ngrok:

```bash
ngrok http 3000
```

Set Telegram webhook:
```bash
curl -F "url=https://<your-ngrok-url>/telegram/webhook" \
  https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /telegram/webhook` | Telegram bot updates |

## Architecture

```
app/
├── controllers/
│   └── telegram_controller.rb    # Webhook handler
├── models/
│   ├── user.rb                   # User with pending_context
│   ├── meal.rb                   # Logged meals
│   └── food_item.rb              # Individual food items
└── services/
    ├── ai/
    │   ├── food_analysis_contract.rb   # Dry-validation schema
    │   └── food_response_validator.rb  # JSON validation
    ├── image_analysis_service.rb       # GPT-4o vision analysis
    ├── text_clarification_service.rb   # Follow-up text handling
    └── telegram_service.rb             # Telegram API client
```

## Flow

1. User sends food photo → `ImageAnalysisService` analyzes with GPT-4o
2. Response validated by `FoodAnalysisContract`
3. If validation fails → retry with relaxed prompt → fallback to "uncertain"
4. If "uncertain" → save context, ask user for clarification
5. User replies with text → `TextClarificationService` re-analyzes
6. Success → save meal and food items to database

## Testing

```bash
bundle exec rspec
```

## License

MIT
