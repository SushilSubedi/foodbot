module Embeddings
  class TextBuilder
    def self.for(record, kind:)
      new(record, kind: kind).build
    end

    def initialize(record, kind:)
      @record = record
      @kind = kind
    end

    def build
      case @kind
      when "food_catalog"
        build_food_catalog_text
      when "user_food_stat"
        build_user_food_stat_text
      when "user_profile"
        build_user_profile_text
      when "user_memory"
        build_user_memory_text
      else
        raise ArgumentError, "Unknown embedding kind: #{@kind}"
      end
    end

    private

    def build_food_catalog_text
      parts = []

      names = [@record.name]
      names << @record.name_nepali if @record.name_nepali.present?
      names << @record.name_romanized if @record.name_romanized.present?
      names.concat(@record.aliases) if @record.aliases.present?
      parts << "Food: #{names.uniq.join(' / ')}"

      if @record.is_nepali?
        parts << "Cuisine: Nepali"
      end

      if @record.cuisine_tags.present? && @record.cuisine_tags.any?
        parts << "Tags: #{@record.cuisine_tags.join(', ')}"
      end

      parts << "Description: #{@record.description}" if @record.description.present?
      parts << "Serving: #{@record.default_serving}" if @record.default_serving.present?
      parts << "Calories: #{@record.calories_per_serving} kcal per serving"

      macro_parts = []
      macro_parts << "#{@record.protein_g}g protein" if @record.protein_g.present?
      macro_parts << "#{@record.carbs_g}g carbs" if @record.carbs_g.present?
      macro_parts << "#{@record.fat_g}g fat" if @record.fat_g.present?
      parts << "Macros: #{macro_parts.join(', ')}" if macro_parts.any?

      parts.join(". ")
    end

    def build_user_food_stat_text
      parts = []
      parts << "Food: #{@record.display_name}"
      parts << "Eaten #{@record.times_eaten} times"
      parts << "Usually for #{@record.most_common_meal_type}" if @record.most_common_meal_type.present?
      parts << "Average #{@record.avg_calories&.round} kcal" if @record.avg_calories.present?

      macro_parts = []
      macro_parts << "#{@record.avg_protein_g&.round}g protein" if @record.avg_protein_g.present?
      macro_parts << "#{@record.avg_carbs_g&.round}g carbs" if @record.avg_carbs_g.present?
      macro_parts << "#{@record.avg_fat_g&.round}g fat" if @record.avg_fat_g.present?
      parts << "Macros: #{macro_parts.join(', ')}" if macro_parts.any?

      parts << @record.health_category if @record.health_score.present?

      parts.join(". ")
    end

    def build_user_profile_text
      parts = []

      parts << "Language: #{@record.language == 'ne' ? 'Nepali' : 'English'}"
      parts << "Health goal: #{humanize_goal(@record.health_goal)}" if @record.health_goal.present?
      parts << "Activity level: #{@record.activity_level.humanize}" if @record.activity_level.present?
      parts << "Daily calorie target: #{@record.recommended_daily_calories} kcal"

      if @record.is_vegetarian?
        parts << "Diet: Vegetarian"
      elsif @record.is_vegan?
        parts << "Diet: Vegan"
      end

      if @record.allergies.any?
        parts << "Allergies: #{@record.allergies.join(', ')}"
      end

      if @record.dislikes.any?
        parts << "Dislikes: #{@record.dislikes.join(', ')}"
      end

      if @record.portion_modifier && @record.portion_modifier != 1.0
        size = @record.portion_modifier > 1.0 ? "larger than average" : "smaller than average"
        parts << "Portion preference: #{size}"
      end

      if @record.intermittent_fasting_enabled?
        parts << "Practices intermittent fasting (#{@record.fasting_schedule&.gsub('_', ':')})"
      end

      if @record.ai_context.present?
        parts << "Additional notes: #{@record.ai_context}"
      end

      top_foods = @record.top_foods(5).pluck(:normalized_name)
      if top_foods.any?
        parts << "Frequently eaten: #{top_foods.join(', ')}"
      end

      recent_foods = @record.recently_eaten_foods(5).pluck(:normalized_name) - top_foods
      if recent_foods.any?
        parts << "Recently eaten: #{recent_foods.join(', ')}"
      end

      parts.join(". ")
    end

    def build_user_memory_text
      parts = []
      parts << "User message (#{@record.created_at&.strftime('%Y-%m-%d')}): #{@record.text}"
      parts << "Source: #{@record.source}" if @record.source.present?
      parts.join(". ")
    end

    def humanize_goal(goal)
      case goal
      when "weight_loss" then "Weight loss"
      when "muscle_gain" then "Muscle gain"
      when "diabetic_friendly" then "Diabetic-friendly eating"
      else "Maintain weight"
      end
    end
  end
end
