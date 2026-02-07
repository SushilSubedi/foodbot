class MealReminderJob < ApplicationJob
  queue_as :default

  def perform
    User.where(meal_reminders_enabled: true).find_each do |user|
      MealReminderService.new(user).check_and_send_all_reminders
    rescue StandardError => e
      Rails.logger.error("Failed to send reminders to user #{user.id}: #{e.message}")
    end
  end
end
