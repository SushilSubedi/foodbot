class UserFoodStatsUpdaterService
  def initialize(food_item)
    @food_item = food_item
    @user = food_item.meal.user
  end

  def update_stats
    normalized_name = normalize_food_name(@food_item.normalized_name || @food_item.name)

    stats = UserFoodStat.find_or_initialize_by(
      user: @user,
      normalized_name: normalized_name
    )

    # Update frequency
    stats.times_eaten ||= 0
    stats.times_eaten += 1
    stats.last_eaten_at = @food_item.created_at || Time.current
    stats.first_eaten_at ||= stats.last_eaten_at

    # Update running averages using incremental mean formula
    update_average(stats, :avg_calories, @food_item.calories)
    update_average(stats, :avg_protein_g, @food_item.protein_g)
    update_average(stats, :avg_carbs_g, @food_item.carbs_g)
    update_average(stats, :avg_fat_g, @food_item.fat_g)

    # Track meal type
    meal_type = @food_item.meal.meal_type
    stats.most_common_meal_type = update_most_common(
      stats.most_common_meal_type,
      meal_type,
      stats.times_eaten
    )

    # Track portion variations
    portion = @food_item.quantity
    if portion.present?
      stats.portion_variations ||= []
      stats.portion_variations << portion unless stats.portion_variations.include?(portion)
      stats.portion_variations = stats.portion_variations.last(10) # Keep last 10
    end

    # Calculate health score
    stats.health_score = calculate_health_score(stats)

    stats.save!
    stats
  end

  private

  def normalize_food_name(name)
    return "unknown" if name.blank?

    name.to_s.downcase
      .gsub(/\b(boiled|fried|steamed|grilled|roasted|raw|cooked)\b/, "")
      .gsub(/[^a-z0-9\s]/, "")
      .strip
      .gsub(/\s+/, "_")
  end

  def update_average(stats, field, new_value)
    return unless new_value

    old_avg = stats.send(field) || 0
    count = stats.times_eaten
    new_avg = old_avg + (new_value - old_avg) / count.to_f
    stats.send("#{field}=", new_avg.round(2))
  end

  def update_most_common(current, new_type, times_eaten)
    return new_type if current.nil? || (times_eaten % 5).zero?
    current
  end

  def calculate_health_score(stats)
    score = 50 # Start neutral

    # Protein bonus (up to +20)
    if stats.avg_calories && stats.avg_calories > 0
      protein_ratio = (stats.avg_protein_g || 0) / (stats.avg_calories / 4.0)
      score += [protein_ratio * 100, 20].min
    end

    # Calorie density penalty (up to -15)
    weight_estimate = 100 # Assume 100g portion
    cal_density = (stats.avg_calories || 0) / weight_estimate
    score -= [cal_density * 5, 15].min if cal_density > 3

    # Fat ratio check (neutral to -10)
    if stats.avg_calories && stats.avg_calories > 0
      fat_ratio = (stats.avg_fat_g || 0) / (stats.avg_calories / 9.0)
      score -= 10 if fat_ratio > 0.4 # >40% fat
    end

    [[score.round, 1].max, 100].min # Clamp between 1-100
  end
end
