class PreferenceApplierService
  VALID_HEALTH_GOALS = %w[maintain weight_loss muscle_gain diabetic_friendly].freeze
  VALID_ACTIVITY_LEVELS = %w[sedentary light moderate very_active extremely_active].freeze

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

  def to_boolean(value)
    case value
    when true, "true", 1, "1", "yes" then true
    when false, "false", 0, "0", "no" then false
    else !!value
    end
  end
end
