module Telegram
  module Commands
    class SuggestCommand
      def initialize(user)
        @user = user
      end

      def execute
        recommender = FoodRecommendationService.new(@user)
        message = recommender.format_suggestions_message

        {
          text: message,
          parse_mode: "Markdown"
        }
      end
    end
  end
end
