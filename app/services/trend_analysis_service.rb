class TrendAnalysisService
  def initialize(user, period_type: "week")
    @user = user
    @period_type = period_type
  end

  def generate_report
    period_start, period_end = calculate_period
    meals = fetch_meals(period_start, period_end)

    return nil if meals.empty?

    trend = NutritionTrend.find_or_initialize_by(
      user: @user,
      period_start: period_start,
      period_type: @period_type
    )

    trend.period_end = period_end
    trend.total_meals_logged = meals.count

    # Daily averages
    days_count = (period_end - period_start).to_i + 1
    trend.avg_daily_calories = total_calories(meals) / days_count.to_f
    trend.avg_daily_protein_g = total_protein(meals) / days_count.to_f
    trend.avg_daily_carbs_g = total_carbs(meals) / days_count.to_f
    trend.avg_daily_fat_g = total_fat(meals) / days_count.to_f

    # Patterns
    trend.day_of_week_breakdown = analyze_by_day_of_week(meals)
    trend.meal_type_breakdown = analyze_by_meal_type(meals)
    trend.top_foods = calculate_top_foods(meals)

    # Goal tracking
    trend.days_met_calorie_goal = days_within_goal(meals)
    trend.days_met_protein_goal = days_met_protein_target(meals)
    trend.goal_adherence_percentage = calculate_adherence(trend)

    trend.save!
    trend
  end

  def summary_message
    trend = generate_report
    lang = @user.language || 'en'
    return t('trends_no_data', lang) unless trend

    title_key = @period_type == 'month' ? 'trends_title_month' : 'trends_title_week'
    period_text = t('trends_period', lang, start: trend.period_start.strftime('%b %d'), end: trend.period_end.strftime('%b %d, %Y'))

    <<~MESSAGE
      #{t(title_key, lang)}

      #{period_text}

      #{t('trends_daily_averages', lang)}
      🔥 Calories: #{trend.avg_daily_calories.round} kcal
      🥩 Protein: #{trend.avg_daily_protein_g.round}g
      🍚 Carbs: #{trend.avg_daily_carbs_g.round}g
      🥑 Fat: #{trend.avg_daily_fat_g.round}g

      #{t('trends_patterns', lang)}
      #{pattern_insights(trend, lang)}

      #{t('trends_goal_achievement', lang)}
      #{t('trends_met_calorie_goal', lang, days: trend.days_met_calorie_goal)}
      #{t('trends_adherence', lang, percent: trend.goal_adherence_percentage.round)}

      #{t('trends_top_foods', lang)}
      #{top_foods_list(trend, lang)}
    MESSAGE
  end

  private

  def calculate_period
    case @period_type
    when "week"
      end_date = Date.current
      start_date = end_date - 6.days
    when "month"
      end_date = Date.current
      start_date = end_date - 29.days
    else
      end_date = Date.current
      start_date = end_date - 6.days
    end
    [start_date, end_date]
  end

  def fetch_meals(start_date, end_date)
    @user.meals
      .where("eaten_at >= ? AND eaten_at <= ?",
             start_date.beginning_of_day,
             end_date.end_of_day)
      .includes(:food_items)
  end

  def total_calories(meals)
    meals.sum { |m| m.food_items.sum(&:calories) }
  end

  def total_protein(meals)
    meals.sum { |m| m.food_items.sum { |fi| fi.protein_g || 0 } }
  end

  def total_carbs(meals)
    meals.sum { |m| m.food_items.sum { |fi| fi.carbs_g || 0 } }
  end

  def total_fat(meals)
    meals.sum { |m| m.food_items.sum { |fi| fi.fat_g || 0 } }
  end

  def analyze_by_day_of_week(meals)
    grouped = meals.group_by { |m| m.eaten_at.strftime("%A").downcase }

    grouped.transform_values do |day_meals|
      {
        "meals" => day_meals.count,
        "calories" => day_meals.count > 0 ? (total_calories(day_meals) / day_meals.count.to_f).round : 0
      }
    end
  end

  def analyze_by_meal_type(meals)
    grouped = meals.group_by(&:meal_type)

    grouped.compact.transform_values do |type_meals|
      {
        "count" => type_meals.count,
        "avg_calories" => type_meals.count > 0 ? (total_calories(type_meals) / type_meals.count.to_f).round : 0
      }
    end
  end

  def calculate_top_foods(meals)
    food_counts = Hash.new(0)

    meals.each do |meal|
      meal.food_items.each do |item|
        normalized = (item.normalized_name || item.name).to_s.downcase.strip
        food_counts[normalized] += 1 if normalized.present?
      end
    end

    food_counts.sort_by { |_, count| -count }
      .first(5)
      .map { |name, count| { "name" => name, "count" => count } }
  end

  def days_within_goal(meals)
    goal_calories = CalorieGoalService.new(@user).recommended_calories
    tolerance = 100 # ±100 calories

    daily_totals = meals.group_by { |m| m.eaten_at.to_date }
                        .transform_values { |day_meals| total_calories(day_meals) }

    daily_totals.count do |_, total|
      (total - goal_calories).abs <= tolerance ||
      (total >= goal_calories * 0.9 && total <= goal_calories * 1.1)
    end
  end

  def days_met_protein_target(meals)
    targets = CalorieGoalService.new(@user).macro_targets
    protein_target = targets[:protein_g]

    daily_totals = meals.group_by { |m| m.eaten_at.to_date }
                        .transform_values { |day_meals| total_protein(day_meals) }

    daily_totals.count { |_, total| total >= protein_target * 0.8 }
  end

  def calculate_adherence(trend)
    total_possible_days = (trend.period_end - trend.period_start).to_i + 1
    met_days = [trend.days_met_calorie_goal || 0, trend.days_met_protein_goal || 0].max

    (met_days.to_f / total_possible_days * 100).round(1)
  end

  def pattern_insights(trend, lang = 'en')
    insights = []

    # Weekend eating pattern
    if trend.day_of_week_breakdown.present?
      weekend_avg = %w[saturday sunday].sum do |day|
        trend.day_of_week_breakdown.dig(day, "calories") || 0
      end / 2.0

      weekday_days = %w[monday tuesday wednesday thursday friday]
      weekday_sum = weekday_days.sum do |day|
        trend.day_of_week_breakdown.dig(day, "calories") || 0
      end
      weekday_avg = weekday_sum / 5.0

      if weekday_avg > 0 && weekend_avg > weekday_avg * 1.2
        diff_pct = ((weekend_avg - weekday_avg) / weekday_avg * 100).round
        insights << t('trends_weekend_pattern', lang, percent: diff_pct)
      end
    end

    # Meal skipping
    if trend.meal_type_breakdown.present?
      total_days = (trend.period_end - trend.period_start).to_i + 1
      breakfast_count = trend.meal_type_breakdown.dig("breakfast", "count") || 0

      if breakfast_count < total_days * 0.5
        insights << t('trends_breakfast_pattern', lang, count: breakfast_count, total: total_days)
      end
    end

    insights.empty? ? t('trends_no_patterns', lang) : insights.join("\n")
  end

  def top_foods_list(trend, lang = 'en')
    return t('trends_no_foods', lang) if trend.top_foods.blank?

    trend.top_foods.map.with_index do |food, idx|
      "#{idx + 1}. #{food['name'].to_s.titleize} (#{food['count']}×)"
    end.join("\n")
  end

  def t(key, lang, params = {})
    TranslationService.t(key, lang, params)
  end
end
