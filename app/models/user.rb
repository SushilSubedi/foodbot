class User < ApplicationRecord
  # Associations
  has_many :meals, dependent: :destroy
  has_many :user_daily_stats, dependent: :destroy
  has_many :user_food_stats, dependent: :destroy
  has_many :nutrition_trends, dependent: :destroy

  # Enums
  enum :health_goal, {
    maintain: "maintain",
    weight_loss: "weight_loss",
    muscle_gain: "muscle_gain",
    diabetic_friendly: "diabetic_friendly"
  }, default: :maintain

  enum :activity_level, {
    sedentary: "sedentary",
    light: "light",
    moderate: "moderate",
    very_active: "very_active",
    extremely_active: "extremely_active"
  }, default: :sedentary, prefix: true

  enum :calorie_goal_mode, {
    manual: "manual",
    auto: "auto"
  }, default: :manual, prefix: true

  # Activity multipliers for TDEE calculation
  ACTIVITY_MULTIPLIERS = {
    "sedentary" => 1.2,
    "light" => 1.375,
    "moderate" => 1.55,
    "very_active" => 1.725,
    "extremely_active" => 1.9
  }.freeze

  # Fasting schedule presets (eating window hours)
  FASTING_SCHEDULES = {
    "16_8" => { start: "12:00", end: "20:00", name: "16:8 (12pm-8pm)" },
    "14_10" => { start: "10:00", end: "20:00", name: "14:10 (10am-8pm)" },
    "18_6" => { start: "12:00", end: "18:00", name: "18:6 (12pm-6pm)" },
    "20_4" => { start: "14:00", end: "18:00", name: "20:4 (2pm-6pm)" }
  }.freeze

  # Scopes
  scope :with_biometrics, -> { where.not(age: nil, weight_kg: nil, height_cm: nil, gender: nil) }
  scope :with_if_enabled, -> { where(intermittent_fasting_enabled: true) }
  scope :with_reminders_enabled, -> { where(meal_reminders_enabled: true) }
  scope :active_recently, -> { where("last_seen_at > ?", 7.days.ago) }

  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :language, inclusion: { in: %w[en ne], allow_nil: true }
  validates :timezone, presence: true
  validates :age, numericality: { greater_than: 0, less_than: 150 }, allow_nil: true
  validates :weight_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :height_cm, numericality: { greater_than: 0 }, allow_nil: true
  validates :gender, inclusion: { in: %w[male female other] }, allow_nil: true

  def pending_context_data
    return nil if pending_context.blank?
    JSON.parse(pending_context, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  def set_pending_context(data)
    update!(pending_context: data.to_json)
  end

  def clear_pending_context
    update!(pending_context: nil)
  end

  def has_pending_context?
    pending_context.present?
  end

  def first_time_user?
    last_seen_at.nil?
  end

  def first_time_today?
    return false if last_seen_at.nil?
    last_seen_at.to_date < Date.today
  end

  def check_daily_limit!
    # Reset limit if it's a new day
    if last_process_date != Date.today
      update(images_processed_count: 0, last_process_date: Date.today)
    end
    
    # Check if limit reached
    # Default limit is 3 if not set
    limit = daily_limit || 3
    
    # Allow if processed count is less than limit
    if images_processed_count < limit
      increment!(:images_processed_count)
      return true
    else
      return false
    end
  end

  def update_last_seen!
    update!(last_seen_at: Time.current)
  end

  # Preference management
  def update_dietary_preference(key, value)
    prefs = (dietary_preferences || {}).dup
    prefs[key.to_s] = value
    update!(dietary_preferences: prefs)
  end

  def add_allergy(food)
    prefs = (dietary_preferences || {}).dup
    allergies = prefs["allergies"] || []
    allergies << food.strip.downcase unless allergies.include?(food.strip.downcase)
    prefs["allergies"] = allergies
    update!(dietary_preferences: prefs)
  end

  def remove_allergy(food)
    prefs = (dietary_preferences || {}).dup
    allergies = prefs["allergies"] || []
    allergies.delete(food.strip.downcase)
    prefs["allergies"] = allergies
    update!(dietary_preferences: prefs)
  end

  def add_dislike(food)
    prefs = (dietary_preferences || {}).dup
    dislikes = prefs["dislikes"] || []
    dislikes << food.strip.downcase unless dislikes.include?(food.strip.downcase)
    prefs["dislikes"] = dislikes
    update!(dietary_preferences: prefs)
  end

  def adjust_portion_size(direction)
    current = portion_modifier || 1.0
    new_value = case direction.to_s
    when "larger"
      [current + 0.1, 2.0].min
    when "smaller"
      [current - 0.1, 0.5].max
    when "normal"
      1.0
    else
      current
    end
    update!(portion_modifier: new_value.round(2))
  end

  # Preference getters
  def is_vegetarian?
    dietary_preferences&.dig("vegetarian") == true
  end

  def is_vegan?
    dietary_preferences&.dig("vegan") == true
  end

  def has_allergies?
    (dietary_preferences&.dig("allergies") || []).any?
  end

  def has_preferences?
    is_vegetarian? || is_vegan? || has_allergies? || 
    (dietary_preferences&.dig("dislikes") || []).any? ||
    portion_modifier != 1.0 || ai_context.present?
  end

  def ai_context_summary
    return nil unless has_preferences? || has_health_profile?

    context_parts = []

    # Health goal
    if health_goal.present? && health_goal != "maintain"
      goal_descriptions = {
        "weight_loss" => "Weight Loss (calorie deficit recommended)",
        "muscle_gain" => "Muscle Gain (protein priority, calorie surplus)",
        "diabetic_friendly" => "Diabetic-Friendly (low GI, reduced carbs/sugar)"
      }
      context_parts << "Goal: #{goal_descriptions[health_goal]}"
    end

    # Calorie target
    target = recommended_daily_calories
    if target
      context_parts << "Daily Calorie Target: #{target} kcal"
    end

    # Dietary restrictions
    dietary_parts = []
    dietary_parts << "Vegetarian" if is_vegetarian?
    dietary_parts << "Vegan" if is_vegan?
    allergies = dietary_preferences&.dig("allergies") || []
    if allergies.any?
      dietary_parts << "Allergic to: #{allergies.join(', ')}"
    end
    dislikes = dietary_preferences&.dig("dislikes") || []
    if dislikes.any?
      dietary_parts << "Dislikes: #{dislikes.join(', ')}"
    end

    context_parts << "Dietary: #{dietary_parts.join(', ')}" if dietary_parts.any?

    # Portion size
    if portion_modifier && portion_modifier != 1.0
      percentage = (portion_modifier * 100).to_i
      if portion_modifier > 1.0
        context_parts << "Portion Size: User's portions are typically #{percentage}% of standard servings (larger than average)"
      elsif portion_modifier < 1.0
        context_parts << "Portion Size: User's portions are typically #{percentage}% of standard servings (smaller than average)"
      end
    end

    # Intermittent fasting
    if intermittent_fasting_enabled?
      window_info = eating_window_start_local && eating_window_end_local ?
        "#{eating_window_start_local.strftime('%H:%M')}-#{eating_window_end_local.strftime('%H:%M')}" :
        fasting_schedule&.gsub("_", ":")
      context_parts << "Intermittent Fasting: #{window_info} eating window"
      context_parts << "Currently #{in_eating_window? ? 'IN' : 'OUTSIDE'} eating window" if can_check_eating_window?
    end

    # Custom notes
    context_parts << "Notes: #{ai_context}" if ai_context.present?

    context_parts.join("\n")
  end

  # Health profile methods
  def has_health_profile?
    health_goal != "maintain" || biometrics_complete? || intermittent_fasting_enabled?
  end

  def biometrics_complete?
    age.present? && gender.present? && weight_kg.present? && height_cm.present?
  end

  def calculate_bmr
    return nil unless biometrics_complete?

    # Mifflin-St Jeor equation
    if gender == "male"
      (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
    else
      (10 * weight_kg) + (6.25 * height_cm) - (5 * age) - 161
    end
  end

  def calculate_tdee
    bmr = calculate_bmr
    return nil unless bmr

    multiplier = ACTIVITY_MULTIPLIERS[activity_level] || 1.2
    (bmr * multiplier).round
  end

  def recommended_daily_calories
    return daily_calorie_goal if calorie_goal_mode_manual?

    tdee = tdee_calories || calculate_tdee
    return daily_calorie_goal unless tdee

    case health_goal
    when "weight_loss"
      [tdee - 500, gender == "female" ? 1200 : 1500].max
    when "muscle_gain"
      tdee + 300
    else
      tdee
    end
  end

  def update_tdee!
    new_tdee = calculate_tdee
    update!(tdee_calories: new_tdee) if new_tdee
    new_tdee
  end

  # Intermittent fasting methods
  def can_check_eating_window?
    intermittent_fasting_enabled? && eating_window_start_local.present? && eating_window_end_local.present?
  end

  def in_eating_window?(time = Time.current)
    return true unless can_check_eating_window?

    user_time = time.in_time_zone(timezone)
    current_minutes = user_time.hour * 60 + user_time.min

    start_minutes = eating_window_start_local.hour * 60 + eating_window_start_local.min
    end_minutes = eating_window_end_local.hour * 60 + eating_window_end_local.min

    if end_minutes > start_minutes
      current_minutes >= start_minutes && current_minutes <= end_minutes
    else
      current_minutes >= start_minutes || current_minutes <= end_minutes
    end
  end

  def meal_timing_for(meal_type)
    meal_timing_preferences&.dig(meal_type.to_s)
  end

  # Top foods for this user
  def top_foods(limit = 5)
    user_food_stats.frequently_eaten.limit(limit)
  end

  def recently_eaten_foods(limit = 10)
    user_food_stats.recently_eaten.limit(limit)
  end

  # Fasting status helpers
  def fasting_status_message
    return nil unless intermittent_fasting_enabled?

    current_time = Time.current.in_time_zone(timezone)

    if in_eating_window?
      if eating_window_end_local
        end_time = eating_window_end_local
        hours_remaining = ((end_time.hour * 60 + end_time.min) - (current_time.hour * 60 + current_time.min)) / 60.0
        hours_remaining += 24 if hours_remaining < 0
        "🍴 Eating window open (#{hours_remaining.round(1)}h remaining)"
      else
        "🍴 Eating window open"
      end
    else
      if eating_window_start_local
        start_time = eating_window_start_local
        hours_until = ((start_time.hour * 60 + start_time.min) - (current_time.hour * 60 + current_time.min)) / 60.0
        hours_until += 24 if hours_until < 0
        "⏸️ Fasting (#{hours_until.round(1)}h until eating window)"
      else
        "⏸️ Currently fasting"
      end
    end
  end

  # Profile completion tracking
  def profile_completion_percentage
    fields = [
      dietary_preferences.present? && dietary_preferences != {},
      (dietary_preferences&.dig("allergies") || []).any?,
      portion_modifier.present? && portion_modifier != 1.0,
      daily_calorie_goal.present?,
      timezone.present?,
      health_goal.present? && health_goal != "maintain",
      activity_level.present?,
      biometrics_complete?
    ]

    completed = fields.count(true)
    total = fields.size
    (completed.to_f / total * 100).round
  end

  def needs_profile_completion?
    profile_completion_percentage < 50
  end

  def profile_completion_tips
    tips = []

    tips << "Set your health goal (/setgoal)" unless health_goal.present? && health_goal != "maintain"
    tips << "Add your biometrics for accurate calorie targets (/setbio)" unless biometrics_complete?
    tips << "Set your activity level (/setactivity)" unless activity_level.present?
    tips << "Add any food allergies (/allergies)" unless (dietary_preferences&.dig("allergies") || []).any?

    tips.first(3)
  end

  # Macro targets delegation
  def macro_targets
    CalorieGoalService.new(self).macro_targets
  end

  # Allergies accessor
  def allergies
    dietary_preferences&.dig("allergies") || []
  end

  # Dislikes accessor
  def dislikes
    dietary_preferences&.dig("dislikes") || []
  end
end
