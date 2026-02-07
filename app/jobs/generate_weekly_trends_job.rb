class GenerateWeeklyTrendsJob < ApplicationJob
  queue_as :default

  def perform
    User.find_each do |user|
      next if user.meals.where("eaten_at > ?", 7.days.ago).empty?

      TrendAnalysisService.new(user, period_type: "week").generate_report
    rescue StandardError => e
      Rails.logger.error("Failed to generate weekly trends for user #{user.id}: #{e.message}")
    end
  end
end
