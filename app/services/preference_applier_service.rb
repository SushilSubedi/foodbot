class PreferenceApplierService
  VALID_HEALTH_GOALS = %w[maintain weight_loss muscle_gain diabetic_friendly].freeze
  VALID_ACTIVITY_LEVELS = %w[sedentary light moderate very_active extremely_active].freeze
  VALID_GENDERS = %w[male female other].freeze
  VALID_FASTING_SCHEDULES = %w[16_8 14_10 18_6 20_4 custom].freeze

  def initialize(user:, signals:)
    @user = user
    @signals = signals || []
  end

  def call
    changes = []

    @signals.each do |signal|
      change = apply_signal(signal)
      changes << change if change
    end

    changes
  end

  private

  def apply_signal(signal)
    op = signal["op"]
    field = signal["field"]
    value = signal["value"]
    evidence = signal["evidence"]

    case field
    when "dietary_preferences.vegetarian"
      apply_boolean_preference("vegetarian", value, evidence)
    when "dietary_preferences.vegan"
      apply_boolean_preference("vegan", value, evidence)
    when "dietary_preferences.allergies"
      apply_list_preference("allergies", op, value, evidence)
    when "dietary_preferences.dislikes"
      apply_list_preference("dislikes", op, value, evidence)
    when "health_goal"
      apply_health_goal(value, evidence)
    when "portion_modifier"
      apply_portion_modifier(value, evidence)
    when "activity_level"
      apply_activity_level(value, evidence)
    when "language"
      apply_language(value, evidence)
    when "age"
      apply_age(value, evidence)
    when "weight_kg"
      apply_weight(value, evidence)
    when "height_cm"
      apply_height(value, evidence)
    when "gender"
      apply_gender(value, evidence)
    when "daily_calorie_goal"
      apply_calorie_goal(value, evidence)
    when "intermittent_fasting"
      apply_fasting(value, evidence)
    end
  end

  def apply_boolean_preference(key, value, evidence)
    current = @user.dietary_preferences&.dig(key)
    bool_value = to_boolean(value)
    return nil if current == bool_value

    @user.update_dietary_preference(key, bool_value)
    { field: "dietary_preferences.#{key}", old_value: current, new_value: bool_value, evidence: evidence }
  end

  def apply_list_preference(key, op, value, evidence)
    normalized = value.to_s.strip.downcase
    return nil if normalized.blank?

    current_list = @user.dietary_preferences&.dig(key) || []

    case op
    when "add"
      return nil if current_list.include?(normalized)
      if key == "allergies"
        @user.add_allergy(normalized)
      else
        @user.add_dislike(normalized)
      end
      { field: "dietary_preferences.#{key}", op: "add", value: normalized, evidence: evidence }
    when "remove"
      return nil unless current_list.include?(normalized)
      if key == "allergies"
        @user.remove_allergy(normalized)
      else
        prefs = (@user.dietary_preferences || {}).dup
        dislikes = prefs["dislikes"] || []
        dislikes.delete(normalized)
        prefs["dislikes"] = dislikes
        @user.update!(dietary_preferences: prefs)
      end
      { field: "dietary_preferences.#{key}", op: "remove", value: normalized, evidence: evidence }
    end
  end

  def apply_health_goal(value, evidence)
    normalized = value.to_s.strip.downcase.gsub(/\s+/, "_")
    return nil unless VALID_HEALTH_GOALS.include?(normalized)
    return nil if @user.health_goal == normalized

    old_value = @user.health_goal
    @user.update!(health_goal: normalized)
    { field: "health_goal", old_value: old_value, new_value: normalized, evidence: evidence }
  end

  def apply_portion_modifier(value, evidence)
    float_value = value.to_f.clamp(0.5, 2.0).round(2)
    return nil if @user.portion_modifier == float_value

    old_value = @user.portion_modifier
    @user.update!(portion_modifier: float_value)
    { field: "portion_modifier", old_value: old_value, new_value: float_value, evidence: evidence }
  end

  def apply_activity_level(value, evidence)
    normalized = value.to_s.strip.downcase.gsub(/\s+/, "_")
    return nil unless VALID_ACTIVITY_LEVELS.include?(normalized)
    return nil if @user.activity_level == normalized

    old_value = @user.activity_level
    @user.update!(activity_level: normalized)
    { field: "activity_level", old_value: old_value, new_value: normalized, evidence: evidence }
  end

  def apply_language(value, evidence)
    normalized = value.to_s.strip.downcase
    return nil unless %w[en ne].include?(normalized)
    return nil if @user.language == normalized

    old_value = @user.language
    @user.update!(language: normalized)
    { field: "language", old_value: old_value, new_value: normalized, evidence: evidence }
  end

  def apply_age(value, evidence)
    age = value.to_i
    return nil unless age > 0 && age < 150
    return nil if @user.age == age

    old_value = @user.age
    @user.update!(age: age)
    { field: "age", old_value: old_value, new_value: age, evidence: evidence }
  end

  def apply_weight(value, evidence)
    weight = value.to_f.round(2)
    return nil unless weight > 20 && weight < 500
    return nil if @user.weight_kg == weight

    old_value = @user.weight_kg
    @user.update!(weight_kg: weight)
    @user.update_tdee! if @user.biometrics_complete?
    { field: "weight_kg", old_value: old_value, new_value: weight, evidence: evidence }
  end

  def apply_height(value, evidence)
    height = value.to_f.round(1)
    return nil unless height > 50 && height < 300
    return nil if @user.height_cm == height

    old_value = @user.height_cm
    @user.update!(height_cm: height)
    @user.update_tdee! if @user.biometrics_complete?
    { field: "height_cm", old_value: old_value, new_value: height, evidence: evidence }
  end

  def apply_gender(value, evidence)
    normalized = value.to_s.strip.downcase
    return nil unless VALID_GENDERS.include?(normalized)
    return nil if @user.gender == normalized

    old_value = @user.gender
    @user.update!(gender: normalized)
    @user.update_tdee! if @user.biometrics_complete?
    { field: "gender", old_value: old_value, new_value: normalized, evidence: evidence }
  end

  def apply_calorie_goal(value, evidence)
    calories = value.to_i
    return nil unless calories >= 800 && calories <= 5000
    return nil if @user.daily_calorie_goal == calories

    old_value = @user.daily_calorie_goal
    @user.update!(daily_calorie_goal: calories, calorie_goal_mode: "manual")
    { field: "daily_calorie_goal", old_value: old_value, new_value: calories, evidence: evidence }
  end

  def apply_fasting(value, evidence)
    return nil unless value.is_a?(Hash) || value.is_a?(ActionController::Parameters)

    enabled = value["enabled"]

    if enabled == false
      return nil unless @user.intermittent_fasting_enabled?
      @user.update!(
        intermittent_fasting_enabled: false,
        eating_window_start_local: nil,
        eating_window_end_local: nil,
        fasting_schedule: nil
      )
      return { field: "intermittent_fasting", old_value: "enabled", new_value: "disabled", evidence: evidence }
    end

    schedule = value["schedule"].to_s
    return nil unless VALID_FASTING_SCHEDULES.include?(schedule)

    if schedule == "custom"
      start_time = parse_time(value["start"])
      end_time = parse_time(value["end"])
      return nil unless start_time && end_time

      @user.update!(
        intermittent_fasting_enabled: true,
        fasting_schedule: "custom",
        eating_window_start_local: start_time,
        eating_window_end_local: end_time
      )
    else
      preset = User::FASTING_SCHEDULES[schedule]
      return nil unless preset

      @user.update!(
        intermittent_fasting_enabled: true,
        fasting_schedule: schedule,
        eating_window_start_local: Time.zone.parse(preset[:start]),
        eating_window_end_local: Time.zone.parse(preset[:end])
      )
    end

    { field: "intermittent_fasting", old_value: @user.intermittent_fasting_enabled_before_last_save ? "enabled" : "disabled", new_value: "enabled (#{schedule})", evidence: evidence }
  end

  def parse_time(time_str)
    return nil unless time_str.present?
    Time.zone.parse(time_str.to_s.strip)
  rescue ArgumentError
    nil
  end

  def to_boolean(value)
    case value
    when true, "true", 1, "1", "yes" then true
    when false, "false", 0, "0", "no" then false
    else !!value
    end
  end
end
