module Telegram
  module Commands
    class ProfileCommand
      def initialize(user)
        @user = user
        @lang = @user.language || "en"
      end

      def execute
        {
          text: profile_message,
          reply_markup: action_keyboard,
          parse_mode: "Markdown"
        }
      end

      private

      def t(key, params = {})
        TranslationService.t(key, @lang, params)
      end

      def profile_message
        <<~MESSAGE
          👤 *#{t(:profile_title)}*

          #{completion_bar}

          *#{t(:profile_health_goal, goal: goal_display)}*
          *#{t(:profile_activity_level, level: activity_display)}*
          *#{t(:profile_daily_target, calories: @user.recommended_daily_calories)}*

          #{biometrics_section}

          #{fasting_section}

          #{dietary_section}

          #{tips_section}
        MESSAGE
      end

      def completion_bar
        pct = @user.profile_completion_percentage
        filled = (pct / 10.0).round
        empty = 10 - filled
        bar = "▓" * filled + "░" * empty
        t(:profile_completion, percent: "#{bar} #{pct}%")
      end

      def goal_display
        emoji = case @user.health_goal
        when "weight_loss" then "📉"
        when "muscle_gain" then "💪"
        when "diabetic_friendly" then "🩺"
        else "🎯"
        end
        "#{emoji} #{@user.health_goal.titleize}"
      end

      def activity_display
        emoji = case @user.activity_level
        when "sedentary" then "🪑"
        when "light" then "🚶"
        when "moderate" then "🏃"
        when "very_active" then "🏋️"
        when "extremely_active" then "🏆"
        else "❓"
        end
        "#{emoji} #{@user.activity_level.titleize}"
      end

      def biometrics_section
        if @user.biometrics_complete?
          t(:profile_biometrics, age: @user.age, weight: @user.weight_kg, height: @user.height_cm)
        else
          t(:profile_biometrics_incomplete)
        end
      end

      def fasting_section
        if @user.intermittent_fasting_enabled?
          t(:profile_fasting_enabled, schedule: @user.fasting_schedule, start: @user.fasting_start_time, end: @user.fasting_end_time)
        else
          t(:profile_fasting_disabled)
        end
      end

      def dietary_section
        parts = []
        parts << "Vegetarian" if @user.is_vegetarian?
        parts << "Vegan" if @user.is_vegan?
        parts << "Allergies: #{@user.allergies.join(', ')}" if @user.allergies.any?
        parts << "Dislikes: #{@user.dislikes.join(', ')}" if @user.dislikes.any?

        if parts.any?
          t(:profile_dietary, preferences: parts.join(" | "))
        else
          t(:profile_dietary_none)
        end
      end

      def tips_section
        tips = @user.profile_completion_tips
        return "" if tips.empty?

        "\n💡 *#{t(:profile_complete_tips)}*\n" + tips.map { |tip| "• #{tip}" }.join("\n")
      end

      def action_keyboard
        {
          inline_keyboard: [
            [
              { text: "🎯 #{t(:profile_btn_goal)}", callback_data: "cmd:setgoal" },
              { text: "🏃 #{t(:profile_btn_activity)}", callback_data: "cmd:setactivity" }
            ],
            [
              { text: "📊 #{t(:profile_btn_bio)}", callback_data: "cmd:setbio" },
              { text: "⏰ #{t(:profile_btn_fasting)}", callback_data: "cmd:setfasting" }
            ],
            [
              { text: "📈 #{t(:profile_btn_trends)}", callback_data: "trends:week" },
              { text: "💡 #{t(:profile_btn_suggest)}", callback_data: "cmd:suggest" }
            ]
          ]
        }
      end
    end
  end
end
