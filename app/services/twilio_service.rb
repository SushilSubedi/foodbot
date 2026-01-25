class TwilioService
  def initialize
    @client = Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'])
  end

  def send_message(to:, body:)
    @client.messages.create(
      from: ENV['TWILIO_WHATSAPP_NUMBER'],
      to: to,
      body: body
    )
  rescue Twilio::REST::TwilioError => e
    Rails.logger.error("Twilio Error: #{e.message}")
  end
end
