require 'rails_helper'

RSpec.describe "Comprehensive Bot Verification", type: :request do
  let(:chat_id) { 123456789 }
  let(:user_id) { 123456789 }
  let(:from_data) { { id: user_id, first_name: "TestUser" } }
  
  let(:telegram_service_instance) { instance_double(TelegramService) }
  let(:analysis_service_instance) { instance_double(ImageAnalysisService) }

  before do
    allow(TelegramService).to receive(:new).and_return(telegram_service_instance)
    allow(telegram_service_instance).to receive(:send_message)
    allow(telegram_service_instance).to receive(:get_file_url).and_return('http://img.com/a.jpg')
    allow(ImageAnalysisService).to receive(:new).and_return(analysis_service_instance)
  end

  def send_command(text)
    post '/telegram/webhook', params: {
      message: {
        chat: { id: chat_id },
        from: from_data,
        text: text
      }
    }
  end

  describe "Core Commands" do
    it "responds to /start with welcome message and help tip" do
      send_command("/start")
      expect(response).to have_http_status(:ok)
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("Use /help to see all commands"))
      )
    end

    it "responds to /help with usage instructions" do
      User.create!(telegram_id: user_id, first_name: "TestUser")
      send_command("/help")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("KhanaAI Commands"))
      )
    end

    it "responds to /stats with profile info" do
      User.create!(telegram_id: user_id, first_name: "TestUser")
      send_command("/stats")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("Your Profile"))
      )
    end

    it "responds to /about with app info" do
      send_command("/about")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("KhanaAI v1.0"))
      )
    end
  end

  describe "Data Commands" do
    let!(:user) { User.create!(telegram_id: user_id, first_name: "TestUser") }

    it "responds to /today" do
      send_command("/today")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: /today|Nothing logged/)
      )
    end

    it "responds to /undo" do
      user.meals.create!(estimated_calories: 500, eaten_at: Time.current, meal_type: 'lunch', input_type: 'image')
      expect {
        send_command("/undo")
      }.to change { user.meals.count }.by(-1)
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: /Removed|हटाउनुहोस्/)
      )
    end
  end

  describe "Preference Commands" do
    let!(:user) { User.create!(telegram_id: user_id, first_name: "TestUser") }

    it "toggles language with /language" do
      expect(user.language).to eq('en')
      send_command("/language")
      expect(user.reload.language).to eq('ne')
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("नेपालीमा कुरा गर्छु"))
      )

      # Verify persistence
      send_command("/help")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("कसरी प्रयोग गर्ने"))
      )
    end

    it "sets vegetarian preference" do
      send_command("/vegetarian")
      expect(user.reload.is_vegetarian?).to be true
    end

    it "adds allergy with /allergic" do
      send_command("/allergic peanuts")
      expect(user.reload.dietary_preferences["allergies"]).to include("peanuts")
    end

    it "sets goals with /setgoals" do
      send_command("/setgoals 2500")
      expect(user.reload.daily_calorie_goal).to eq(2500)
    end

    it "returns error for invalid goal values" do
      send_command("/setgoals 99999")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("Please enter a value between 800-5000"))
      )
      expect(user.reload.daily_calorie_goal).to eq(2000) # Assuming default
    end
  end

  describe "Location Feature Removal Verification" do
    let!(:user) { User.create!(telegram_id: user_id, first_name: "TestUser") }

    it "treats /setlocation as a casual text message instead of a command" do
      send_command("/setlocation Kathmandu")
      # It should fall through to casual response
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: match(/📸|Snap|Show/))
      )
    end

    it "treats /location as a casual text message" do
      send_command("/location")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: match(/📸|Snap|Show/))
      )
    end
  end

  describe "Stability in various scenarios" do
    it "handles unknown text gracefully for non-existent user" do
      send_command("Hello bot")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("Hey there! 👋 Send /start"))
      )
    end

    it "handles unknown text for existing user" do
      User.create!(telegram_id: user_id, first_name: "TestUser")
      send_command("I'm hungry")
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: match(/📸|Snap|Show/))
      )
    end

    it "doesn't crash on standard error in webhook" do
      # Simulate error by passing malformed params if possible, 
      # or just ensuring it returns :ok even if something is weird
      post '/telegram/webhook', params: { unknown: :garbage }
      expect(response).to have_http_status(:ok)
    end

    it "handles follow-up text after an uncertain analysis" do
      user = User.create!(telegram_id: user_id, first_name: "TestUser")
      # Manually set pending context
      user.set_pending_context({
        image_url: 'http://test.com/img.jpg',
        possible_foods: ['Momo'],
        calorie_range: { min: 200, max: 400 }
      })
      
      # Mock the TextClarificationService
      clarification_service = instance_double(TextClarificationService)
      allow(TextClarificationService).to receive(:new).and_return(clarification_service)
      allow(clarification_service).to receive(:call).and_return({
        'status' => 'success',
        'confidence' => 0.9,
        'meal_type' => 'snack',
        'foods' => [{'name' => 'Momo', 'quantity' => '1 plate', 'calories' => 350, 'protein_g' => 10, 'carbs_g' => 40, 'fat_g' => 10}],
        'total' => {'calories' => 350, 'protein_g' => 10, 'carbs_g' => 40, 'fat_g' => 10},
        'health_rating' => 7,
        'advice' => 'Good snack'
      })

      send_command("It was 10 pieces of steamed momo")
      
      expect(user.reload.has_pending_context?).to be false
      expect(telegram_service_instance).to have_received(:send_message).with(
        hash_including(text: include("Momo"))
      )
    end
  end
end
