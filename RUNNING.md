# 🚀 Running the Telegram Food Tracking Bot

## Prerequisites

- Ruby 3.3.5 (check with `ruby -v`)
- Rails 8.1.2
- SQLite3
- OpenAI API key
- Telegram Bot Token
- ngrok (for local development)

## 1. Initial Setup

### Install Dependencies
```bash
cd /Users/sushilsubedi/work/foodbot
bundle install
```

### Configure Environment Variables
```bash
# Copy example env file (if exists) or create .env
touch .env
```

Add to `.env`:
```
OPENAI_API_KEY=your_openai_api_key_here
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
```

**Get API Keys:**
- **OpenAI**: https://platform.openai.com/api-keys
- **Telegram Bot**: Message @BotFather on Telegram, use `/newbot`

### Setup Database
```bash
# Run migrations
rails db:migrate

# Verify schema
rails db:schema:load
```

## 2. Start the Rails Server

```bash
rails server
# or
rails s
```

Server runs on `http://localhost:3000`

## 3. Expose Local Server (for Telegram Webhook)

### Install ngrok
```bash
# macOS
brew install ngrok

# Or download from https://ngrok.com/download
```

### Start ngrok
```bash
# In a new terminal
ngrok http 3000
```

**Copy the HTTPS URL** (e.g., `https://abc123.ngrok-free.app`)

## 4. Set Telegram Webhook

```bash
# Replace YOUR_BOT_TOKEN and YOUR_NGROK_URL
curl -F "url=https://YOUR_NGROK_URL/telegram/webhook" \
  https://api.telegram.org/botYOUR_BOT_TOKEN/setWebhook
```

**Example:**
```bash
curl -F "url=https://abc123.ngrok-free.app/telegram/webhook" \
  https://api.telegram.org/bot123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11/setWebhook
```

**Verify webhook:**
```bash
curl https://api.telegram.org/botYOUR_BOT_TOKEN/getWebhookInfo
```

## 5. Test the Bot

### Open Telegram
1. Search for your bot by username
2. Send `/start`
3. Send a food photo

### Expected Flow
```
You: /start
Bot: 👋 Namaste! I can help estimate calories...

You: [Send food photo]
Bot: 📸 Image received! Analyzing your meal...
Bot: 🍛 Dal Bhat detected
     🔥 Calories: ~520 kcal
     ...
```

## 6. Monitor Logs

### Rails Logs
```bash
# In another terminal
tail -f log/development.log
```

### Check for Errors
```bash
# Filter for errors
tail -f log/development.log | grep -i error

# Check AI validation
tail -f log/development.log | grep -i "validation"
```

## 7. Test in Rails Console

```bash
rails console
# or
rails c
```

### Test User Creation
```ruby
User.create!(
  telegram_id: 123456789,
  first_name: "Test",
  username: "testuser"
)

User.last
```

### Test Meal Creation
```ruby
user = User.last
meal = user.meals.create!(
  meal_type: "lunch",
  input_type: "image",
  estimated_calories: 520,
  confidence_score: 0.72,
  eaten_at: Time.current
)

meal.food_items.create!(
  name: "Dal bhat",
  quantity: "1 plate",
  calories: 520,
  protein_g: 18,
  carbs_g: 85,
  fat_g: 12
)
```

### Test Validation
```ruby
valid_json = {
  status: "success",
  meal_type: "lunch",
  foods: [{
    name: "Dal bhat",
    normalized_name: "dal bhat",
    quantity: "1 plate",
    portion_size: "medium",
    calories: 520,
    protein_g: 18.0,
    carbs_g: 85.0,
    fat_g: 12.0
  }],
  total: { calories: 520, protein_g: 18.0, carbs_g: 85.0, fat_g: 12.0 },
  balance: "carb-heavy",
  advice: "Add protein",
  confidence: 0.72,
  assumptions: ["Medium plate"]
}.to_json

result = Ai::FoodResponseValidator.call(valid_json)
puts result[:success] # Should be true
```

## 8. Common Issues & Solutions

### Issue: "Blocked hosts" Error
**Solution:** Already fixed in `config/environments/development.rb`
```ruby
config.hosts << /.*\.ngrok-free\.app/
```

### Issue: Connection Timeout to Telegram
**Solution:** Already fixed in `config/initializers/01_resolv_replace.rb`
```ruby
require 'resolv-replace'
```

### Issue: OpenAI API Error
**Check:**
- API key is correct in `.env`
- You have credits in OpenAI account
- Model `gpt-4o-mini` is accessible

### Issue: Telegram Not Receiving Messages
**Check:**
1. Webhook is set correctly (`getWebhookInfo`)
2. ngrok is running
3. Rails server is running
4. Check logs for errors

## 9. Development Workflow

### Terminal Setup (4 terminals)

**Terminal 1: Rails Server**
```bash
cd /Users/sushilsubedi/work/foodbot
rails s
```

**Terminal 2: ngrok**
```bash
ngrok http 3000
```

**Terminal 3: Logs**
```bash
cd /Users/sushilsubedi/work/foodbot
tail -f log/development.log
```

**Terminal 4: Console/Commands**
```bash
cd /Users/sushilsubedi/work/foodbot
rails c
# or run other commands
```

## 10. Quick Test Script

Save as `test_bot.sh`:
```bash
#!/bin/bash

# Test /start command
curl -X POST http://localhost:3000/telegram/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "message_id": 1,
      "from": {"id": 999999, "first_name": "Test"},
      "chat": {"id": 999999},
      "text": "/start"
    }
  }'
```

Run:
```bash
chmod +x test_bot.sh
./test_bot.sh
```

## 11. Stopping the Project

```bash
# Stop Rails server: Ctrl+C in Terminal 1
# Stop ngrok: Ctrl+C in Terminal 2
# Stop log tail: Ctrl+C in Terminal 3
```

## 12. Restart After Changes

```bash
# If you changed code
# Stop Rails server (Ctrl+C)
rails s

# If you changed gems
bundle install
rails s

# If you changed migrations
rails db:migrate
rails s

# If you changed .env
# Just restart Rails server
```

## Summary

**Minimum to run:**
1. `bundle install`
2. Setup `.env` with API keys
3. `rails db:migrate`
4. `rails s` (Terminal 1)
5. `ngrok http 3000` (Terminal 2)
6. Set webhook with curl
7. Test in Telegram!

**Check it's working:**
- Send `/start` → Should get welcome message
- Send food photo → Should get analysis
- Check `rails console` → Should see User and Meal records
