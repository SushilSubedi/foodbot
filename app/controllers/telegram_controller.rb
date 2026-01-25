class TelegramController < ApplicationController
  def webhook
    update = params
    message = update[:message]
    
    if message
      chat_id = message.dig(:chat, :id)
      
      case message[:text]
      when "/start"
        handle_start_command(message)
      when "/help"
        handle_help_command(message)
      when "/about"
        handle_about_command(message)
      when "/today"
        handle_today_command(message)
      when "/week"
        handle_week_command(message)
      when "/stats"
        handle_stats_command(message)
      when "/setgoal"
        handle_setgoal_command(message)
      when "/language"
        handle_language_command(message)
      else
        if message[:photo].present?
          handle_photo_message(message)
        else
          handle_text_message(message)
        end
      end
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("Telegram webhook error: #{e.message}")
    head :ok
  end

  private

  def handle_start_command(message)
    user = find_or_create_user(message[:from])
    name = user.first_name || "there"
    
    # Determine user status
    is_first_time = user.first_time_user?
    is_first_today = user.first_time_today?
    
    # Update last seen
    user.update_last_seen!
    lang = user.language || 'en'

    if is_first_time
      # Brand new user
      welcome_text = TranslationService.t('welcome_new', lang, name: name)
    elsif is_first_today
      # Returning user, first time today
      meals_yesterday = user.meals.where('DATE(eaten_at) = ?', Date.yesterday).count
      
      greeting_key = case Time.current.hour
      when 5..11 then 'welcome_back_morning'
      when 12..16 then 'welcome_back_afternoon'
      when 17..20 then 'welcome_back_evening'
      else 'welcome_back_hello'
      end
      
      yesterday_msg = ""
      if lang == 'ne'
        yesterday_msg = meals_yesterday > 0 ? "\n\n📊 हिजो तपाईंले #{meals_yesterday} पटक खाना लग गर्नुभयो! राम्रो काम 💪" : ""
      else
        yesterday_msg = meals_yesterday > 0 ? "\n\n📊 You logged #{meals_yesterday} meal#{meals_yesterday > 1 ? 's' : ''} yesterday! Keep it up 💪" : ""
      end
      
      welcome_text = TranslationService.t(greeting_key, lang, name: name, yesterday_msg: yesterday_msg)
    else
      # Already seen today
      welcome_text = TranslationService.t('quick_menu', lang, name: name)
    end
    
    send_message(message.dig(:chat, :id), welcome_text)
  end

  def handle_help_command(message)
    help_text = <<~TEXT
      📖 How to Use KhanaAI

      📸 Track Meals:
      • Send food photo
      • Add caption (optional)
      • Get nutrition info

      📊 View Logs:
      • /today - Today's summary
      • /week - Weekly overview
      • /stats - Your profile

      ⚙️ Settings:
      • /language - Toggle En/Ne
      • /setgoal 2500 - Set daily goal
      • /start - Restart bot
      • /about - About KhanaAI

      💡 Works best with Nepali food!
    TEXT

    send_message(message.dig(:chat, :id), help_text)
  end

  def handle_about_command(message)
    about_text = <<~TEXT
      🤖 KhanaAI v1.0
      
      I am an AI-powered nutrition assistant designed to help you track your meals and stay healthy!
      
      Created by Sushil Subedi.
    TEXT  📊 Estimates: Calories, Protein, Carbs, Fat
      🍛 Knows: Dal bhat, momo, tarkari, achar & more

      ⚠️ These are estimates only, not medical advice.

      Built with ❤️ in Nepal
    TEXT

    send_message(message.dig(:chat, :id), about_text)
  end

  def handle_today_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    
    unless user
      send_message(chat_id, "👋 Welcome! Please send /start to begin.")
      return
    end
    
    summary = DailyLogService.new(user, Date.today).call
    send_message(chat_id, summary)
  end

  def handle_week_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    
    unless user
      send_message(chat_id, "👋 Welcome! Please send /start to begin.")
      return
    end
    
    summary = WeeklySummaryService.new(user).call
    send_message(chat_id, summary)
  end

  def handle_stats_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    
    unless user
      send_message(chat_id, "👋 Welcome! Please send /start to begin.")
      return
    end
    
    stats_text = <<~TEXT
      👤 Your Profile

      🎯 Daily Goal: #{user.daily_calorie_goal} kcal

      🔧 Settings:
        Language: #{user.language == 'ne' ? 'Nepali' : 'English'}
        Timezone: #{user.timezone}

      💡 Commands:
        /today - Today's meals
        /week - Weekly summary
        /help - How to use
    TEXT
    
    send_message(chat_id, stats_text)
  end

  def handle_setgoal_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    text = TranslationService.t('feature_in_development', lang)
    send_message(chat_id, text)
  end

  def handle_photo_message(message)
    chat_id = message.dig(:chat, :id)
    user = User.find_by(telegram_id: chat_id)
    lang = user&.language || 'en'
    
    # Send instant feedback and capture ID
    processing_msg = send_message(chat_id, TranslationService.t('analyzing', lang))
    message_id = processing_msg.dig('result', 'message_id') if processing_msg
    
    # Process image
    photo = message[:photo].last
    file_id = photo[:file_id]
    caption = message[:caption]
    
    # Update user activity
    user&.update_last_seen!
    
    process_image(chat_id, file_id, caption, message_id)
  end

  def handle_text_message(message)
    chat_id = message.dig(:chat, :id)
    user = User.find_by(telegram_id: chat_id)

    unless user
      send_message(chat_id, "👋 Welcome! Please send /start to begin.")
      return
    end

    if user.has_pending_context?
      handle_followup_text(user, message[:text], chat_id)
    else
      send_message(chat_id, "📸 Send me a food photo and I'll estimate the calories!\n\n💡 Tip: Add a caption like \"dal bhat, medium plate\" for better accuracy.")
    end
  end

  def handle_followup_text(user, text, chat_id)
    context = user.pending_context_data
    user.clear_pending_context

    send_message(chat_id, "✨ Thanks! Re-analyzing with: \"#{text}\"\n⏳ Just a moment...")

    analysis = TextClarificationService.new(
      text: text,
      image_url: context[:image_url],
      possible_foods: context[:possible_foods],
      calorie_range: context[:calorie_range]
    ).call

    if analysis
      handle_analysis_response(user, analysis, context[:image_url], text, chat_id)
    else
      send_error_message(chat_id)
    end
  end

  def handle_language_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    return unless user

    new_lang = user.language == 'en' ? 'ne' : 'en'
    user.update!(language: new_lang)

    key = new_lang == 'ne' ? 'lang_set_ne' : 'lang_set_en'
    text = TranslationService.t(key, new_lang)
    send_message(message.dig(:chat, :id), text)
  end

  def process_image(chat_id, file_id, caption, message_id = nil)
    service = TelegramService.new
    image_url = service.get_file_url(file_id)
    
    unless image_url
      send_or_edit_message(chat_id, message_id, "❌ Error: Could not download photo.")
      return
    end
    
    user = User.find_by(telegram_id: chat_id)
    unless user
      send_or_edit_message(chat_id, message_id, "👋 Welcome! Please send /start to begin.")
      return
    end
    
    lang = user.language || 'en'
    analysis = ImageAnalysisService.new(image_url, caption, lang).call
    
    if analysis
      handle_analysis_response(user, analysis, image_url, caption, chat_id, message_id)
    else
      send_or_edit_message(chat_id, message_id, "😕 Sorry, I couldn't analyze that image.")
    end
  end

  def handle_analysis_response(user, analysis, image_url, caption, chat_id, message_id = nil)
    case analysis['status']
    when 'success'
      handle_successful_analysis(user, analysis, image_url, caption, chat_id, message_id)
    when 'uncertain'
      handle_uncertain_analysis(user, analysis, image_url, chat_id, message_id)
    when 'not_food'
      handle_not_food(analysis, chat_id, message_id)
    when 'failed'
      handle_failed_analysis(analysis, chat_id, message_id)
    else
      send_or_edit_message(chat_id, message_id, "😕 Something went wrong.")
    end
  end

  def handle_not_food(analysis, chat_id, message_id = nil)
    user = User.find_by(telegram_id: chat_id)
    lang = user&.language || 'en'
    detected = analysis['detected_object'] || 'something else'
    
    text = <<~TEXT
      #{TranslationService.t('not_food_header', lang)}

      I see: #{detected}

      #{TranslationService.t('not_food_tip', lang)}
    TEXT

    send_or_edit_message(chat_id, message_id, text)
  end

  def handle_successful_analysis(user, analysis, image_url, caption, chat_id, message_id = nil)
    lang = user&.language || 'en'
    if analysis['confidence'] >= 0.7
      meal = save_meal(user, analysis, image_url, caption)
      response = format_high_confidence_response(analysis, lang)
      send_or_edit_message(chat_id, message_id, response)
    elsif analysis['confidence'] >= 0.4
      meal = save_meal(user, analysis, image_url, caption)
      response = format_medium_confidence_response(analysis, lang)
      send_or_edit_message(chat_id, message_id, response)
    else
      response = format_low_confidence_response(analysis, lang)
      send_or_edit_message(chat_id, message_id, response)
    end
  end

  def handle_uncertain_analysis(user, analysis, image_url, chat_id, message_id = nil)
    foods = analysis['possible_foods'].map { |f| "  • #{f}" }.join("\n")
    cal_range = analysis['estimated_calorie_range']
    cal_range_text = "#{cal_range['min']}–#{cal_range['max']}"

    user.set_pending_context(
      image_url: image_url,
      possible_foods: analysis['possible_foods'],
      calorie_range: cal_range
    )

    text = <<~TEXT
      🤔 I need a bit more info!

      I think this might be:
      #{foods}

      📊 Estimated: #{cal_range_text} kcal

      💬 Reply with the food name or portion size
      Example: "momo, 8 pieces" or "dal bhat thali"
    TEXT

    send_or_edit_message(chat_id, message_id, text)
  end

  def handle_failed_analysis(analysis, chat_id, message_id = nil)
    text = <<~TEXT
      😕 #{analysis['reason']}

      #{analysis['retry_tip']}
    TEXT
    
    send_or_edit_message(chat_id, message_id, text)
  end

  def save_meal(user, analysis, image_url, caption)
    meal = user.meals.create!(
      meal_type: analysis['meal_type'],
      input_type: 'image',
      image_url: image_url,
      raw_input: caption,
      estimated_calories: analysis['total']['calories'],
      confidence_score: analysis['confidence'],
      health_rating: analysis['health_rating'],
      eaten_at: Time.current
    )
    
    analysis['foods'].each do |food|
      meal.food_items.create!(
        name: food['name'],
        quantity: food['quantity'],
        calories: food['calories'],
        protein_g: food['protein_g'],
        carbs_g: food['carbs_g'],
        fat_g: food['fat_g']
      )
    end
    
    # Trigger daily stats calculation
    CalculateDailyStatsJob.perform_later(user.id, Date.today)
    
    meal
  end

  def format_high_confidence_response(analysis, lang = 'en')
    if analysis['foods'].length == 1
      format_single_food_response(analysis, lang)
    else
      format_multiple_foods_response(analysis, lang)
    end
  end

  def format_single_food_response(analysis, lang = 'en')
    food = analysis['foods'].first
    confidence_pct = (analysis['confidence'] * 100).to_i

    health_rating = analysis['health_rating']
    health_line = health_rating ? "💚 #{TranslationService.t('health_score', lang)}: #{health_rating}/10\n" : ""

    # Translate balance
    balance_key = "balance_#{analysis['balance']&.gsub('-', '_')}"
    balance_text = TranslationService.t(balance_key, lang)

    # Translate meal type
    meal_type_key = "meal_#{analysis['meal_type']}"
    meal_type_text = TranslationService.t(meal_type_key, lang)
    
    logged_as = TranslationService.t('logged_as', lang)
    confident_text = TranslationService.t('confident', lang)

    <<~TEXT
      ✅ #{food['name'].capitalize}
      🔥 #{food['calories']} kcal

      📊 #{TranslationService.t('protein', lang)}: #{food['protein_g'].round(1)}g | #{TranslationService.t('carbs', lang)}: #{food['carbs_g'].round(1)}g | #{TranslationService.t('fat', lang)}: #{food['fat_g'].round(1)}g

      #{health_line}⚖️ #{balance_text}
      💡 #{analysis['advice']}

      📝 #{logged_as} #{meal_type_text.downcase} (#{confidence_pct}% #{confident_text})
    TEXT
  end

  def format_multiple_foods_response(analysis, lang = 'en')
    foods_text = analysis['foods'].map.with_index do |food, idx|
      "  #{idx + 1}. #{food['name']} — #{food['calories']} kcal"
    end.join("\n")
    confidence_pct = (analysis['confidence'] * 100).to_i

    health_rating = analysis['health_rating']
    health_line = health_rating ? "💚 #{TranslationService.t('health_score', lang)}: #{health_rating}/10\n" : ""

    balance_key = "balance_#{analysis['balance']&.gsub('-', '_')}"
    balance_text = TranslationService.t(balance_key, lang)
    confident_text = TranslationService.t('confident', lang)

    <<~TEXT
      ✅ #{TranslationService.t('meal_logged', lang)} (#{analysis['foods'].length} #{TranslationService.t('items', lang)})
      #{foods_text}
      
      🔥 #{TranslationService.t('total', lang)}: #{analysis['total']['calories']} kcal

      📊 #{TranslationService.t('protein', lang)}: #{analysis['total']['protein_g'].round(1)}g | #{TranslationService.t('carbs', lang)}: #{analysis['total']['carbs_g'].round(1)}g | #{TranslationService.t('fat', lang)}: #{analysis['total']['fat_g'].round(1)}g

      #{health_line}⚖️ #{balance_text}
      💡 #{analysis['advice']}

      📝 #{confidence_pct}% #{confident_text}
    TEXT
  end

  def format_medium_confidence_response(analysis, lang = 'en')
    response = format_high_confidence_response(analysis, lang)
    assumptions = analysis['assumptions'].map { |a| "  • #{a}" }.join("\n")

    "#{response}\n⚠️ #{TranslationService.t('assumptions', lang)}:\n#{assumptions}"
  end

  def format_low_confidence_response(analysis, lang = 'en')
    foods = analysis['foods'].map { |f| "  • #{f['name']}" }.join("\n")
    cal_range = "#{analysis['total']['calories'] - 50}–#{analysis['total']['calories'] + 50}"

    <<~TEXT
      🤔 #{TranslationService.t('low_confidence_guess', lang)}

      #{TranslationService.t('possible_food', lang)}:
      #{foods}

      #{TranslationService.t('estimated_calories', lang)}: #{cal_range} kcal

      💬 #{TranslationService.t('reply_for_accuracy', lang)}
      #{TranslationService.t('example', lang)}: "chicken curry" #{TranslationService.t('or', lang)} "small portion"
    TEXT
  end

  def send_error_message(chat_id)
    user = User.find_by(telegram_id: chat_id)
    lang = user&.language || 'en'
    
    text = <<~TEXT
      #{TranslationService.t('error_oops', lang)}

      #{TranslationService.t('error_tips', lang)}

      #{TranslationService.t('error_help', lang)}
    TEXT

    send_message(chat_id, text)
  end

  def translate_balance(balance)
    {
      'balanced' => '✅ Well balanced',
      'carb-heavy' => '🍚 Carb-heavy',
      'protein-low' => '⚠️ Low protein',
      'fat-heavy' => '🧈 High fat'
    }[balance] || balance
  end

  def translate_meal_type(type)
    {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      'snack' => 'Snack',
      'unknown' => 'Meal'
    }[type] || type
  end

  def send_or_edit_message(chat_id, message_id, text, reply_markup = nil)
    service = TelegramService.new
    if message_id
      service.edit_message_text(
        chat_id: chat_id,
        message_id: message_id,
        text: text,
        reply_markup: reply_markup
      )
    else
      service.send_message(
        chat_id: chat_id,
        text: text,
        reply_markup: reply_markup
      )
    end
  end

  def send_message(chat_id, text, reply_markup = nil)
    TelegramService.new.send_message(chat_id: chat_id, text: text, reply_markup: reply_markup)
  end

  def find_or_create_user(from_data)
    User.find_or_create_by!(telegram_id: from_data[:id]) do |user|
      user.first_name = from_data[:first_name]
      user.last_name = from_data[:last_name]
      user.username = from_data[:username]
      user.language = 'en' # Default to English
    end
  end
end
