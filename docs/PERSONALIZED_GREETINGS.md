# Personalized Greetings Feature

## Overview
The bot now sends different welcome messages based on whether the user is:
1. **Brand new** (first time ever)
2. **Returning** (first time today)
3. **Active** (already used today)

## Implementation

### Database Changes
Added `last_seen_at` column to users table to track last activity.

**Migration:** `db/migrate/20260125140457_add_last_seen_to_users.rb`

### User Model Methods

**`first_time_user?`**
- Returns `true` if `last_seen_at` is nil
- Indicates brand new user

**`first_time_today?`**
- Returns `true` if last seen before today
- Indicates returning user's first interaction today

**`update_last_seen!`**
- Updates `last_seen_at` to current time
- Called on /start and when sending photos

### Message Types

#### 1. First Time Ever
```
🙏 Namaste, Sushil! Welcome to FoodBot!

I'm your AI nutrition assistant for tracking Nepali food 🍛

📸 How it works:
1. Send me a food photo
2. I'll analyze it with AI
3. Get calories & nutrition instantly

⚡ Results in 5-10 seconds
📊 Track daily & weekly progress
🎯 Set your calorie goals

Let's get started! Send me a photo of your meal 👇

💡 Tip: Works best with clear photos and good lighting
```

#### 2. First Time Today (Morning)
```
Good morning, Sushil! 👋

Ready to track today's meals?

📊 You logged 3 meals yesterday! Keep it up 💪

📸 Send a food photo to get started
💡 Commands: /today · /week · /stats
```

**Time-based greetings:**
- 5am-11am: "Good morning"
- 12pm-4pm: "Good afternoon"
- 5pm-8pm: "Good evening"
- Other: "Hello"

**Yesterday's stats:**
- Shows meal count from previous day
- Encourages consistency

#### 3. Already Active Today
```
👋 Hey Sushil!

I'm here to help! Here's what you can do:

📸 Send food photo - Track a meal
📊 /today - See today's summary
📈 /week - View weekly progress
⚙️ /stats - Your profile

What would you like to do?
```

## When last_seen_at Updates

1. **On /start command** - Always updates
2. **On photo upload** - Updates before analysis
3. **Not on /today, /week, /stats** - View-only commands don't update

## Benefits

✅ **Better onboarding** - New users get detailed instructions
✅ **Engagement** - Returning users see yesterday's progress
✅ **Personalization** - Time-based greetings feel natural
✅ **Reduced friction** - Active users get quick menu

## Testing

### Test First Time User
```ruby
# Rails console
user = User.last
user.update!(last_seen_at: nil)

# Then send /start in Telegram
# Should see full welcome message
```

### Test First Time Today
```ruby
# Rails console
user = User.last
user.update!(last_seen_at: 1.day.ago)

# Then send /start in Telegram
# Should see "Good morning/afternoon/evening" message
```

### Test Active User
```ruby
# Rails console
user = User.last
user.update!(last_seen_at: 1.hour.ago)

# Then send /start in Telegram
# Should see quick menu
```

## Example Flow

```
Day 1, 8am:
User: /start
Bot: "🙏 Namaste! Welcome to FoodBot!" (full onboarding)

Day 1, 9am:
User: [sends photo]
Bot: Analyzes food (updates last_seen_at)

Day 1, 2pm:
User: /start
Bot: "👋 Hey! I'm here to help..." (quick menu)

Day 2, 7am:
User: /start
Bot: "Good morning! Ready to track today's meals?
     📊 You logged 3 meals yesterday!" (daily greeting)
```

## Files Modified

1. `app/models/user.rb` - Added helper methods
2. `app/controllers/telegram_controller.rb` - Updated /start handler
3. `db/migrate/20260125140457_add_last_seen_to_users.rb` - Added column
