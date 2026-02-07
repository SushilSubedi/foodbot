require 'dry-validation'

module Ai
  class FoodAnalysisContract < Dry::Validation::Contract
    params do
      required(:status).filled(:string, included_in?: %w[success uncertain failed not_food])

      optional(:meal_type).filled(:string, included_in?: %w[breakfast lunch dinner snack unknown])
      optional(:foods).array(:hash) do
        required(:name).filled(:string)
        required(:normalized_name).filled(:string)
        required(:quantity).filled(:string)
        required(:portion_size).filled(:string, included_in?: %w[small medium large unknown])
        required(:calories).filled(:integer, gteq?: 0)
        required(:protein_g).filled(:float, gteq?: 0)
        required(:carbs_g).filled(:float, gteq?: 0)
        required(:fat_g).filled(:float, gteq?: 0)
      end
      optional(:total).hash do
        required(:calories).filled(:integer, gteq?: 0)
        required(:protein_g).filled(:float, gteq?: 0)
        required(:carbs_g).filled(:float, gteq?: 0)
        required(:fat_g).filled(:float, gteq?: 0)
      end
      optional(:balance).filled(:string, included_in?: %w[balanced carb-heavy protein-low fat-heavy unbalanced])
      optional(:health_rating).filled(:float, gteq?: 1, lteq?: 10)
      optional(:advice).filled(:string)
      optional(:confidence).filled(:float, gteq?: 0, lteq?: 1)
      optional(:assumptions).array(:string)

      optional(:possible_foods).array(:string)
      optional(:estimated_calorie_range).hash do
        required(:min).filled(:integer, gteq?: 0)
        required(:max).filled(:integer, gteq?: 0)
      end
      optional(:follow_up_prompt).filled(:string)

      optional(:reason).filled(:string)
      optional(:retry_tip).filled(:string)

      optional(:detected_object).filled(:string)
      optional(:message).filled(:string)
    end

    rule(:status, :foods, :total, :meal_type, :balance, :advice, :confidence, :assumptions) do
      if values[:status] == 'success'
        key(:foods).failure('is required for success status') unless values[:foods]&.any?
        key(:total).failure('is required for success status') unless values[:total]
        key(:meal_type).failure('is required for success status') unless values[:meal_type]
        key(:balance).failure('is required for success status') unless values[:balance]
        key(:advice).failure('is required for success status') unless values[:advice]
        key(:confidence).failure('is required for success status') if values[:confidence].nil?
        key(:assumptions).failure('is required for success status') unless values[:assumptions]
      end
    end

    rule(:status, :possible_foods, :estimated_calorie_range, :confidence, :follow_up_prompt) do
      if values[:status] == 'uncertain'
        key(:possible_foods).failure('is required for uncertain status') unless values[:possible_foods]&.any?
        key(:estimated_calorie_range).failure('is required for uncertain status') unless values[:estimated_calorie_range]
        key(:confidence).failure('is required for uncertain status') if values[:confidence].nil?
        key(:follow_up_prompt).failure('is required for uncertain status') unless values[:follow_up_prompt]
      end
    end

    rule(:status, :reason, :retry_tip) do
      if values[:status] == 'failed'
        key(:reason).failure('is required for failed status') unless values[:reason]
        key(:retry_tip).failure('is required for failed status') unless values[:retry_tip]
      end
    end

    rule(:estimated_calorie_range) do
      if values[:estimated_calorie_range]
        min = values[:estimated_calorie_range][:min]
        max = values[:estimated_calorie_range][:max]
        key.failure('min must be less than or equal to max') if min && max && min > max
      end
    end

    rule(:status, :detected_object, :message) do
      if values[:status] == 'not_food'
        key(:detected_object).failure('is required for not_food status') unless values[:detected_object]
        key(:message).failure('is required for not_food status') unless values[:message]
      end
    end
  end
end
