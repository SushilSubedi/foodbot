module Ai
  class FoodResponseValidator
    def self.call(raw_json)
      if raw_json.nil? || raw_json.strip.empty?
        log_invalid_response(raw_json, "Empty response")
        return failure("Empty response", { error: "AI returned empty response" })
      end

      parsed = JSON.parse(raw_json, symbolize_names: true)
      result = FoodAnalysisContract.new.call(parsed)

      if result.failure?
        log_invalid_response(raw_json, result.errors.to_h)
        return failure("Validation failed", result.errors.to_h)
      end

      success(result.to_h)
    rescue JSON::ParserError => e
      log_invalid_response(raw_json, e.message)
      failure("Invalid JSON", { parse_error: e.message })
    rescue StandardError => e
      log_invalid_response(raw_json, e.message)
      failure("Validation error", { error: e.message })
    end

    def self.log_invalid_response(raw_json, errors)
      Rails.logger.error("[FoodResponseValidator] Invalid AI response")
      Rails.logger.error("[FoodResponseValidator] Errors: #{errors}")
      Rails.logger.error("[FoodResponseValidator] Raw: #{raw_json&.truncate(500)}")
    end

    def self.success(data)
      {
        success: true,
        data: deep_stringify_keys(data)
      }
    end

    def self.deep_stringify_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
      when Array
        obj.map { |v| deep_stringify_keys(v) }
      else
        obj
      end
    end

    def self.failure(message, errors)
      {
        success: false,
        error: message,
        details: errors
      }
    end
  end
end
