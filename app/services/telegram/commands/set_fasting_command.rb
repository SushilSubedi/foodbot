module Telegram
  module Commands
    class SetFastingCommand
      def initialize(user)
        @user = user
      end

      def execute
        {
          text: fasting_intro,
          reply_markup: schedule_keyboard,
          parse_mode: "Markdown"
        }
      end

      def handle_callback(callback_data)
        action = callback_data.split(":").last

        case action
        when "disable"
          disable_fasting
        when "custom"
          start_custom_setup
        else
          enable_preset(action)
        end
      end

      def handle_time_input(text)
        context = @user.pending_context_data
        return nil unless context&.dig(:state)&.start_with?("fasting_")

        time = parse_time(text)
        unless time
          return { text: t(:fasting_invalid_time) }
        end

        case context[:state]
        when "fasting_start"
          @user.update(eating_window_start_local: time)
          @user.set_pending_context({ state: "fasting_end" })
          { text: t(:fasting_ask_end), parse_mode: "Markdown" }
        when "fasting_end"
          @user.update(eating_window_end_local: time)
          finish_setup
        end
      end

      private

      def t(key, params = {})
        TranslationService.t(key, @user.language || "en", params)
      end

      def fasting_intro
        status = if @user.intermittent_fasting_enabled?
                   t(:fasting_current, schedule: current_schedule)
        else
                   t(:fasting_disabled)
        end

        <<~MESSAGE
          #{t(:fasting_title)}

          #{status}

          #{t(:fasting_choose)}
        MESSAGE
      end

      def current_schedule
        if @user.eating_window_start_local && @user.eating_window_end_local
          "#{@user.eating_window_start_local.strftime('%H:%M')} - #{@user.eating_window_end_local.strftime('%H:%M')}"
        else
          @user.fasting_schedule || "16:8"
        end
      end

      def schedule_keyboard
        {
          inline_keyboard: [
            [ { text: t(:fasting_16_8), callback_data: "fasting:16_8" } ],
            [ { text: t(:fasting_14_10), callback_data: "fasting:14_10" } ],
            [ { text: t(:fasting_18_6), callback_data: "fasting:18_6" } ],
            [ { text: t(:fasting_20_4), callback_data: "fasting:20_4" } ],
            [ { text: t(:fasting_custom), callback_data: "fasting:custom" } ],
            [ { text: t(:fasting_disable_btn), callback_data: "fasting:disable" } ]
          ]
        }
      end

      def enable_preset(schedule)
        preset = User::FASTING_SCHEDULES[schedule]
        return { text: "Invalid schedule" } unless preset

        start_time = Time.zone.parse(preset[:start])
        end_time = Time.zone.parse(preset[:end])

        @user.update(
          intermittent_fasting_enabled: true,
          fasting_schedule: schedule,
          eating_window_start_local: start_time,
          eating_window_end_local: end_time
        )
        @user.clear_pending_context

        {
          text: success_message(preset[:name], preset[:start], preset[:end]),
          parse_mode: "Markdown"
        }
      end

      def start_custom_setup
        @user.update(intermittent_fasting_enabled: true, fasting_schedule: "custom")
        @user.set_pending_context({ state: "fasting_start" })

        {
          text: t(:fasting_ask_start),
          parse_mode: "Markdown"
        }
      end

      def disable_fasting
        @user.update(
          intermittent_fasting_enabled: false,
          eating_window_start_local: nil,
          eating_window_end_local: nil,
          fasting_schedule: nil
        )
        @user.clear_pending_context

        {
          text: t(:fasting_disabled_confirm),
          parse_mode: "Markdown"
        }
      end

      def finish_setup
        @user.clear_pending_context

        start_str = @user.eating_window_start_local.strftime("%H:%M")
        end_str = @user.eating_window_end_local.strftime("%H:%M")

        {
          text: success_message("Custom", start_str, end_str),
          parse_mode: "Markdown"
        }
      end

      def success_message(name, start_time, end_time)
        <<~MESSAGE
          #{t(:fasting_enabled_confirm, schedule: name)}

          #{t(:fasting_schedule_label, schedule: name)}
          #{t(:fasting_eating_window, start: start_time, end: end_time)}

          #{@user.fasting_status_message}

          #{t(:fasting_tips_title)}
          #{t(:fasting_tip1)}
          #{t(:fasting_tip2)}
          #{t(:fasting_tip3)}

          #{t(:fasting_adjust)}
        MESSAGE
      end

      def parse_time(text)
        cleaned = text.strip.gsub(/[^\d:]/, "")
        Time.zone.parse(cleaned)
      rescue ArgumentError
        nil
      end
    end
  end
end
