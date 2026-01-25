require 'rails_helper'

RSpec.describe ImageAnalysisService do
  let(:service) { described_class.new('http://example.com/image.jpg', 'fake caption') }
  let(:mock_client) { double('GeminiClient') }
  let(:mock_image_data) { 'fake_image_data' }
  
  before do
    allow(URI).to receive(:open).and_return(StringIO.new(mock_image_data))
    allow(Gemini).to receive(:new).and_return(mock_client)
    allow(ENV).to receive(:[]).with('GEMINI_API_KEY').and_return('fake_key')
  end

  describe '#call' do
    context 'when analysis is successful' do
      it 'returns parsed json' do
        mock_response = {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => '{"items": [], "total_calories": 0, "macros": {}}' }
                ]
              }
            }
          ]
        }
        allow(mock_client).to receive(:generate_content).and_return(mock_response)
        
        result = service.call
        expect(result).to be_a(Hash)
        expect(result).to have_key('items')
      end
    end

    context 'when download fails' do
      it 'returns nil' do
        allow(URI).to receive(:open).and_raise(StandardError)
        expect(service.call).to be_nil
      end
    end
  end
end
