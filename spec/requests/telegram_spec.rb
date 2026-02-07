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
      allow(telegram_service_instance).to receive(:edit_message_text)
      allow(telegram_service_instance).to receive(:get_file_url).and_return('http://img.com/a.jpg')
      allow(ImageAnalysisService).to receive(:new).and_return(analysis_service_instance)
    end

    context 'when text is sent' do
      it 'replies with a message' do
        post '/telegram/webhook', params: text_payload

        expect(telegram_service_instance).to have_received(:send_message).at_least(:once)
      end
    end

    context 'when photo is sent' do
      it 'analyzes and replies' do
        mock_data = {
          'status' => 'success',
          'items' => [{ 'name' => 'Pizza', 'calories' => 300, 'protein_g' => 12, 'carbs_g' => 35, 'fat_g' => 10 }],
          'total_calories' => 300,
          'health_rating' => 6.5,
          'meal_type' => 'lunch'
        }
        allow(analysis_service_instance).to receive(:call).and_return(mock_data)

        post '/telegram/webhook', params: valid_photo_payload

        # Should fetch the last file_id
        expect(telegram_service_instance).to have_received(:get_file_url).with('large_id')

        # Should send at least one message (analyzing message or result)
        expect(telegram_service_instance).to have_received(:send_message).at_least(:once)
      end
    end
  end
end
