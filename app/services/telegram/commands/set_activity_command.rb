module Telegram
  module Commands
    class SetActivityCommand
      ACTIVITY_LEVELS = %w[sedentary light moderate very_active extremely_active].freeze

      def initialize(user)
        @user = user
        @lang = @user.language || "en"
      end

      def execute
        {
          text: TranslationService.t("setactivity_prompt", @lang),
          reply_markup: activity_keyboard
        }
      end

      def handle_callback(callback_data)
        activity = callback_data.split(":").last
        @user.update(activity_level: activity)

        @user.update_tdee! if @user.biometrics_complete?

        {
          text: response_message(activity),
          parse_mode: "Markdown"
        }
      end

      private

      def activity_keyboard
        buttons = ACTIVITY_LEVELS.map do |level|
          button_text = TranslationService.t("setactivity_#{level}", @lang)
          [ { text: button_text, callback_data: "activity:#{level}" } ]
        end
        { inline_keyboard: buttons }
      end

      def response_message(activity)
        confirm_text = TranslationService.t("setactivity_confirm", @lang, level: activity.titleize)

        <<~MESSAGE
          ✅ #{confirm_text}

          #{tdee_message}

          #{next_step_message}
        MESSAGE
      end

      def tdee_message
        if @user.tdee_calories
          TranslationService.t("setactivity_tdee_message", @lang, tdee: @user.tdee_calories)
        else
          TranslationService.t("setactivity_complete_bio", @lang)
        end
      end

      def next_step_message
        if @user.biometrics_complete?
          TranslationService.t("setactivity_next_step", @lang)
        else
          TranslationService.t("setactivity_complete_bio", @lang)
        end
      end
    end
  end
end
