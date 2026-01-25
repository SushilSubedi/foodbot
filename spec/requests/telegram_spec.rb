require 'rails_helper'

RSpec.describe "Telegram", type: :request do
  describe "POST /telegram/webhook" do
    let(:valid_photo_payload) do
      {
        message: {
          chat: { id: 123 },
          caption: "Momo plat",
          photo: [
            { file_id: 'small_id' },
            { file_id: 'large_id' }
          ]
        }
      }
    end

    let(:text_payload) do
      {
        message: {
          chat: { id: 123 },
          text: "hello"
        }
      }
    end

    let(:telegram_service_instance) { instance_double(TelegramService) }
    let(:analysis_service_instance) { instance_double(ImageAnalysisService) }

    before do
      allow(TelegramService).to receive(:new).and_return(telegram_service_instance)
      allow(telegram_service_instance).to receive(:send_message)
      allow(telegram_service_instance).to receive(:get_file_url).and_return('http://img.com/a.jpg')
      allow(ImageAnalysisService).to receive(:new).and_return(analysis_service_instance)
    end

    context 'when text is sent' do
      it 'replies asking for a photo' do
        post '/telegram/webhook', params: text_payload
        
        expect(telegram_service_instance).to have_received(:send_message).with(
          chat_id: '123',
          text: include("Kripaya khana ko photo")
        )
      end
    end

    context 'when photo is sent' do
      it 'analyzes and replies' do
        mock_data = {
          'items' => [{'name' => 'Pizza', 'calories' => 300}],
          'total_calories' => 300,
          'macros' => {'protein' => '15%', 'carbs' => '50%', 'fat' => '35%'}
        }
        allow(analysis_service_instance).to receive(:call).and_return(mock_data)

        post '/telegram/webhook', params: valid_photo_payload

        # Should fetch the last file_id
        expect(telegram_service_instance).to have_received(:get_file_url).with('large_id')
        
        # Should reply with analysis
        expect(telegram_service_instance).to have_received(:send_message).with(
          chat_id: '123',
          text: include("Pizza: 300 kcal")
        )
      end
    end
  end
end
