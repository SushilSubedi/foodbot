class PreferenceLearningJob < ApplicationJob
  queue_as :default

  def perform(user_id:, message_text:, chat_id:, source_message_id: nil, language: nil)
    user = User.find_by(id: user_id)
    return unless user

    return if source_message_id && UserMemory.exists?(user: user, source_message_id: source_message_id)

    extraction = PreferenceExtractionService.new(user: user, message: message_text).call
    signals = extraction["signals"] || []

    applied_changes = []
    if signals.any?
      applied_changes = PreferenceApplierService.new(user: user, signals: signals).call
    end

    UserMemory.create!(
      user: user,
      source: "telegram",
      source_message_id: source_message_id,
      text: message_text,
      language: language || user.language,
      extraction: extraction,
      applied_changes: applied_changes,
      confidence: signals.map { |s| s["confidence"] || 0 }.max
    )

    if applied_changes.any?
      send_confirmation(chat_id, user, applied_changes)
    end
  rescue StandardError => e
    Rails.logger.error("[PreferenceLearningJob] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
  end

  private

  def send_confirmation(chat_id, user, changes)
    lang = user.language || "en"
    messages = changes.map { |change| format_change(change, lang) }.compact

    return if messages.empty?

    text = if lang == "ne"
      "🧠 #{messages.join("\n")}"
    else
      "🧠 #{messages.join("\n")}"
    end

    TelegramService.new.send_message(
      chat_id: chat_id,
      text: text,
      parse_mode: "Markdown"
    )
  end

  def format_change(change, lang)
    field = change[:field]
    new_value = change[:new_value]
    value = change[:value]
    op = change[:op]

    if lang == "ne"
      format_change_nepali(field, new_value, value, op)
    else
      format_change_english(field, new_value, value, op)
    end
  end

  def format_change_english(field, new_value, value, op)
    case field
    when "dietary_preferences.vegetarian"
      new_value ? "Noted — I'll keep recommendations vegetarian." : "Got it — vegetarian mode removed."
    when "dietary_preferences.vegan"
      new_value ? "Noted — I'll keep recommendations vegan." : "Got it — vegan mode removed."
    when "dietary_preferences.allergies"
      op == "add" ? "Noted — I'll avoid *#{value}* (allergy)." : "Got it — removed *#{value}* from allergies."
    when "dietary_preferences.dislikes"
      op == "add" ? "Noted — I'll avoid *#{value}* in suggestions." : "Got it — removed *#{value}* from dislikes."
    when "health_goal"
      goal_labels = {
        "weight_loss" => "weight loss",
        "muscle_gain" => "muscle gain",
        "diabetic_friendly" => "diabetic-friendly",
        "maintain" => "maintenance"
      }
      "Got it — your goal is now *#{goal_labels[new_value] || new_value}*."
    when "portion_modifier"
      pct = (new_value.to_f * 100).round
      "Noted — portions adjusted to *#{pct}%* of standard."
    when "activity_level"
      "Got it — activity level set to *#{new_value.to_s.humanize}*."
    when "language"
      new_value == "ne" ? "भाषा नेपालीमा सेट गरियो।" : "Language set to English."
    when "age"
      "Got it — age set to *#{new_value}*."
    when "weight_kg"
      "Got it — weight set to *#{new_value} kg*."
    when "height_cm"
      "Got it — height set to *#{new_value} cm*."
    when "gender"
      "Got it — gender set to *#{new_value}*."
    when "daily_calorie_goal"
      "Got it — daily calorie target set to *#{new_value} kcal*."
    when "intermittent_fasting"
      new_value.to_s.include?("disabled") ? "Got it — intermittent fasting disabled." : "Got it — intermittent fasting *#{new_value}*."
    end
  end

  def format_change_nepali(field, new_value, value, op)
    case field
    when "dietary_preferences.vegetarian"
      new_value ? "बुझें — शाकाहारी सिफारिसहरू दिनेछु।" : "बुझें — शाकाहारी मोड हटाइयो।"
    when "dietary_preferences.vegan"
      new_value ? "बुझें — भेगन सिफारिसहरू दिनेछु।" : "बुझें — भेगन मोड हटाइयो।"
    when "dietary_preferences.allergies"
      op == "add" ? "बुझें — *#{value}* बाट टाढा राख्नेछु (एलर्जी)।" : "बुझें — *#{value}* एलर्जीबाट हटाइयो।"
    when "dietary_preferences.dislikes"
      op == "add" ? "बुझें — *#{value}* सिफारिसमा नराख्नेछु।" : "बुझें — *#{value}* नापसन्दबाट हटाइयो।"
    when "health_goal"
      goal_labels = {
        "weight_loss" => "तौल घटाउने",
        "muscle_gain" => "मांसपेशी बढाउने",
        "diabetic_friendly" => "मधुमेह-मैत्री",
        "maintain" => "कायम राख्ने"
      }
      "बुझें — तपाईंको लक्ष्य अब *#{goal_labels[new_value] || new_value}* हो।"
    when "portion_modifier"
      pct = (new_value.to_f * 100).round
      "बुझें — भाग आकार *#{pct}%* मा समायोजन गरियो।"
    when "activity_level"
      "बुझें — गतिविधि स्तर *#{new_value}* मा सेट गरियो।"
    when "language"
      new_value == "ne" ? "भाषा नेपालीमा सेट गरियो।" : "Language set to English."
    when "age"
      "बुझें — उमेर *#{new_value}* सेट गरियो।"
    when "weight_kg"
      "बुझें — तौल *#{new_value} kg* सेट गरियो।"
    when "height_cm"
      "बुझें — उचाइ *#{new_value} cm* सेट गरियो।"
    when "gender"
      labels = { "male" => "पुरुष", "female" => "महिला", "other" => "अन्य" }
      "बुझें — लिङ्ग *#{labels[new_value] || new_value}* सेट गरियो।"
    when "daily_calorie_goal"
      "बुझें — दैनिक क्यालोरी लक्ष्य *#{new_value} kcal* सेट गरियो।"
    when "intermittent_fasting"
      new_value.to_s.include?("disabled") ? "बुझें — बर्ती उपवास बन्द गरियो।" : "बुझें — बर्ती उपवास *#{new_value}* सेट गरियो।"
    end
  end
end
