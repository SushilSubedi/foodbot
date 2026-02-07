module Telegram
  module Commands
    class SetGoalCommand
      def initialize(user)
        @user = user
        @lang = @user.language || "en"
      end

      def execute
        {
          text: t("setgoal_prompt"),
          reply_markup: goal_keyboard
        }
      end

      def handle_callback(callback_data)
        goal = callback_data.split(":").last
        @user.update(health_goal: goal)

        if @user.calorie_goal_mode_auto?
          @user.update_tdee!
        end

        {
          text: response_message(goal),
          parse_mode: "Markdown"
        }
      end

      private

      def t(key, params = {})
        TranslationService.t(key, @lang, params)
      end

      def goal_keyboard
        {
          inline_keyboard: [
            [
              { text: t("setgoal_maintain"), callback_data: "goal:maintain" },
              { text: t("setgoal_weight_loss"), callback_data: "goal:weight_loss" }
            ],
            [
              { text: t("setgoal_muscle_gain"), callback_data: "goal:muscle_gain" },
              { text: t("setgoal_diabetic"), callback_data: "goal:diabetic_friendly" }
            ]
          ]
        }
      end

      def response_message(goal)
        targets = @user.macro_targets

        <<~MESSAGE
          #{t("setgoal_confirm", goal: goal.titleize)}

          #{goal_specific_message(goal)}

          #{t("setgoal_recommended_calories", calories: @user.recommended_daily_calories)}

          #{t("setgoal_macro_targets", protein: targets[:protein_g], carbs: targets[:carbs_g], fat: targets[:fat_g])}

          #{t("setgoal_next_step")}
        MESSAGE
      end

      def goal_specific_message(goal)
        case goal
        when "weight_loss"
          t("setgoal_desc_weight_loss")
        when "muscle_gain"
          t("setgoal_desc_muscle_gain")
        when "diabetic_friendly"
          t("setgoal_desc_diabetic")
        else
          t("setgoal_desc_maintain")
        end
      end
    end
  end
end
