module Telegram
  module Commands
    class TrendsCommand
      def initialize(user)
        @user = user
        @lang = user.language || "en"
      end

      def execute
        {
          text: t("trends_prompt"),
          reply_markup: period_keyboard
        }
      end

      def handle_callback(callback_data)
        period = callback_data.split(":").last

        analyzer = TrendAnalysisService.new(@user, period_type: period)
        summary = analyzer.summary_message

        {
          text: summary,
          parse_mode: "Markdown"
        }
      rescue StandardError => e
        Rails.logger.error("Trend analysis failed: #{e.message}")
        { text: t("trends_error") }
      end

      private

      def period_keyboard
        {
          inline_keyboard: [
            [
              { text: t("trends_7days"), callback_data: "trends:week" },
              { text: t("trends_30days"), callback_data: "trends:month" }
            ]
          ]
        }
      end

      def t(key, params = {})
        TranslationService.t(key, @lang, params)
      end
    end
  end
end
