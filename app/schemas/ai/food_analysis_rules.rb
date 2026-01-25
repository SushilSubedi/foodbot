module Ai
  class FoodAnalysisContract < Dry::Validation::Contract
    params do
      required(:status).filled(:string)

      # Success fields
      optional(:meal_type).filled(:string)
      optional(:foods).array(:hash) do
        required(:name).filled(:string)
        required(:normalized_name).filled(:string)
        required(:quantity).filled(:string)
        required(:portion_size).filled(:string)
        required(:calories).filled(:integer)
        required(:protein_g).filled(:float)
        required(:carbs_g).filled(:float)
        required(:fat_g).filled(:float)
      end

      optional(:total).hash do
        required(:calories).filled(:integer)
        required(:protein_g).filled(:float)
        required(:carbs_g).filled(:float)
        required(:fat_g).filled(:float)
      end

      optional(:balance).filled(:string)
      required(:health_rating).filled(:integer)
      optional(:advice).filled(:string)
      optional(:confidence).filled(:float)
      optional(:assumptions).array(:string)

      # Uncertain fields
      optional(:possible_foods).array(:string)
      optional(:estimated_calorie_range).hash do
        required(:min).filled(:integer)
        required(:max).filled(:integer)
      end
      optional(:follow_up_prompt).filled(:string)

      # Failed fields
      optional(:reason).filled(:string)
      optional(:retry_tip).filled(:string)
    end

    # Validate status enum
    rule(:status) do
      valid_statuses = %w[success uncertain failed]
      key.failure("must be one of: #{valid_statuses.join(', ')}") unless valid_statuses.include?(value)
    end

    # Validate confidence range
    rule(:confidence) do
      key.failure("must be between 0 and 1") if value && (value < 0.0 || value > 1.0)
    end

    # Validate meal_type enum
    rule(:meal_type) do
      if value
        valid_types = %w[breakfast lunch dinner snack unknown]
        key.failure("must be one of: #{valid_types.join(', ')}") unless valid_types.include?(value)
      end
    end

    # Validate balance enum
    rule(:balance) do
      if value
        valid_balances = %w[balanced carb-heavy protein-low fat-heavy]
        key.failure("must be one of: #{valid_balances.join(', ')}") unless valid_balances.include?(value)
      end
    end

    # Validate health_rating range
    rule(:health_rating) do
      if value
        key.failure("must be between 1 and 10") unless (1..10).include?(value)
      end
    end

    # Validate portion_size in foods
    rule(:foods) do
      if value.is_a?(Array)
        value.each_with_index do |food, idx|
          if food[:portion_size]
            valid_sizes = %w[small medium large unknown]
            unless valid_sizes.include?(food[:portion_size])
              key.failure("foods[#{idx}].portion_size must be one of: #{valid_sizes.join(', ')}")
            end
          end
        end
      end
    end

    # Conditional validation based on status
    rule(:status, :foods, :total, :confidence, :health_rating) do
      case values[:status]
      when "success"
        key(:foods).failure("must be present and non-empty for success status") unless values[:foods]&.any?
        key(:total).failure("must be present for success status") unless values[:total]
        key(:confidence).failure("must be present for success status") unless values[:confidence]
        key(:health_rating).failure("must be present for success status") unless values[:health_rating]
      end
    end

    rule(:status, :possible_foods, :estimated_calorie_range, :confidence) do
      if values[:status] == "uncertain"
        key(:possible_foods).failure("must be present and non-empty for uncertain status") unless values[:possible_foods]&.any?
        key(:estimated_calorie_range).failure("must be present for uncertain status") unless values[:estimated_calorie_range]
        key(:confidence).failure("must be present for uncertain status") unless values[:confidence]
      end
    end

    rule(:status, :reason, :retry_tip) do
      if values[:status] == "failed"
        key(:reason).failure("must be present for failed status") unless values[:reason]
        key(:retry_tip).failure("must be present for failed status") unless values[:retry_tip]
      end
    end

    # Validate calorie range makes sense
    rule(:estimated_calorie_range) do
      if value.is_a?(Hash) && value[:min] && value[:max]
        key.failure("min must be less than max") if value[:min] >= value[:max]
        key.failure("min must be positive") if value[:min] < 0
      end
    end
  end
end
