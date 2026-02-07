class MealReminderService
  MEAL_TYPES = %w[breakfast lunch dinner snack].freeze

  DEFAULT_MEAL_TIMES = {
    "breakfast" => "06:00",
    "lunch" => "11:00",
    "dinner" => "19:30",
    "snack" => "15:00"
  }.freeze

  def initialize(user)
    @user = user
  end

  def should_send_reminder?(meal_type)
    return false unless @user.meal_reminders_enabled
    return false unless reminder_enabled_for_meal?(meal_type)
    return false if recently_reminded?
    return false if in_fasting_window?

    !logged_meal_today?(meal_type) && past_meal_time?(meal_type)
  end

  def send_reminder(meal_type)
    return unless should_send_reminder?(meal_type)

    message = reminder_message(meal_type)
    send_telegram_message(message)

    @user.update(last_reminder_sent_at: Time.current)
    true
  end

  def check_and_send_all_reminders
    sent = false
    MEAL_TYPES.each do |meal_type|
      sent = true if send_reminder(meal_type)
    end
    sent
  end

  def next_reminder_time
    return nil unless @user.meal_reminders_enabled

    current_time = Time.current.in_time_zone(@user.timezone)

    MEAL_TYPES.each do |meal_type|
      next unless reminder_enabled_for_meal?(meal_type)
      next if logged_meal_today?(meal_type)

      meal_time = parse_meal_time(meal_type)
      reminder_time = meal_time + 30.minutes

      return reminder_time if reminder_time > current_time
    end

    nil
  end

  private

  def reminder_enabled_for_meal?(meal_type)
    settings = @user.meal_reminder_settings || {}
    settings[meal_type.to_s] == true || settings[meal_type.to_s] == "true"
  end

  def recently_reminded?
    return false unless @user.last_reminder_sent_at

    @user.last_reminder_sent_at > 2.hours.ago
  end

  def in_fasting_window?
    return false unless @user.intermittent_fasting_enabled?
    !@user.in_eating_window?
  end

  def logged_meal_today?(meal_type)
    user_today = Date.current.in_time_zone(@user.timezone)

    @user.meals
      .where("eaten_at >= ? AND eaten_at < ?",
             user_today.beginning_of_day,
             user_today.end_of_day)
      .where(meal_type: meal_type)
      .exists?
  end

  def past_meal_time?(meal_type)
    current_time = Time.current.in_time_zone(@user.timezone)
    meal_time = parse_meal_time(meal_type)
    grace_period = 30.minutes

    current_time > (meal_time + grace_period)
  end

  def parse_meal_time(meal_type)
    time_string = @user.meal_timing_preferences&.dig(meal_type.to_s) ||
                  DEFAULT_MEAL_TIMES[meal_type]

    today = Date.current.in_time_zone(@user.timezone)
    Time.zone.parse("#{today} #{time_string}")
  end

  def reminder_message(meal_type)
    hour = Time.current.in_time_zone(@user.timezone).hour

    greeting = case hour
    when 5..11 then "Good morning"
    when 12..16 then "Hi there"
    when 17..21 then "Good evening"
    else "Hey"
    end

    goal_tip = goal_specific_tip

    <<~MESSAGE
      #{greeting}! 👋

      I noticed you haven't logged your #{meal_type} yet today.

      #{goal_tip}

      📸 Send a photo of your meal, or
      ✍️ Just describe what you ate!

      Example: "Dal bhat with chicken curry and saag"
    MESSAGE
  end

  def goal_specific_tip
    case @user.health_goal
    when "weight_loss"
      "💡 Tip: Include vegetables to feel full with fewer calories!"
    when "muscle_gain"
      "💪 Tip: Don't forget to include protein in this meal!"
    when "diabetic_friendly"
      "🩺 Tip: Choose whole grains and include fiber-rich foods."
    else
      "🍽️ Regular logging helps you stay on track!"
    end
  end

  def send_telegram_message(message)
    TelegramService.new.send_message(
      chat_id: @user.telegram_id,
      text: message
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send reminder to user #{@user.id}: #{e.message}")
    false
  end
end
