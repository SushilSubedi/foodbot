require 'faraday'
require 'json'

class TelegramService
  def base_url
    "https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_TOKEN']}"
  end

  def file_base_url
    "https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}"
  end

  def get_file_url(file_id)
    response = Faraday.get("#{base_url}/getFile?file_id=#{file_id}") do |req|
      req.options.open_timeout = 5
      req.options.timeout = 5
    end
    unless response.success?
      Rails.logger.error("Telegram getFile HTTP Error: #{response.status} - #{response.body}")
      return nil
    end

    data = JSON.parse(response.body)
    unless data['ok']
      Rails.logger.error("Telegram getFile API Error: #{data['description']}")
      return nil
    end

    file_path = data['result']['file_path']
    "#{file_base_url}/#{file_path}"
  rescue StandardError => e
    Rails.logger.error("Telegram getFile error: #{e.message}")
    nil
  end

  def send_message(chat_id:, text:, reply_markup: nil)
    payload = {
      chat_id: chat_id,
      text: text
    }
    payload[:reply_markup] = reply_markup if reply_markup

    response = Faraday.post("#{base_url}/sendMessage", payload.to_json, 'Content-Type' => 'application/json')

    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.error("Telegram sendMessage HTTP Error: #{response.status} - #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("Telegram sendMessage error: #{e.message}")
    nil
  end

  def edit_message_text(chat_id:, message_id:, text:, reply_markup: nil)
    payload = {
      chat_id: chat_id,
      message_id: message_id,
      text: text
    }
    payload[:reply_markup] = reply_markup if reply_markup

    response = Faraday.post("#{base_url}/editMessageText", payload.to_json, 'Content-Type' => 'application/json')

    unless response.success?
      Rails.logger.error("Telegram editMessageText HTTP Error: #{response.status} - #{response.body}")
    end
  rescue StandardError => e
    Rails.logger.error("Telegram editMessageText error: #{e.message}")
  end

  def answer_callback_query(callback_query_id:, text: nil)
    payload = { callback_query_id: callback_query_id }
    payload[:text] = text if text

    response = Faraday.post("#{base_url}/answerCallbackQuery", payload.to_json, 'Content-Type' => 'application/json')

    unless response.success?
      Rails.logger.error("Telegram answerCallbackQuery HTTP Error: #{response.status} - #{response.body}")
    end
  rescue StandardError => e
    Rails.logger.error("Telegram answerCallbackQuery error: #{e.message}")
  end
end
