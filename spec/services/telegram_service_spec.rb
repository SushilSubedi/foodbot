require 'rails_helper'

RSpec.describe TelegramService do
  let(:service) { described_class.new }
  let(:token) { 'fake_token' }
  let(:base_url) { "https://api.telegram.org/bot#{token}" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('TELEGRAM_BOT_TOKEN').and_return(token)
  end

  describe '#get_file_url' do
    it 'returns url on success' do
      stub_request(:get, "#{base_url}/getFile?file_id=123")
        .to_return(body: { ok: true, result: { file_path: 'photos/file_0.jpg' } }.to_json)

      expect(service.get_file_url('123')).to eq("https://api.telegram.org/file/bot#{token}/photos/file_0.jpg")
    end

    it 'returns nil on failure' do
      stub_request(:get, "#{base_url}/getFile?file_id=123")
        .to_return(status: 400)
      
      expect(service.get_file_url('123')).to be_nil
    end
  end

  describe '#send_message' do
    it 'posts message' do
      stub_request(:post, "#{base_url}/sendMessage")
        .with(body: hash_including(chat_id: '456', text: 'Hi'))
        .to_return(status: 200)

      service.send_message(chat_id: '456', text: 'Hi')
      # Expectation is implicit via WebMock verification or lack of error
    end
  end
end
