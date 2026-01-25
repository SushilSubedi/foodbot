require 'rails_helper'

RSpec.describe "Whatsapps", type: :request do
  describe "POST /whatsapp/receive" do
    let(:params) { { From: 'whatsapp:+123', Body: 'hi', NumMedia: '0' } }
    let(:twilio_service) { instance_double(TwilioService) }

    before do
      allow(TwilioService).to receive(:new).and_return(twilio_service)
      allow(twilio_service).to receive(:send_message)
    end

    context 'with no image' do
      it 'responds effectively asking for image' do
        post '/whatsapp/receive', params: params
        expect(response).to have_http_status(:ok)
        expect(twilio_service).to have_received(:send_message).with(
          to: 'whatsapp:+123',
          body: include("Kripaya khana ko photo")
        )
      end
    end

    context 'with image' do
      let(:params) { { From: 'whatsapp:+123', Body: '', NumMedia: '1', MediaUrl0: 'http://img.com' } }
      let(:analysis_service) { instance_double(ImageAnalysisService) }

      before do
        allow(ImageAnalysisService).to receive(:new).with('http://img.com', nil).and_return(analysis_service)
      end

      it 'analyzes and responds' do
        mock_data = {
          'items' => [{'name' => 'Apple', 'calories' => 95}],
          'total_calories' => 95,
          'macros' => {'protein' => '0%', 'carbs' => '100%', 'fat' => '0%'}
        }
        allow(analysis_service).to receive(:call).and_return(mock_data)

        post '/whatsapp/receive', params: params
        
        expect(response).to have_http_status(:ok)
        expect(twilio_service).to have_received(:send_message).with(
          to: 'whatsapp:+123',
          body: include("Apple: 95 kcal")
        )
      end
    end
  end
end
