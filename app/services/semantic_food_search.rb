class SemanticFoodSearch
  Result = Struct.new(:record, :similarity, :source, :metadata, keyword_init: true)

  QUERY_WEIGHT = 0.55
  PROFILE_WEIGHT = 0.30
  FREQUENCY_WEIGHT = 0.15

  def initialize(user:, openai_client: Embeddings::OpenaiClient.new)
    @user = user
    @openai_client = openai_client
  end

  def search(query:, limit: 10, include_catalog: true, include_personal: true)
    normalized_query = normalize_query(query)
    query_embedding = @openai_client.embed(normalized_query)
    user_profile_embedding = load_user_profile_embedding

    results = []

    if include_personal
      personal_results = search_personal_foods(query_embedding, limit: limit * 2)
      results.concat(personal_results)
    end

    if include_catalog
      catalog_results = search_catalog(query_embedding, limit: limit * 2)
      results.concat(catalog_results)
    end

    results = apply_hard_filters(results)
    results = rerank_results(results, query_embedding, user_profile_embedding)
    results.first(limit)
  end

  def similar_foods(food_name:, limit: 5)
    embedding = Embedding.find_by(
      record_type: "FoodCatalog",
      kind: "food_catalog"
    )&.then { |e| e if e.content.downcase.include?(food_name.downcase) }

    embedding ||= Embedding.find_by(
      record_type: "UserFoodStat",
      kind: "user_food_stat"
    )&.then { |e| e if e.metadata["normalized_name"]&.downcase&.include?(food_name.downcase) }

    return [] unless embedding

    Embedding
      .where.not(id: embedding.id)
      .for_kind(embedding.kind)
      .nearest_neighbors(:embedding, embedding.embedding, distance: "cosine")
      .limit(limit)
      .map do |emb|
        record = emb.record_type.constantize.find_by(id: emb.record_id)
        next unless record

        Result.new(
          record: record,
          similarity: 1 - emb.neighbor_distance,
          source: emb.kind,
          metadata: emb.metadata
        )
      end.compact
  end

  private

  def normalize_query(query)
    parts = [query]

    if @user.language == "ne"
      parts << "(Nepali food preference)"
    end

    if @user.health_goal == "diabetic_friendly"
      parts << "low glycemic index, diabetic-friendly"
    elsif @user.health_goal == "weight_loss"
      parts << "low calorie, light"
    elsif @user.health_goal == "muscle_gain"
      parts << "high protein"
    end

    parts.join(". ")
  end

  def search_personal_foods(query_embedding, limit:)
    embeddings = Embedding
      .for_kind("user_food_stat")
      .for_user(@user.id)
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)

    embeddings.filter_map do |emb|
      stat = UserFoodStat.find_by(id: emb.record_id)
      next unless stat

      Result.new(
        record: stat,
        similarity: 1 - emb.neighbor_distance,
        source: "personal",
        metadata: emb.metadata.merge(times_eaten: stat.times_eaten)
      )
    end
  end

  def search_catalog(query_embedding, limit:)
    embeddings = Embedding
      .for_kind("food_catalog")
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)

    embeddings.filter_map do |emb|
      food = FoodCatalog.find_by(id: emb.record_id)
      next unless food

      Result.new(
        record: food,
        similarity: 1 - emb.neighbor_distance,
        source: "catalog",
        metadata: emb.metadata
      )
    end
  end

  def load_user_profile_embedding
    embedding = Embedding.find_by(
      record_type: "User",
      record_id: @user.id,
      kind: "user_profile"
    )

    embedding&.embedding
  end

  def apply_hard_filters(results)
    allergies = @user.allergies.map(&:downcase)
    dislikes = @user.dislikes.map(&:downcase)

    results.reject do |result|
      food_name = extract_food_name(result).downcase

      allergies.any? { |a| food_name.include?(a) } ||
        dislikes.any? { |d| food_name.include?(d) }
    end
  end

  def extract_food_name(result)
    case result.record
    when FoodCatalog
      [result.record.name, result.record.name_nepali, result.record.name_romanized].compact.join(" ")
    when UserFoodStat
      result.record.normalized_name
    else
      ""
    end
  end

  def rerank_results(results, query_embedding, user_profile_embedding)
    max_frequency = [results.map { |r| r.metadata[:times_eaten] || 0 }.max || 1, 1].max

    results.map do |result|
      query_score = result.similarity || 0.0
      profile_score = calculate_profile_similarity(result, user_profile_embedding)
      frequency_score = (result.metadata[:times_eaten] || 0).to_f / max_frequency

      final_score = (QUERY_WEIGHT * query_score) +
                    (PROFILE_WEIGHT * profile_score) +
                    (FREQUENCY_WEIGHT * frequency_score)

      result.similarity = final_score.nan? ? 0.0 : final_score
      result
    end.sort_by { |r| -(r.similarity || 0.0) }
  end

  def calculate_profile_similarity(result, user_profile_embedding)
    return 0.5 unless user_profile_embedding

    record_embedding = Embedding.find_by(
      record_type: result.record.class.name,
      record_id: result.record.id
    )&.embedding

    return 0.5 unless record_embedding

    1 - cosine_distance(user_profile_embedding, record_embedding)
  end

  def cosine_distance(vec1, vec2)
    return 1.0 unless vec1 && vec2 && vec1.length == vec2.length

    dot_product = vec1.zip(vec2).sum { |a, b| a * b }
    magnitude1 = Math.sqrt(vec1.sum { |x| x * x })
    magnitude2 = Math.sqrt(vec2.sum { |x| x * x })

    return 1.0 if magnitude1.zero? || magnitude2.zero?

    result = 1 - (dot_product / (magnitude1 * magnitude2))
    result.nan? ? 1.0 : result.clamp(0.0, 2.0)
  end
end
