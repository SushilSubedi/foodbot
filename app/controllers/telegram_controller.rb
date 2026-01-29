class TelegramController < ApplicationController
  # New personalization commands
  NEW_COMMANDS = %w[/setgoal /setactivity /setbio /setfasting /trends /suggest /profile /reminders].freeze

  def webhook
    update = params
    message = update[:message]
    callback_query = update[:callback_query]

    if callback_query
      handle_callback_query(callback_query)
    elsif message
      chat_id = message.dig(:chat, :id)
      text = message[:text].to_s

      # Check for new personalization commands first
      if NEW_COMMANDS.any? { |cmd| text.downcase.start_with?(cmd) }
        handle_new_command(message)
      else
        case text
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
        when "/setgoals"
          handle_setgoals_command(message)
        when /^\/setgoals\s+(\d+)/
          handle_setgoals_value_command(message, $1.to_i)
        when "/redeem"
          handle_redeem_command(message)
        when "/language"
          handle_language_command(message)
        when "/vegetarian"
          handle_vegetarian_command(message)
        when "/vegan"
          handle_vegan_command(message)
        when "/preferences"
          handle_preferences_command(message)
        when /^\/allergic\s+(.+)/
          handle_allergic_command(message, $1)
        when /^\/removeallergy\s+(.+)/
          handle_removeallergy_command(message, $1)
        when /^\/dislike\s+(.+)/
          handle_dislike_command(message, $1)
        when /^\/portions\s+(larger|smaller|normal)/
          handle_portions_command(message, $1)
        when /^\/setnote\s+(.+)/
          handle_setnote_command(message, $1)
        when "/clearnote"
          handle_clearnote_command(message)
        when "/history"
          handle_history_command(message)
        when "/last"
          handle_last_command(message)
        when "/undo"
          handle_undo_command(message)
        else
          if message[:photo].present?
            handle_photo_message(message)
          else
            handle_text_message(message)
          end
        end
      end
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("Telegram webhook error: #{e.message}")
    head :ok
  end

  private

  def t(key, lang, params = {})
    TranslationService.t(key, lang, params)
  end

  def handle_new_command(message)
    user = find_or_create_user(message[:from])
    chat_id = message.dig(:chat, :id)
    router = Telegram::CommandRouter.new(user)

    response = router.route_command(message[:text])
    send_response(chat_id, response) if response
  end

  def handle_callback_query(callback_query)
    user = find_or_create_user(callback_query[:from])
    chat_id = callback_query.dig(:message, :chat, :id)
    message_id = callback_query.dig(:message, :message_id)
    callback_data = callback_query[:data]

    router = Telegram::CommandRouter.new(user)
    response = router.route_callback(callback_data)

    if response
      # Answer callback to remove loading state
      answer_callback(callback_query[:id])

      # Send or edit message based on response
      if response[:edit_message]
        edit_message(chat_id, message_id, response)
      else
        send_response(chat_id, response)
      end
    end
  end

  def send_response(chat_id, response)
    return unless response.is_a?(Hash)

    telegram_service.send_message(
      chat_id: chat_id,
      text: response[:text],
      parse_mode: response[:parse_mode] || "Markdown",
      reply_markup: response[:reply_markup]
    )
  end

  def edit_message(chat_id, message_id, response)
    telegram_service.edit_message(
      chat_id: chat_id,
      message_id: message_id,
      text: response[:text],
      parse_mode: response[:parse_mode] || "Markdown",
      reply_markup: response[:reply_markup]
    )
  end

  def answer_callback(callback_query_id)
    telegram_service.answer_callback_query(callback_query_id: callback_query_id)
  rescue StandardError => e
    Rails.logger.warn("Failed to answer callback: #{e.message}")
  end

  def telegram_service
    @telegram_service ||= TelegramService.new
  end

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
      
      # Add preferences tip for new users
      prefs_tip = if lang == 'ne'
        "\n\n🎯 सुझाव: /preferences प्रयोग गरेर आफ्नो खाने बानी सेट गर्नुहोस् (शाकाहारी, एलर्जी, आदि) सटीक अनुमानको लागि!"
      else
        "\n\n🎯 Tip: Set your dietary preferences with /preferences (vegetarian, allergies, etc.) for more accurate estimates!"
      end
      
      welcome_text += prefs_tip
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
    
    # Append help tip to all start messages
    welcome_text += TranslationService.t('help_tip', lang)
    
    send_message(message.dig(:chat, :id), welcome_text)
  end

  def handle_help_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    lang = user&.language || 'en'

    help_text = <<~TEXT
      #{t('help_title', lang)}

      #{t('help_track_title', lang)}
      #{t('help_track_desc', lang)}

      #{t('help_view_title', lang)}
      #{t('help_cmd_today', lang)}
      #{t('help_cmd_week', lang)}
      #{t('help_cmd_trends', lang)}
      #{t('help_cmd_history', lang)}
      #{t('help_cmd_last', lang)}
      #{t('help_cmd_undo', lang)}

      #{t('help_profile_title', lang)}
      #{t('help_cmd_profile', lang)}
      #{t('help_cmd_setgoal', lang)}
      #{t('help_cmd_setactivity', lang)}
      #{t('help_cmd_setbio', lang)}
      #{t('help_cmd_suggest', lang)}

      #{t('help_fasting_title', lang)}
      #{t('help_cmd_setfasting', lang)}
      #{t('help_cmd_reminders', lang)}

      #{t('help_prefs_title', lang)}
      #{t('help_cmd_preferences', lang)}
      #{t('help_cmd_vegetarian', lang)}
      #{t('help_cmd_vegan', lang)}
      #{t('help_cmd_allergic', lang)}
      #{t('help_cmd_portions', lang)}

      #{t('help_settings_title', lang)}
      #{t('help_cmd_language', lang)}
      #{t('help_cmd_setgoals', lang)}
      #{t('help_cmd_stats', lang)}
      #{t('help_cmd_redeem', lang)}

      #{t('help_footer', lang)}
    TEXT

    send_message(message.dig(:chat, :id), help_text, parse_mode: "Markdown")
  end

  def handle_about_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    lang = user&.language || 'en'

    about_text = <<~TEXT
      #{t('about_title', lang)}

      #{t('about_desc', lang)}

      #{t('about_features', lang)}

      #{t('about_disclaimer', lang)}

      #{t('about_creator', lang)}
    TEXT

    send_message(message.dig(:chat, :id), about_text, parse_mode: "Markdown")
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
    
    lang = user.language || 'en'
    
    # Calculate stats
    limit = user.daily_limit || 3
    remaining = [limit - (user.images_processed_count || 0), 0].max
    
    # Last 7 days average
    week_stats = user.user_daily_stats.where('date >= ?', 7.days.ago).pluck(:total_calories)
    avg_calories = week_stats.any? ? (week_stats.sum / week_stats.count).round : 0
    
    # Streak (consecutive days with meals)
    streak = 0
    date = Date.today
    while user.meals.where('DATE(eaten_at) = ?', date).exists?
      streak += 1
      date -= 1.day
    end
    
    stats_text = if lang == 'ne'
      <<~TEXT
        👤 तपाईंको प्रोफाइल

        🎯 दैनिक लक्ष्य: #{user.daily_calorie_goal} kcal
        📊 ७ दिनको औसत: #{avg_calories} kcal
        🔥 स्ट्रिक: #{streak} दिन
        📸 आज बाँकी: #{remaining}/#{limit}

        🔧 सेटिङ:
          भाषा: नेपाली

        💡 /preferences · /help
      TEXT
    else
      <<~TEXT
        👤 Your Profile

        🎯 Daily Goal: #{user.daily_calorie_goal} kcal
        📊 7-day Avg: #{avg_calories} kcal
        🔥 Streak: #{streak} day#{streak != 1 ? 's' : ''}
        📸 Today remaining: #{remaining}/#{limit}

        🔧 Settings:
          Language: English

        💡 /preferences · /help
      TEXT
    end
    
    send_message(chat_id, stats_text)
  end

  def handle_setgoals_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    current = user.daily_calorie_goal || 2000

    text = if lang == 'ne'
      <<~TEXT
        🎯 हालको लक्ष्य: #{current} kcal/दिन

        लक्ष्य परिवर्तन गर्न:
        /setgoals 1500 - घटाउने
        /setgoals 2000 - सामान्य
        /setgoals 2500 - बढाउने

        💡 सामान्य लक्ष्यहरू:
        • घटाउने: 1200-1500 kcal
        • मध्यम: 1800-2200 kcal
        • बढाउने: 2500-3000 kcal
      TEXT
    else
      <<~TEXT
        🎯 Current goal: #{current} kcal/day

        Set a new goal:
        /setgoals 1500 - Weight loss
        /setgoals 2000 - Maintenance
        /setgoals 2500 - Weight gain

        💡 Common targets:
        • Weight loss: 1200-1500 kcal
        • Maintenance: 1800-2200 kcal
        • Muscle gain: 2500-3000 kcal
      TEXT
    end

    send_message(chat_id, text)
  end

  def handle_setgoals_value_command(message, calories)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'

    if calories < 800 || calories > 5000
      text = if lang == 'ne'
        "⚠️ कृपया 800-5000 kcal बीचको मान प्रविष्ट गर्नुहोस्।"
      else
        "⚠️ Please enter a value between 800-5000 kcal."
      end
      send_message(chat_id, text)
      return
    end

    user.update!(daily_calorie_goal: calories)

    text = if lang == 'ne'
      "✅ दैनिक लक्ष्य सेट गरियो: #{calories} kcal/दिन"
    else
      "✅ Daily goal set: #{calories} kcal/day"
    end

    send_message(chat_id, text)
  end

  def handle_redeem_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user
    
    code_str = message[:text].split(' ').last.to_s.upcase
    lang = user.language || 'en'
    
    promo = PromoCode.find_by(code: code_str, active: true)
    
    if promo.nil?
      send_message(chat_id, TranslationService.t('promo_invalid', lang))
      return
    end

    if promo.max_uses && promo.uses_count >= promo.max_uses
      send_message(chat_id, TranslationService.t('promo_limit_reached', lang))
      return
    end

    if PromoCodeRedemption.exists?(user: user, promo_code: promo)
      send_message(chat_id, TranslationService.t('promo_already_used', lang))
      return
    end

    # Apply promo
    increment = promo.limit_increase
    user.increment!(:daily_limit, increment)
    
    # Record redemption
    PromoCodeRedemption.create!(user: user, promo_code: promo)
    promo.increment!(:uses_count)
    
    text = TranslationService.t('promo_success', lang, amount: increment, new_limit: user.daily_limit)
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
      send_message(chat_id, "Hey there! 👋 Send /start and let's get you set up.")
      return
    end

    lang = user.language || 'en'

    # Check for command router conversations (bio setup, fasting setup, etc.)
    router = Telegram::CommandRouter.new(user)
    if router.has_pending_conversation?
      response = router.route_text_response(message[:text])
      if response
        send_response(chat_id, response)
        return
      end
    end

    if user.has_pending_context?
      handle_followup_text(user, message[:text], chat_id)
    else
      text = if lang == 'ne'
        casual_responses = [
          "📸 खानाको फोटो पठाउनुहोस् त!",
          "📸 के खानुभयो? फोटो पठाउनुहोस्!",
          "📸 फोटो पठाउनुहोस्, म हेर्छु क्यालोरी कति छ।"
        ]
        casual_responses.sample
      else
        casual_responses = [
          "📸 Show me what you're eating!",
          "📸 Snap a pic of your food and I'll check the calories.",
          "📸 Send me a food photo!",
          "What are you having? 📸 Send a pic!"
        ]
        casual_responses.sample
      end
      send_message(chat_id, text)
    end
  end

  def handle_followup_text(user, text, chat_id)
    context = user.pending_context_data
    user.clear_pending_context
    lang = user.language || 'en'

    followup_msg = if lang == 'ne'
      ["आहा, #{text}! हेर्दैछु...", "#{text} हो? एक छिन...", "बुझें! जाँच गर्दैछु..."].sample
    else
      ["Ah, #{text}! Let me check...", "Got it — #{text}. One sec...", "#{text}, nice! Checking..."].sample
    end
    send_message(chat_id, followup_msg)

    analysis = TextClarificationService.new(
      text: text,
      image_url: context[:image_url],
      possible_foods: context[:possible_foods],
      calorie_range: context[:calorie_range],
      user: user
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
    
    # Check limit
    unless user.check_daily_limit!
      limit = user.daily_limit || 3
      text = TranslationService.t('daily_limit_reached', lang, limit: limit)
      send_or_edit_message(chat_id, message_id, text)
      return
    end

    analysis = ImageAnalysisService.new(image_url, caption, lang, user).call
    
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
    detected = analysis['detected_object'] || 'something'

    text = if lang == 'ne'
      responses = [
        "🤔 यो त #{detected} जस्तो देखिन्छ, खाना होइन!\n\nखानाको फोटो पठाउनुस् त।",
        "😅 यो खाना होइन जस्तो छ — #{detected}?\n\nदाल भात, मोमो जस्तो केही पठाउनुस्!"
      ]
      responses.sample
    else
      responses = [
        "🤔 That looks like #{detected}, not food!\n\nSend me a pic of your meal instead.",
        "😅 Hmm, #{detected}? I can only analyze food!\n\nTry sending dal bhat, momo, etc."
      ]
      responses.sample
    end

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
    lang = user.language || 'en'
    foods = analysis['possible_foods'].join(", ")
    cal_range = analysis['estimated_calorie_range']
    cal_range_text = "#{cal_range['min']}–#{cal_range['max']}"

    user.set_pending_context(
      image_url: image_url,
      possible_foods: analysis['possible_foods'],
      calorie_range: cal_range
    )

    text = if lang == 'ne'
      <<~TEXT
        🤔 यो के हो भन्न गाह्रो भयो!

        #{foods} जस्तो देखिन्छ
        📊 लगभग #{cal_range_text} kcal

        के हो भन्नुस् त — जस्तै "मोमो, ८ वटा"
      TEXT
    else
      <<~TEXT
        🤔 Hmm, I'm not quite sure what this is!

        Could be #{foods}
        📊 Roughly #{cal_range_text} kcal

        What is it? Just reply like "momo, 8 pieces"
      TEXT
    end

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
    health_rating = analysis['health_rating']

    balance_key = "balance_#{analysis['balance']&.gsub('-', '_')}"
    balance_text = TranslationService.t(balance_key, lang)

    encouragement = TranslationService.random_encouragement(lang)

    if lang == 'ne'
      <<~TEXT
        ✅ #{food['name']}

        🔥 #{food['calories']} kcal
        🍗 प्रोटिन: #{food['protein_g'].round(1)}g · 🍚 कार्ब: #{food['carbs_g'].round(1)}g · 🧈 फ्याट: #{food['fat_g'].round(1)}g

        #{health_rating ? "💚 स्वास्थ्य: #{format_health_rating(health_rating)}/10 · " : ""}#{balance_text}

        💡 #{analysis['advice']}
      TEXT
    else
      <<~TEXT
        ✅ #{food['name'].capitalize}

        🔥 #{food['calories']} kcal
        🍗 Protein: #{food['protein_g'].round(1)}g · 🍚 Carbs: #{food['carbs_g'].round(1)}g · 🧈 Fat: #{food['fat_g'].round(1)}g

        #{health_rating ? "💚 Health: #{format_health_rating(health_rating)}/10 · " : ""}#{balance_text}

        💡 #{analysis['advice']}
      TEXT
    end
  end

  def format_multiple_foods_response(analysis, lang = 'en')
    foods_text = analysis['foods'].map.with_index do |food, idx|
      "#{idx + 1}. #{food['name']} — #{food['calories']} kcal"
    end.join("\n")

    health_rating = analysis['health_rating']
    balance_key = "balance_#{analysis['balance']&.gsub('-', '_')}"
    balance_text = TranslationService.t(balance_key, lang)
    total = analysis['total']

    if lang == 'ne'
      <<~TEXT
        ✅ #{analysis['foods'].length} परिकार लग भयो!

        #{foods_text}

        🔥 जम्मा: #{total['calories']} kcal
        🍗 प्रोटिन: #{total['protein_g'].round(1)}g · 🍚 कार्ब: #{total['carbs_g'].round(1)}g · 🧈 फ्याट: #{total['fat_g'].round(1)}g

        #{health_rating ? "💚 स्वास्थ्य: #{format_health_rating(health_rating)}/10 · " : ""}#{balance_text}

        💡 #{analysis['advice']}
      TEXT
    else
      <<~TEXT
        ✅ Logged #{analysis['foods'].length} items!

        #{foods_text}

        🔥 Total: #{total['calories']} kcal
        🍗 Protein: #{total['protein_g'].round(1)}g · 🍚 Carbs: #{total['carbs_g'].round(1)}g · 🧈 Fat: #{total['fat_g'].round(1)}g

        #{health_rating ? "💚 Health: #{format_health_rating(health_rating)}/10 · " : ""}#{balance_text}

        💡 #{analysis['advice']}
      TEXT
    end
  end

  def format_medium_confidence_response(analysis, lang = 'en')
    response = format_high_confidence_response(analysis, lang)
    assumptions = analysis['assumptions']&.first(2)&.map { |a| "• #{a}" }&.join("\n")

    if assumptions.present?
      if lang == 'ne'
        "#{response}\n📝 मेरो अनुमान:\n#{assumptions}"
      else
        "#{response}\n📝 I'm assuming:\n#{assumptions}"
      end
    else
      response
    end
  end

  def format_low_confidence_response(analysis, lang = 'en')
    foods = analysis['foods'].map { |f| f['name'] }.join(", ")
    cal_range = "#{analysis['total']['calories'] - 50}–#{analysis['total']['calories'] + 50}"

    if lang == 'ne'
      <<~TEXT
        🤔 हम्म, पक्का छैन तर...

        #{foods} जस्तो देखिन्छ?
        📊 लगभग #{cal_range} kcal

        के हो भन्नुस् त! जस्तै "मोमो, १० वटा"
      TEXT
    else
      <<~TEXT
        🤔 Not totally sure, but...

        Looks like #{foods}?
        📊 Roughly #{cal_range} kcal

        Tell me what it is! Like "momo, 10 pieces"
      TEXT
    end
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

  def format_health_rating(rating)
    return nil unless rating
    rating.is_a?(Float) ? rating.round(1) : rating
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

  def send_message(chat_id, text, reply_markup: nil, parse_mode: nil)
    TelegramService.new.send_message(chat_id: chat_id, text: text, reply_markup: reply_markup, parse_mode: parse_mode)
  end

  def find_or_create_user(from_data)
    User.find_or_create_by!(telegram_id: from_data[:id]) do |user|
      user.first_name = from_data[:first_name]
      user.last_name = from_data[:last_name]
      user.username = from_data[:username]
      user.language = 'en' # Default to English
    end
  end

  # Preference command handlers
  def handle_vegetarian_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    current = user.is_vegetarian?
    user.update_dietary_preference('vegetarian', !current)

    if current
      text = lang == 'ne' ? "✅ शाकाहारी मोड हटाइयो" : "✅ Vegetarian mode removed"
    else
      text = lang == 'ne' ? "✅ शाकाहारी मोड सेट गरियो! म अब शाकाहारी खानाको लागि क्यालोरी अनुमान समायोजन गर्नेछु।" : "✅ Vegetarian mode enabled! I'll adjust calorie estimates for vegetarian meals."
    end
    
    send_message(chat_id, text)
  end

  def handle_vegan_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    current = user.is_vegan?
    user.update_dietary_preference('vegan', !current)

    if current
      text = lang == 'ne' ? "✅ भेगन मोड हटाइयो" : "✅ Vegan mode removed"
    else
      text = lang == 'ne' ? "✅ भेगन मोड सेट गरियो! म अब भेगन खानाको लागि क्यालोरी अनुमान समायोजन गर्नेछु।" : "✅ Vegan mode enabled! I'll adjust calorie estimates for vegan meals."
    end
    
    send_message(chat_id, text)
  end

  def handle_allergic_command(message, food)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    user.add_allergy(food)
    
    text = lang == 'ne' ? "✅ एलर्जी थपियो: #{food}" : "✅ Added allergy: #{food}. I'll keep this in mind when analyzing your meals."
    send_message(chat_id, text)
  end

  def handle_removeallergy_command(message, food)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    user.remove_allergy(food)
    
    text = lang == 'ne' ? "✅ एलर्जी हटाइयो: #{food}" : "✅ Removed allergy: #{food}"
    send_message(chat_id, text)
  end

  def handle_dislike_command(message, food)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    user.add_dislike(food)
    
    text = lang == 'ne' ? "✅ नापसन्द थपियो: #{food}" : "✅ Added to dislikes: #{food}"
    send_message(chat_id, text)
  end

  def handle_portions_command(message, direction)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    user.adjust_portion_size(direction)
    percentage = (user.portion_modifier * 100).to_i
    
    text = if lang == 'ne'
      "✅ भाग आकार समायोजन: #{percentage}%"
    else
      case direction
      when "larger"
        "✅ Got it! I'll estimate #{percentage}% of standard portions (larger servings)."
      when "smaller"
        "✅ Got it! I'll estimate #{percentage}% of standard portions (smaller servings)."
      when "normal"
        "✅ Portion size reset to normal (100%)."
      end
    end
    
    send_message(chat_id, text)
  end

  def handle_setnote_command(message, note)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    user.update!(ai_context: note)
    
    text = lang == 'ne' ? "✅ नोट सेट गरियो" : "✅ Note saved! I'll consider this context in my analysis."
    send_message(chat_id, text)
  end

  def handle_clearnote_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    user.update!(ai_context: nil)
    
    text = lang == 'ne' ? "✅ नोट हटाइयो" : "✅ Note cleared"
    send_message(chat_id, text)
  end

  def handle_preferences_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'

    if !user.has_preferences?
      text = if lang == 'ne'
        "कुनै प्राथमिकता सेट गरिएको छैन।\n\nउपलब्ध आदेशहरू:\n/vegetarian - शाकाहारी मोड\n/vegan - भेगन मोड\n/allergic <खाना> - एलर्जी थप्नुहोस्\n/portions larger/smaller - भाग आकार समायोजन गर्नुहोस्"
      else
        "No preferences set yet.\n\nAvailable commands:\n/vegetarian - Toggle vegetarian mode\n/vegan - Toggle vegan mode\n/allergic <food> - Add allergy\n/dislike <food> - Add dislike\n/portions larger/smaller/normal - Adjust portions\n/setnote <text> - Add custom note"
      end
      send_message(chat_id, text)
      return
    end

    prefs = []
    
    prefs << (lang == 'ne' ? "🥗 शाकाहारी" : "🥗 Vegetarian") if user.is_vegetarian?
    prefs << (lang == 'ne' ? "🌱 भेगन" : "🌱 Vegan") if user.is_vegan?
    
    allergies = user.dietary_preferences&.dig("allergies") || []
    if allergies.any?
      prefs << (lang == 'ne' ? "🚫 एलर्जी: #{allergies.join(', ')}" : "🚫 Allergies: #{allergies.join(', ')}")
    end
    
    dislikes = user.dietary_preferences&.dig("dislikes") || []
    if dislikes.any?
      prefs << (lang == 'ne' ? "👎 नापसन्द: #{dislikes.join(', ')}" : "👎 Dislikes: #{dislikes.join(', ')}")
    end
    
    if user.portion_modifier && user.portion_modifier != 1.0
      percentage = (user.portion_modifier * 100).to_i
      prefs << (lang == 'ne' ? "📏 भाग आकार: #{percentage}%" : "📏 Portion size: #{percentage}%")
    end
    
    if user.ai_context.present?
      prefs << (lang == 'ne' ? "📝 नोट: #{user.ai_context}" : "📝 Note: #{user.ai_context}")
    end
    
    header = lang == 'ne' ? "तपाईंका प्राथमिकताहरू:" : "Your preferences:"
    text = "#{header}\n\n#{prefs.join("\n")}"
    
    send_message(chat_id, text)
  end

  def handle_history_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    meals = user.meals.includes(:food_items).order(eaten_at: :desc).limit(10)

    if meals.empty?
      text = lang == 'ne' ? "📜 कुनै खाना इतिहास छैन।\n\n📸 आफ्नो पहिलो खाना ट्र्याक गर्न फोटो पठाउनुहोस्!" : "📜 No meal history yet.\n\n📸 Send a photo to track your first meal!"
      send_message(chat_id, text)
      return
    end

    header = lang == 'ne' ? "📜 पछिल्लो १० खाना:" : "📜 Last 10 meals:"
    meal_lines = meals.map do |meal|
      time = meal.eaten_at.strftime("%b %d, %H:%M")
      foods = meal.food_items.map(&:name).join(", ")
      foods = foods.truncate(40) if foods.length > 40
      "• #{time}: #{foods} (#{meal.estimated_calories} kcal)"
    end

    text = "#{header}\n\n#{meal_lines.join("\n")}\n\n💡 /today · /week"
    send_message(chat_id, text)
  end

  def handle_last_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    meal = user.meals.includes(:food_items).order(eaten_at: :desc).first

    if meal.nil?
      text = lang == 'ne' ? "📭 कुनै खाना लग गरिएको छैन।" : "📭 No meals logged yet."
      send_message(chat_id, text)
      return
    end

    time = meal.eaten_at.strftime("%b %d, %H:%M")
    foods = meal.food_items.map { |f| "  • #{f.name}: #{f.calories} kcal" }.join("\n")
    health = format_health_rating(meal.health_rating)
    
    header = lang == 'ne' ? "📋 पछिल्लो खाना" : "📋 Last Meal"
    text = <<~TEXT
      #{header} (#{time})

      #{foods}

      🔢 Total: #{meal.estimated_calories} kcal
      💚 Health: #{health}/10

      💡 /undo to remove · /history for more
    TEXT

    send_message(chat_id, text)
  end

  def handle_undo_command(message)
    user = User.find_by(telegram_id: message.dig(:from, :id))
    chat_id = message.dig(:chat, :id)
    return unless user

    lang = user.language || 'en'
    meal = user.meals.order(created_at: :desc).first

    if meal.nil?
      text = lang == 'ne' ? "📭 हटाउनको लागि कुनै खाना छैन।" : "📭 No meal to undo."
      send_message(chat_id, text)
      return
    end

    foods = meal.food_items.map(&:name).join(", ")
    calories = meal.estimated_calories
    meal.destroy

    text = if lang == 'ne'
      "✅ हटाइयो: #{foods} (#{calories} kcal)"
    else
      "✅ Removed: #{foods} (#{calories} kcal)"
    end

    send_message(chat_id, text)
  end
end
