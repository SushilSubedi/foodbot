module Telegram
  module Commands
    class RemindersCommand
      MEAL_TYPES = %w[breakfast lunch dinner snack].freeze

      def initialize(user)
        @user = user
        @lang = @user.language || 'en'
      end

      def execute
        {
          text: reminders_message,
          reply_markup: reminders_keyboard,
          parse_mode: "Markdown"
        }
      end

      def handle_callback(callback_data)
        action = callback_data.split(":").last

        case action
        when "enable_all"
          enable_all_reminders
        when "disable_all"
          disable_all_reminders
        when *MEAL_TYPES
          toggle_meal_reminder(action)
        else
          { text: "Unknown action" }
        end
      end

      private

      def reminders_message
        status = @user.meal_reminders_enabled? ? t('reminders_status_enabled') : t('reminders_status_disabled')

        <<~MESSAGE
          *#{t('reminders_title')}*

          #{status}

          #{t('reminders_description')}

          #{current_settings}
        MESSAGE
      end

      def current_settings
        return t('reminders_no_settings') unless @user.meal_reminder_settings.present?

        MEAL_TYPES.map do |meal|
          enabled = @user.meal_reminder_settings[meal] == true
          emoji = enabled ? "✅" : "❌"
          time = @user.meal_timing_preferences&.dig(meal) || default_time(meal)
          "#{emoji} #{meal.capitalize}: #{time}"
        end.join("\n")
      end

      def default_time(meal)
        case meal
        when "breakfast" then "08:00"
        when "lunch" then "13:00"
        when "dinner" then "19:30"
        when "snack" then "16:00"
        end
      end

      def reminders_keyboard
        meal_buttons = MEAL_TYPES.map do |meal|
          enabled = @user.meal_reminder_settings&.dig(meal) == true
          emoji = enabled ? "✅" : "⬜"
          [{ text: "#{emoji} #{meal.capitalize}", callback_data: "reminder:#{meal}" }]
        end

        {
          inline_keyboard: meal_buttons + [
            [
              { text: t('reminders_enable_all'), callback_data: "reminder:enable_all" },
              { text: t('reminders_disable_all'), callback_data: "reminder:disable_all" }
            ]
          ]
        }
      end

      def enable_all_reminders
        settings = MEAL_TYPES.each_with_object({}) { |m, h| h[m] = true }
        @user.update(meal_reminders_enabled: true, meal_reminder_settings: settings)

        {
          text: t('reminders_enabled_confirm'),
          reply_markup: reminders_keyboard
        }
      end

      def disable_all_reminders
        @user.update(meal_reminders_enabled: false, meal_reminder_settings: {})

        {
          text: t('reminders_disabled_confirm'),
          reply_markup: reminders_keyboard
        }
      end

      def toggle_meal_reminder(meal)
        settings = (@user.meal_reminder_settings || {}).dup
        settings[meal] = !settings[meal]
        @user.update(meal_reminder_settings: settings)

        any_enabled = settings.values.any?
        @user.update(meal_reminders_enabled: any_enabled)

        status = settings[meal] ? "enabled" : "disabled"
        {
          text: t('reminders_meal_toggled', meal: meal.capitalize, status: status),
          reply_markup: reminders_keyboard
        }
      end

      def t(key, params = {})
        TranslationService.t(key, @lang, params)
      end
    end
  end
end
