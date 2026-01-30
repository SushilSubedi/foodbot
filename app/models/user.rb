class User < ApplicationRecord
  # Associations
  has_many :meals, dependent: :destroy
  has_many :user_daily_stats, dependent: :destroy

  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :language, inclusion: { in: %w[en ne], allow_nil: true }
  validates :timezone, presence: true

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
    return nil unless has_preferences?

    context_parts = []
    
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
    
    # Custom notes
    context_parts << "Notes: #{ai_context}" if ai_context.present?
    
    context_parts.join("\n")
  end
end
