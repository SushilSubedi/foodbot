class RagContextBuilder
  def initialize(user:)
    @user = user
  end

  def build(query: nil, semantic_results: [], include_eating_patterns: true)
    sections = []

    sections << build_user_constraints_section
    sections << build_eating_patterns_section if include_eating_patterns
    sections << build_user_memories_section(query)
    sections << build_semantic_matches_section(semantic_results) if semantic_results.any?
    sections << build_query_context_section(query) if query.present?

    sections.compact.join("\n\n")
  end

  def build_for_recommendation(query:, limit: 5)
    search = SemanticFoodSearch.new(user: @user)
    results = search.search(query: query, limit: limit)

    build(query: query, semantic_results: results)
  end

  private

  def build_user_constraints_section
    parts = ["## User Constraints (Must Follow)"]

    parts << "- Language: #{@user.language == 'ne' ? 'Nepali' : 'English'}"
    parts << "- Health Goal: #{humanize_goal(@user.health_goal)}"
    parts << "- Daily Calorie Target: #{@user.recommended_daily_calories} kcal"

    if @user.is_vegetarian?
      parts << "- Diet: Vegetarian (NO meat, fish, eggs)"
    elsif @user.is_vegan?
      parts << "- Diet: Vegan (NO animal products)"
    end

    if @user.allergies.any?
      parts << "- ALLERGIES (NEVER recommend): #{@user.allergies.join(', ')}"
    end

    if @user.dislikes.any?
      parts << "- Dislikes (avoid if possible): #{@user.dislikes.join(', ')}"
    end

    if @user.intermittent_fasting_enabled?
      status = @user.in_eating_window? ? "IN eating window" : "OUTSIDE eating window (fasting)"
      parts << "- Intermittent Fasting: #{status}"
    end

    if @user.portion_modifier && @user.portion_modifier != 1.0
      pct = (@user.portion_modifier * 100).round
      parts << "- Portion size: #{pct}% of standard (adjust recommendations accordingly)"
    end

    parts.join("\n")
  end

  def build_eating_patterns_section
    parts = ["## User Eating Patterns (Last 14 Days)"]

    stats = calculate_recent_stats
    if stats[:total_meals] > 0
      parts << "- Total meals logged: #{stats[:total_meals]}"
      parts << "- Avg daily calories: #{stats[:avg_daily_calories]} kcal"
      parts << "- Avg protein: #{stats[:avg_protein]}g, Carbs: #{stats[:avg_carbs]}g, Fat: #{stats[:avg_fat]}g"
    end

    top_foods = @user.top_foods(5)
    if top_foods.any?
      food_list = top_foods.map { |f| "#{f.display_name} (#{f.times_eaten}x)" }.join(", ")
      parts << "- Top foods: #{food_list}"
    end

    healthy_foods = @user.user_food_stats.healthy.recent.limit(3)
    if healthy_foods.any?
      parts << "- Healthy choices: #{healthy_foods.map(&:display_name).join(', ')}"
    end

    needs_improvement = @user.user_food_stats.needs_improvement.recent.limit(3)
    if needs_improvement.any?
      parts << "- Could improve: #{needs_improvement.map(&:display_name).join(', ')}"
    end

    parts.join("\n")
  end

  def build_semantic_matches_section(results)
    return nil if results.empty?

    parts = ["## Relevant Food Matches"]

    results.each_with_index do |result, idx|
      food = result.record
      source = result.source == "personal" ? "User's history" : "Food catalog"

      case food
      when FoodCatalog
        name = [food.name, food.name_nepali].compact.first
        info = "#{food.calories_per_serving} kcal"
        info += ", #{food.protein_g}g protein" if food.protein_g
        tags = food.cuisine_tags.any? ? " [#{food.cuisine_tags.join(', ')}]" : ""
        parts << "#{idx + 1}. #{name} (#{info})#{tags} - #{source}"
      when UserFoodStat
        parts << "#{idx + 1}. #{food.display_name} (#{food.avg_calories&.round} kcal avg, eaten #{food.times_eaten}x) - #{source}"
      end
    end

    parts.join("\n")
  end

  def build_query_context_section(query)
    parts = ["## User Query Context"]
    parts << "Query: \"#{query}\""

    intent = detect_intent(query)
    parts << "Detected intent: #{intent}" if intent

    parts.join("\n")
  end

  def detect_intent(query)
    query_lower = query.downcase

    if query_lower.match?(/breakfast|morning|बिहान/)
      "Breakfast recommendation"
    elsif query_lower.match?(/lunch|दिउँसो|khana/)
      "Lunch recommendation"
    elsif query_lower.match?(/dinner|evening|साँझ|beluka/)
      "Dinner recommendation"
    elsif query_lower.match?(/snack|light|हल्का/)
      "Light snack recommendation"
    elsif query_lower.match?(/protein|muscle|प्रोटिन/)
      "High-protein food"
    elsif query_lower.match?(/low cal|diet|हल्का|light/)
      "Low-calorie option"
    elsif query_lower.match?(/warm|hot|तातो|गरम/)
      "Warm/hot food"
    elsif query_lower.match?(/quick|fast|छिटो/)
      "Quick meal"
    end
  end

  def build_user_memories_section(query)
    return nil unless query.present? && @user.user_memories.exists?

    openai = Embeddings::OpenaiClient.new
    query_embedding = openai.embed(query)

    memory_embeddings = Embedding.nearest_for_kind(
      query_embedding, kind: "user_memory", user_id: @user.id, limit: 5
    )

    return nil if memory_embeddings.empty?

    memories = memory_embeddings.filter_map do |emb|
      memory = UserMemory.find_by(id: emb.record_id)
      next unless memory
      { text: memory.text, date: memory.created_at.strftime("%Y-%m-%d") }
    end

    return nil if memories.empty?

    parts = ["## User Memories (Self-reported preferences & context)"]
    memories.each do |mem|
      parts << "- [#{mem[:date]}] \"#{mem[:text].truncate(150)}\""
    end

    parts.join("\n")
  end

  def calculate_recent_stats
    stats = @user.user_daily_stats.where("date >= ?", 14.days.ago)

    {
      total_meals: @user.meals.where("eaten_at >= ?", 14.days.ago).count,
      avg_daily_calories: stats.average(:total_calories)&.round || 0,
      avg_protein: stats.average(:total_protein_g)&.round || 0,
      avg_carbs: stats.average(:total_carbs_g)&.round || 0,
      avg_fat: stats.average(:total_fat_g)&.round || 0
    }
  end

  def humanize_goal(goal)
    case goal
    when "weight_loss" then "Weight loss (prefer lower calorie options)"
    when "muscle_gain" then "Muscle gain (prioritize protein)"
    when "diabetic_friendly" then "Diabetic-friendly (low GI, reduced sugar/carbs)"
    else "Maintain weight"
    end
  end
end
