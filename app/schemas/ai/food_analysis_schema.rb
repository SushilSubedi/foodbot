module Ai
  FoodAnalysisSchema = Dry::Schema.Params do
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
end
