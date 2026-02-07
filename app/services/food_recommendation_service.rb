class FoodRecommendationService
  NEPALI_ALTERNATIVES = {
    "white_rice" => ["brown rice", "quinoa", "millet (dhido)"],
    "fried_momo" => ["steamed momo", "jhol momo"],
    "fried_chicken" => ["grilled chicken", "tandoori chicken", "chicken sekuwa"],
    "samosa" => ["steamed momo", "vegetable soup", "roasted chickpeas"],
    "soda" => ["lassi", "fresh lime water", "coconut water", "buttermilk"],
    "chips" => ["roasted chickpeas", "makhana", "popcorn"],
    "paratha" => ["roti", "whole wheat chapati"],
    "puri" => ["roti", "steamed rice"],
    "jalebi" => ["fresh fruits", "juju dhau (small portion)"],
    "instant_noodles" => ["thukpa", "dal bhat", "khichdi"]
  }.freeze

  PROTEIN_RICH_NEPALI_FOODS = [
    { name: "Grilled chicken (kukhura)", protein: 31, calories: 165 },
    { name: "Boiled eggs (anda)", protein: 13, calories: 155 },
    { name: "Dal (masoor/mung)", protein: 9, calories: 116 },
    { name: "Paneer", protein: 14, calories: 265 },
    { name: "Chhurpi (dried cheese)", protein: 54, calories: 350 },
    { name: "Buff curry (lean)", protein: 26, calories: 250 },
    { name: "Fish curry (machha)", protein: 22, calories: 180 }
  ].freeze

  FIBER_RICH_NEPALI_FOODS = [
    { name: "Saag (spinach/mustard greens)", fiber: 2.2, calories: 23 },
    { name: "Rajma (kidney beans)", fiber: 7.4, calories: 127 },
    { name: "Gundruk", fiber: 3.5, calories: 45 },
    { name: "Brown rice", fiber: 3.5, calories: 370 },
    { name: "Dhido (millet)", fiber: 8.5, calories: 378 },
    { name: "Guava (amba)", fiber: 5.4, calories: 68 },
    { name: "Kwati (mixed beans)", fiber: 6.0, calories: 150 }
  ].freeze

  LOW_GI_SWAPS = [
    { replace: "White rice (bhat)", with: "Brown rice or dhido", gi_reduction: 25 },
    { replace: "White bread", with: "Whole grain roti", gi_reduction: 30 },
    { replace: "Sugar in tea", with: "Stevia or reduce amount", gi_reduction: 100 },
    { replace: "Potato (alu)", with: "Sweet potato (sakharkhand)", gi_reduction: 15 },
    { replace: "Instant noodles", with: "Buckwheat noodles", gi_reduction: 20 }
  ].freeze

  def initialize(user)
    @user = user
  end

  def suggest_alternatives
    frequent_foods = @user.user_food_stats
                          .where("times_eaten >= ?", 3)
                          .order(times_eaten: :desc)
                          .limit(10)

    suggestions = []

    frequent_foods.each do |stat|
      if stat.health_score && stat.health_score < 60
        alternatives = find_healthier_alternatives(stat.normalized_name)
        next if alternatives.empty?

        suggestions << {
          current_food: stat.normalized_name.to_s.titleize,
          health_score: stat.health_score,
          alternatives: alternatives,
          reason: improvement_reason(stat)
        }
      end
    end

    suggestions
  end

  def goal_aligned_suggestions
    targets = CalorieGoalService.new(@user).macro_targets
    recent_meals = @user.meals.where("eaten_at > ?", 7.days.ago).includes(:food_items)
    current_avg = calculate_current_macros(recent_meals)

    suggestions = []

    # Protein deficit
    if current_avg[:protein_g] < targets[:protein_g] * 0.8
      suggestions << {
        type: "protein_boost",
        message: "You're getting #{current_avg[:protein_g].round}g protein/day, but need #{targets[:protein_g]}g",
        foods: PROTEIN_RICH_NEPALI_FOODS.first(5)
      }
    end

    # Fiber deficit
    if current_avg[:fiber_g] < 25
      suggestions << {
        type: "fiber_boost",
        message: "Add more fiber for better digestion (currently ~#{current_avg[:fiber_g].round}g/day)",
        foods: FIBER_RICH_NEPALI_FOODS.first(5)
      }
    end

    # Diabetic-friendly swaps
    if @user.health_goal == "diabetic_friendly"
      suggestions << {
        type: "low_gi_swaps",
        message: "Lower glycemic alternatives for better blood sugar control",
        swaps: LOW_GI_SWAPS
      }
    end

    # Weight loss specific
    if @user.health_goal == "weight_loss"
      suggestions << {
        type: "calorie_reduction",
        message: "Focus on volume eating - more vegetables, less oil",
        tips: [
          "Start meals with a bowl of saag or vegetable soup",
          "Use smaller rice portions, more dal and tarkari",
          "Choose steamed over fried (momo, fish)",
          "Drink water or buttermilk instead of sweet drinks"
        ]
      }
    end

    # Muscle gain specific
    if @user.health_goal == "muscle_gain"
      suggestions << {
        type: "protein_timing",
        message: "Distribute protein across meals for muscle building",
        tips: [
          "Add eggs or paneer to breakfast",
          "Include dal or meat in every main meal",
          "Post-workout: lassi with protein or boiled eggs",
          "Snack on chhurpi, roasted chickpeas, or nuts"
        ]
      }
    end

    suggestions
  end

  def format_suggestions_message
    alternatives = suggest_alternatives
    goal_suggestions = goal_aligned_suggestions
    lang = @user.language || 'en'

    return t('suggestions_all_good', lang) if alternatives.empty? && goal_suggestions.empty?

    message_parts = ["#{t('suggestions_title', lang)}\n"]

    if alternatives.any?
      message_parts << t('suggestions_healthy_alternatives', lang)
      alternatives.first(3).each do |alt|
        message_parts << "• #{alt[:current_food]} → Try: #{alt[:alternatives].first(2).join(' or ')}"
        message_parts << "  (#{alt[:reason]})" if alt[:reason].present?
      end
      message_parts << ""
    end

    goal_suggestions.each do |suggestion|
      case suggestion[:type]
      when "protein_boost"
        message_parts << t('suggestions_protein_boost', lang)
        message_parts << suggestion[:message]
        suggestion[:foods].first(3).each do |food|
          message_parts << "• #{food[:name]} (#{food[:protein]}g protein)"
        end
      when "fiber_boost"
        message_parts << t('suggestions_fiber_boost', lang)
        message_parts << suggestion[:message]
        suggestion[:foods].first(3).each do |food|
          message_parts << "• #{food[:name]} (#{food[:fiber]}g fiber)"
        end
      when "low_gi_swaps"
        message_parts << t('suggestions_diabetic_swaps', lang)
        suggestion[:swaps].first(3).each do |swap|
          message_parts << "• #{swap[:replace]} → #{swap[:with]}"
        end
      when "calorie_reduction", "protein_timing"
        message_parts << t('suggestions_goal_tips', lang)
        suggestion[:tips].first(3).each { |tip| message_parts << "• #{tip}" }
      end
      message_parts << ""
    end

    message_parts.join("\n")
  end

  private

  def t(key, lang, params = {})
    TranslationService.t(key, lang, params)
  end

  def find_healthier_alternatives(normalized_name)
    NEPALI_ALTERNATIVES[normalized_name] || default_alternatives
  end

  def default_alternatives
    ["more vegetables (tarkari)", "steamed options", "smaller portions"]
  end

  def improvement_reason(stat)
    reasons = []

    if stat.avg_calories && stat.avg_calories > 400
      reasons << "high calories"
    end

    if stat.avg_calories && stat.avg_calories > 0
      protein_ratio = (stat.avg_protein_g || 0) / (stat.avg_calories / 4.0)
      reasons << "low protein" if protein_ratio < 0.15
    end

    if stat.avg_calories && stat.avg_calories > 0
      fat_ratio = (stat.avg_fat_g || 0) / (stat.avg_calories / 9.0)
      reasons << "high fat" if fat_ratio > 0.4
    end

    reasons.join(", ")
  end

  def calculate_current_macros(meals)
    return { protein_g: 0, carbs_g: 0, fat_g: 0, fiber_g: 0 } if meals.empty?

    days = [(Date.current - meals.minimum(:eaten_at).to_date).to_i + 1, 1].max

    {
      protein_g: meals.sum { |m| m.food_items.sum { |fi| fi.protein_g || 0 } } / days.to_f,
      carbs_g: meals.sum { |m| m.food_items.sum { |fi| fi.carbs_g || 0 } } / days.to_f,
      fat_g: meals.sum { |m| m.food_items.sum { |fi| fi.fat_g || 0 } } / days.to_f,
      fiber_g: 15 # Estimate - would need fiber tracking in food_items
    }
  end
end
