module Telegram
  module Commands
    class SetBioCommand
      STATES = %w[bio_age bio_gender bio_weight bio_height].freeze

      def initialize(user)
        @user = user
        @lang = @user.language || "en"
      end

      def execute
        @user.set_pending_context({ state: "bio_age" })

        {
          text: intro_message,
          parse_mode: "Markdown"
        }
      end

      def handle_response(text)
        context = @user.pending_context_data
        return nil unless context

        case context[:state]
        when "bio_age"
          process_age(text)
        when "bio_weight"
          process_weight(text)
        when "bio_height"
          process_height(text)
        else
          nil
        end
      end

      def handle_callback(callback_data)
        action, value = callback_data.split(":")

        case action
        when "bio_gender"
          process_gender(value)
        else
          nil
        end
      end

      private

      def t(key, params = {})
        TranslationService.t(key, @lang, params)
      end

      def intro_message
        profile = t("setbio_current_profile",
          age: @user.age || "Not set",
          gender: @user.gender&.capitalize || "Not set",
          weight: @user.weight_kg ? "#{@user.weight_kg}kg" : "Not set",
          height: @user.height_cm ? "#{@user.height_cm}cm" : "Not set"
        )

        <<~MESSAGE
          #{t("setbio_intro")}

          *#{profile}*

          #{t("setbio_skip_hint")}

          *#{t("setbio_ask_age")}*
        MESSAGE
      end

      def current_profile_summary
        t("setbio_current_profile",
          age: @user.age || "Not set",
          gender: @user.gender&.capitalize || "Not set",
          weight: @user.weight_kg ? "#{@user.weight_kg}kg" : "Not set",
          height: @user.height_cm ? "#{@user.height_cm}cm" : "Not set"
        )
      end

      def process_age(text)
        if text.downcase == "skip"
          transition_to_gender
        else
          age = text.to_i
          if age > 0 && age < 120
            @user.update(age: age)
            transition_to_gender
          else
            { text: t("setbio_invalid_age") }
          end
        end
      end

      def transition_to_gender
        @user.set_pending_context({ state: "bio_gender" })
        {
          text: t("setbio_ask_gender"),
          reply_markup: gender_keyboard
        }
      end

      def gender_keyboard
        {
          inline_keyboard: [
            [
              { text: t("setbio_male"), callback_data: "bio_gender:male" },
              { text: t("setbio_female"), callback_data: "bio_gender:female" }
            ],
            [
              { text: t("setbio_other"), callback_data: "bio_gender:other" },
              { text: t("setbio_skip"), callback_data: "bio_gender:skip" }
            ]
          ]
        }
      end

      def process_gender(value)
        @user.update(gender: value) unless value == "skip"
        transition_to_weight
      end

      def transition_to_weight
        @user.set_pending_context({ state: "bio_weight" })
        { text: t("setbio_ask_weight"), parse_mode: "Markdown" }
      end

      def process_weight(text)
        if text.downcase == "skip"
          transition_to_height
        else
          weight = text.gsub(/[^\d.]/, "").to_f
          if weight > 20 && weight < 500
            @user.update(weight_kg: weight)
            transition_to_height
          else
            { text: t("setbio_invalid_weight") }
          end
        end
      end

      def transition_to_height
        @user.set_pending_context({ state: "bio_height" })
        { text: t("setbio_ask_height"), parse_mode: "Markdown" }
      end

      def process_height(text)
        if text.downcase == "skip"
          finish_setup
        else
          height = text.gsub(/[^\d.]/, "").to_f
          if height > 50 && height < 300
            @user.update(height_cm: height)
            finish_setup
          else
            { text: t("setbio_invalid_height") }
          end
        end
      end

      def finish_setup
        @user.clear_pending_context
        @user.update(profile_completed_at: Time.current)

        tdee = @user.update_tdee!

        {
          text: completion_message(tdee),
          parse_mode: "Markdown"
        }
      end

      def completion_message(tdee)
        <<~MESSAGE
          #{t("setbio_complete")}

          #{current_profile_summary}

          #{tdee_section(tdee)}
        MESSAGE
      end

      def tdee_section(tdee)
        if tdee
          targets = @user.macro_targets
          <<~SECTION
            #{t("setbio_numbers_title")}
            #{t("setbio_bmr", bmr: @user.calculate_bmr.round)}
            #{t("setbio_tdee", tdee: tdee)}
            #{t("setbio_target", target: @user.recommended_daily_calories)}

            #{t("setbio_macro_title")}
            • Protein: #{targets[:protein_g]}g
            • Carbs: #{targets[:carbs_g]}g
            • Fat: #{targets[:fat_g]}g
          SECTION
        else
          t("setbio_complete_all")
        end
      end
    end
  end
end
