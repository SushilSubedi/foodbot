class WeeklySummaryService
  def initialize(user)
    @user = user
    @end_date = Date.today
    @start_date = @end_date - 6.days
  end

  def call
    daily_stats = (@start_date..@end_date).map do |date|
      total = @user.meals.where('DATE(eaten_at) = ?', date).sum(:estimated_calories)
      {
        date: date,
        calories: total,
        is_today: date == @end_date
      }
    end
    
    format_weekly_summary(daily_stats)
  end

  private

  def format_weekly_summary(stats)
    lang = @user.language || 'en'
    goal = @user.daily_calorie_goal || 2000
    
    daily_lines = stats.map do |day|
      status = calorie_status(day[:calories], goal)
      today_tag = day[:is_today] ? " (#{TranslationService.t('today_header', lang).split(' ').first})" : "" # Getting just "Today" or "आज" part roughly
      # Better approach: add 'today_tag' to translation service. For now, repurpose 'today_header' or hardcode date.
      # Actually, let's keep it simple: date is good enough usually, but "today" helps.
      # Let's use English date format for now as strftime is English.
      
      formatted_cals = format_number(day[:calories])
      
      "#{day[:date].strftime('%a %d')}: #{formatted_cals} kcal #{status}"
    end.join("\n")
    
    total_cals = stats.sum { |d| d[:calories] }
    avg = (total_cals / 7.0).round
    
    # Date range
    date_range = "#{@start_date.strftime('%b %d')}-#{@end_date.strftime('%d')}"
    header = "#{TranslationService.t('weekly_header', lang)} (#{date_range})"
    
    <<~TEXT
      #{header}

      #{daily_lines}

      #{TranslationService.t('weekly_avg', lang)}: #{format_number(avg)} #{TranslationService.t('kcal_per_day', lang)}
      #{TranslationService.t('weekly_target', lang)}: #{format_number(goal)} #{TranslationService.t('kcal_per_day', lang)}
    TEXT
  end

  def calorie_status(calories, goal)
    return '⚪' if calories.zero?
    
    diff = (calories.to_f / goal * 100).to_i
    
    case diff
    when 90..110 then '⭐'  # Perfect
    when 80..120 then '✅'  # Good
    when 50..79, 121..150 then '⚠️'   # Warning
    else '🔴'  # Too low or too high
    end
  end

  def format_number(num)
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
