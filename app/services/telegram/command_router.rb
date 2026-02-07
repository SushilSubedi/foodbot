module Telegram
  class CommandRouter
    COMMANDS = {
      "/setgoal" => Commands::SetGoalCommand,
      "/setactivity" => Commands::SetActivityCommand,
      "/setbio" => Commands::SetBioCommand,
      "/setfasting" => Commands::SetFastingCommand,
      "/trends" => Commands::TrendsCommand,
      "/suggest" => Commands::SuggestCommand,
      "/profile" => Commands::ProfileCommand,
      "/reminders" => Commands::RemindersCommand
    }.freeze

    CALLBACK_PREFIXES = {
      "goal" => Commands::SetGoalCommand,
      "activity" => Commands::SetActivityCommand,
      "bio_gender" => Commands::SetBioCommand,
      "fasting" => Commands::SetFastingCommand,
      "trends" => Commands::TrendsCommand,
      "reminder" => Commands::RemindersCommand,
      "cmd" => :route_to_command
    }.freeze

    def initialize(user)
      @user = user
    end

    def route_command(text)
      command = text.split.first.downcase
      command_class = COMMANDS[command]

      return nil unless command_class

      command_class.new(@user).execute
    end

    def route_callback(callback_data)
      prefix = callback_data.split(":").first

      if prefix == "cmd"
        # Route to another command
        cmd_name = "/#{callback_data.split(':').last}"
        route_command(cmd_name)
      else
        command_class = CALLBACK_PREFIXES[prefix]
        return nil unless command_class && command_class != :route_to_command

        command_class.new(@user).handle_callback(callback_data)
      end
    end

    def route_text_response(text)
      context = @user.pending_context_data
      return nil unless context

      state = context[:state].to_s

      case state
      when /^bio_/
        Commands::SetBioCommand.new(@user).handle_response(text)
      when /^fasting_/
        Commands::SetFastingCommand.new(@user).handle_time_input(text)
      else
        nil
      end
    end

    def command?(text)
      text.start_with?("/") && COMMANDS.key?(text.split.first.downcase)
    end

    def has_pending_conversation?
      @user.pending_context_data.present?
    end
  end
end
