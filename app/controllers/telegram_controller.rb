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

    welcome_text = <<~TEXT
      🙏 Namaste, #{name}!

      I'm your AI nutrition assistant. Send me a food photo and I'll estimate calories & macros.

      🍛 Optimized for Nepali food
      ⚡ Results in 5-10 seconds
      📊 Tracks protein, carbs & fat

      📸 Send a food photo to get started!

      Commands: /help · /about
    TEXT

    send_message(message.dig(:chat, :id), welcome_text)
  end

  def handle_help_command(message)
    help_text = <<~TEXT
      📖 How to Use FoodBot

      1. 📸 Send a food photo
      2. ✏️ Add caption (optional)
      3. ⏳ Wait 5-10 seconds
      4. 📊 Get nutrition info

      💡 Tips for best results:
      • Good lighting
      • One meal per photo
      • Add caption like "momo, 8 pieces"

      🍽️ I recognize: Dal bhat, momo, chowmein, thukpa, samosa & more!
    TEXT

    send_message(message.dig(:chat, :id), help_text)
  end

  def handle_about_command(message)
    about_text = <<~TEXT
      🤖 FoodBot v1.0

      AI-powered calorie tracking for Nepali cuisine 🇳🇵

      🧠 Powered by GPT-4o Vision
      📊 Estimates: Calories, Protein, Carbs, Fat
      🍛 Knows: Dal bhat, momo, tarkari, achar & more

      ⚠️ These are estimates only, not medical advice.

      Built with ❤️ in Nepal
    TEXT

    send_message(message.dig(:chat, :id), about_text)
  end

  def handle_photo_message(message)
    chat_id = message.dig(:chat, :id)
    
    send_message(chat_id, "📸 Got it! Analyzing your meal...\n⏳ This takes about 5-10 seconds")
    
    # Process image
    photo = message[:photo].last
    file_id = photo[:file_id]
    caption = message[:caption]
    
    process_image(chat_id, file_id, caption)
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

  def process_image(chat_id, file_id, caption)
    service = TelegramService.new
    image_url = service.get_file_url(file_id)
    
    unless image_url
      send_error_message(chat_id)
      return
    end
    
    user = User.find_by(telegram_id: chat_id)
    unless user
      send_message(chat_id, "Please send /start first.")
      return
    end
    
    analysis = ImageAnalysisService.new(image_url, caption).call
    
    if analysis
      handle_analysis_response(user, analysis, image_url, caption, chat_id)
    else
      send_error_message(chat_id)
    end
  end

  def handle_analysis_response(user, analysis, image_url, caption, chat_id)
    case analysis['status']
    when 'success'
      handle_successful_analysis(user, analysis, image_url, caption, chat_id)
    when 'uncertain'
      handle_uncertain_analysis(user, analysis, image_url, chat_id)
    when 'not_food'
      handle_not_food(analysis, chat_id)
    when 'failed'
      handle_failed_analysis(analysis, chat_id)
    else
      send_error_message(chat_id)
    end
  end

  def handle_not_food(analysis, chat_id)
    detected = analysis['detected_object'] || 'something else'
    text = <<~TEXT
      🤷 Hmm, that doesn't look like food to me!

      I see: #{detected}

      📸 Please send a photo of your actual meal (dal bhat, momo, etc.) and I'll analyze it for you!
    TEXT

    send_message(chat_id, text)
  end

  def handle_successful_analysis(user, analysis, image_url, caption, chat_id)
    if analysis['confidence'] >= 0.7
      meal = save_meal(user, analysis, image_url, caption)
      response = format_high_confidence_response(analysis)
    elsif analysis['confidence'] >= 0.4
      meal = save_meal(user, analysis, image_url, caption)
      response = format_medium_confidence_response(analysis)
    else
      response = format_low_confidence_response(analysis)
    end
    
    send_message(chat_id, response)
  end

  def handle_uncertain_analysis(user, analysis, image_url, chat_id)
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

    send_message(chat_id, text)
  end

  def handle_failed_analysis(analysis, chat_id)
    text = <<~TEXT
      😕 #{analysis['reason']}

      #{analysis['retry_tip']}
    TEXT
    
    send_message(chat_id, text)
  end

  def save_meal(user, analysis, image_url, caption)
    meal = user.meals.create!(
      meal_type: analysis['meal_type'],
      input_type: 'image',
      image_url: image_url,
      raw_input: caption,
      estimated_calories: analysis['total']['calories'],
      confidence_score: analysis['confidence'],
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
    
    meal
  end

  def format_high_confidence_response(analysis)
    if analysis['foods'].length == 1
      format_single_food_response(analysis)
    else
      format_multiple_foods_response(analysis)
    end
  end

  def format_single_food_response(analysis)
    food = analysis['foods'].first
    confidence_pct = (analysis['confidence'] * 100).to_i

    <<~TEXT
      ✅ #{food['name'].capitalize}

      🔥 #{food['calories']} kcal

      📊 Macros:
        Protein: #{food['protein_g'].round(1)}g
        Carbs: #{food['carbs_g'].round(1)}g
        Fat: #{food['fat_g'].round(1)}g

      ⚖️ #{translate_balance(analysis['balance'])}
      💡 #{analysis['advice']}

      📝 Logged as #{translate_meal_type(analysis['meal_type']).downcase} (#{confidence_pct}% confident)
    TEXT
  end

  def format_multiple_foods_response(analysis)
    foods_text = analysis['foods'].map.with_index do |food, idx|
      "  #{idx + 1}. #{food['name']} — #{food['calories']} kcal"
    end.join("\n")
    confidence_pct = (analysis['confidence'] * 100).to_i

    <<~TEXT
      ✅ Meal Logged (#{analysis['foods'].length} items)

      #{foods_text}
      🔥 Total: #{analysis['total']['calories']} kcal

      📊 Macros:
        Protein: #{analysis['total']['protein_g'].round(1)}g
        Carbs: #{analysis['total']['carbs_g'].round(1)}g
        Fat: #{analysis['total']['fat_g'].round(1)}g

      ⚖️ #{translate_balance(analysis['balance'])}
      💡 #{analysis['advice']}

      📝 #{confidence_pct}% confident
    TEXT
  end

  def format_medium_confidence_response(analysis)
    response = format_high_confidence_response(analysis)
    assumptions = analysis['assumptions'].map { |a| "  • #{a}" }.join("\n")

    "#{response}\n⚠️ Assumptions:\n#{assumptions}"
  end

  def format_low_confidence_response(analysis)
    foods = analysis['foods'].map { |f| "  • #{f['name']}" }.join("\n")
    cal_range = "#{analysis['total']['calories'] - 50}–#{analysis['total']['calories'] + 50}"

    <<~TEXT
      🤔 I made my best guess, but I'm not very confident

      Possible food:
      #{foods}

      Estimated calories: #{cal_range} kcal

      💬 Reply with food name or portion to get accurate results
      Example: "chicken curry" or "small portion"
    TEXT
  end

  def send_error_message(chat_id)
    text = <<~TEXT
      😕 Oops! Something went wrong.

      📸 Please try again with:
        • A clearer photo
        • Better lighting
        • One meal per image

      Still having issues? Send /help for tips!
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

  def send_message(chat_id, text)
    TelegramService.new.send_message(chat_id: chat_id, text: text)
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
