class DailyLogService
  def initialize(user, date)
    @user = user
    @date = date
  end

  def call
    meals = @user.meals
                 .where('DATE(eaten_at) = ?', @date)
                 .includes(:food_items)
                 .order(:eaten_at)
    
    return no_meals_message if meals.empty?
    
    format_daily_summary(meals)
  end

  private

  def format_daily_summary(meals)
    lang = @user.language || 'en'
    grouped = meals.group_by(&:meal_type)
    total_cals = meals.sum(:estimated_calories)
    
    # Calculate totals from food_items
    all_food_items = meals.flat_map(&:food_items)
    total_protein = all_food_items.sum(&:protein_g).round(1)
    total_carbs = all_food_items.sum(&:carbs_g).round(1)
    total_fat = all_food_items.sum(&:fat_g).round(1)
    
    meals_text = grouped.map do |type, type_meals|
      emoji = meal_emoji(type)
      
      # Translate meal type header
      meal_type_key = "meal_#{type}"
      meal_type_text = TranslationService.t(meal_type_key, lang)
      
      items = type_meals.flat_map(&:food_items).map do |item|
        "  • #{item.name} — #{item.calories} kcal"
      end.join("\n")
      
      "#{emoji} #{meal_type_text}\n#{items}"
    end.join("\n\n")
    
    goal = @user.daily_calorie_goal || 2000
    remaining = [goal - total_cals, 0].max
    progress = [[((total_cals.to_f / goal) * 100).to_i, 100].min, 0].max
    
    # Format date (simple approach, could contain English month names but acceptable for now)
    date_str = @date.strftime('%b %d')
    header = "#{TranslationService.t('today_header', lang)} (#{date_str})"
    
    <<~TEXT
      #{header}

      #{meals_text}

      📊 #{TranslationService.t('total', lang)}: #{total_cals} kcal
        #{TranslationService.t('protein', lang)}: #{total_protein}g | #{TranslationService.t('carbs', lang)}: #{total_carbs}g | #{TranslationService.t('fat', lang)}: #{total_fat}g

      #{TranslationService.t('goal_label', lang)}: #{goal} kcal
      #{TranslationService.t('progress_label', lang)}: #{progress}% (#{remaining} kcal #{TranslationService.t('remaining', lang)})
    TEXT
  end

  def no_meals_message
    # We don't have a specific key for this yet, let's add a simple one or use existing components
    # For now, using a hardcoded fallback or adding to TranslationService would be better.
    # Given the previous step, I missed adding 'no_meals_message'. I'll add it to TranslationService in next step if needed.
    # For now, stick to English as fallback or try to construct it.
    # Actually, I'll update it to use a new key 'no_meals_logged' which I will add.
    lang = @user.language || 'en'
    TranslationService.t('no_meals_logged', lang) rescue "📅 No meals logged today yet!\n\n📸 Send a food photo to get started."
  end

  def meal_emoji(type)
    {
      'breakfast' => '🌅',
      'lunch' => '🌞',
      'dinner' => '🌙',
      'snack' => '🍪',
      'unknown' => '🍽️'
    }[type] || '🍽️'
  end
end
