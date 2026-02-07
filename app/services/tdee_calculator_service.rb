# Calculates Total Daily Energy Expenditure using Mifflin-St Jeor equation
class TdeeCalculatorService
  ACTIVITY_MULTIPLIERS = {
    sedentary: 1.2,
    light: 1.375,
    moderate: 1.55,
    very_active: 1.725,
    extremely_active: 1.9
  }.freeze

  def initialize(user)
    @user = user
  end

  def calculate
    return nil unless valid_biometrics?

    bmr = calculate_bmr
    tdee = (bmr * activity_multiplier).round

    @user.update(tdee_calories: tdee)
    tdee
  end

  private

  def valid_biometrics?
    @user.age.present? &&
    @user.gender.present? &&
    @user.weight_kg.present? &&
    @user.height_cm.present?
  end

  def calculate_bmr
    # Mifflin-St Jeor Equation (more accurate than Harris-Benedict)
    # Men: (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) + 5
    # Women: (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) - 161

    base = (10 * @user.weight_kg) + (6.25 * @user.height_cm) - (5 * @user.age)

    case @user.gender.to_s.downcase
    when "male"
      base + 5
    when "female"
      base - 161
    else
      base - 78 # Average of male/female
    end
  end

  def activity_multiplier
    ACTIVITY_MULTIPLIERS[@user.activity_level.to_sym] || 1.2
  end
end
