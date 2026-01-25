class WhatsappController < ApplicationController
  def receive
    sender = params[:From]
    num_media = params[:NumMedia].to_i

    if num_media > 0
      image_url = params[:MediaUrl0]
      
      # Process analysis
      analysis = ImageAnalysisService.new(image_url, nil).call
      
      if analysis
        response_body = format_response(analysis)
        TwilioService.new.send_message(to: sender, body: response_body)
      else
        TwilioService.new.send_message(to: sender, body: "Maaff garnuho, maile tyo photo bhujna sakina. Khana ko saafa photo pathaunu hola.")
      end
    else
      TwilioService.new.send_message(to: sender, body: "Kripaya khana ko photo pathaunu hola! 📸")
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("Error processing message: #{e.message}")
    head :internal_server_error
  end

  private

  def format_response(analysis)
    case analysis['status']
    when 'success'
      foods_str = analysis['foods'].map { |f| "- #{f['name']}: #{f['calories']} kcal" }.join("\n")
      <<~RESPONSE
        🍽️ Khana ko Bibran

        #{foods_str}

        Jamma: #{analysis['total']['calories']} kcal
        Protein: #{analysis['total']['protein_g']}g | Carbs: #{analysis['total']['carbs_g']}g | Fat: #{analysis['total']['fat_g']}g

        ⚠️ Calorie haru anumantit hun.
      RESPONSE
    when 'uncertain'
      "🤔 #{analysis['follow_up_prompt']}"
    else
      "😕 #{analysis['reason'] || 'Analysis failed'}"
    end
  end
end
