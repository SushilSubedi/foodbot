class CalorieGoalService
  GOAL_ADJUSTMENTS = {
    weight_loss: -500,      # 500 calorie deficit (1 lb/week loss)
    muscle_gain: 300,       # 300 calorie surplus
    maintain: 0,            # Maintenance
    diabetic_friendly: -200 # Slight deficit + carb management
  }.freeze

  def initialize(user)
    @user = user
  end

  def recommended_calories
    case @user.calorie_goal_mode
    when "manual"
      @user.daily_calorie_goal
    when "auto"
      calculate_from_tdee
    else
      1800 # Safe default
    end
  end

  def macro_targets
    calories = recommended_calories

    case @user.health_goal
    when "weight_loss"
      { protein_g: (calories * 0.30 / 4).round, # 30% protein
        carbs_g: (calories * 0.40 / 4).round,   # 40% carbs
        fat_g: (calories * 0.30 / 9).round }    # 30% fat
    when "muscle_gain"
      { protein_g: (calories * 0.35 / 4).round, # 35% protein
        carbs_g: (calories * 0.45 / 4).round,   # 45% carbs
        fat_g: (calories * 0.20 / 9).round }    # 20% fat
    when "diabetic_friendly"
      { protein_g: (calories * 0.25 / 4).round, # 25% protein
        carbs_g: (calories * 0.35 / 4).round,   # 35% carbs (lower)
        fat_g: (calories * 0.40 / 9).round }    # 40% fat (higher healthy fats)
    else # maintain
      { protein_g: (calories * 0.25 / 4).round, # 25% protein
        carbs_g: (calories * 0.45 / 4).round,   # 45% carbs
        fat_g: (calories * 0.30 / 9).round }    # 30% fat
    end
  end

  private

  def calculate_from_tdee
    tdee = @user.tdee_calories || TdeeCalculatorService.new(@user).calculate
    return 1800 unless tdee

    adjustment = GOAL_ADJUSTMENTS[@user.health_goal.to_sym] || 0
    [tdee + adjustment, 1200].max # Never go below 1200 calories
  end
end
