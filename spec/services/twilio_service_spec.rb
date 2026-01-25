require 'rails_helper'

RSpec.describe TwilioService do
  let(:service) { described_class.new }
  let(:mock_client) { instance_double(Twilio::REST::Client) }
  let(:mock_messages) { instance_double(Twilio::REST::Api::V2010::AccountContext::MessageList) }

  before do
    allow(Twilio::REST::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:messages).and_return(mock_messages)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('TWILIO_ACCOUNT_SID').and_return('sid')
    allow(ENV).to receive(:[]).with('TWILIO_AUTH_TOKEN').and_return('token')
    allow(ENV).to receive(:[]).with('TWILIO_WHATSAPP_NUMBER').and_return('whatsapp:+123')
  end

  describe '#send_message' do
    it 'sends a message' do
      expect(mock_messages).to receive(:create).with(
        from: 'whatsapp:+123',
        to: 'whatsapp:+456',
        body: 'Hello'
      )
      service.send_message(to: 'whatsapp:+456', body: 'Hello')
    end
  end
end
