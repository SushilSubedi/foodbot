namespace :embeddings do
  desc "Backfill all food catalog embeddings"
  task backfill_food_catalogs: :environment do
    puts "Backfilling food catalog embeddings..."
    count = FoodCatalog.count
    puts "Found #{count} food catalogs"

    FoodCatalog.find_in_batches(batch_size: 50) do |batch|
      puts "Processing batch of #{batch.size}..."
      Embeddings::UpsertService.new.upsert_batch(records: batch, kind: "food_catalog")
    end

    puts "Done!"
  end

  desc "Backfill user food stat embeddings for active users"
  task backfill_user_food_stats: :environment do
    puts "Backfilling user food stat embeddings..."

    User.active_recently.find_each do |user|
      stats = user.user_food_stats
      next if stats.empty?

      puts "Processing #{stats.count} stats for user #{user.id}..."
      Embeddings::UpsertService.new.upsert_batch(records: stats.to_a, kind: "user_food_stat")
    end

    puts "Done!"
  end

  desc "Backfill user profile embeddings for active users"
  task backfill_user_profiles: :environment do
    puts "Backfilling user profile embeddings..."

    User.active_recently.find_each do |user|
      puts "Processing user #{user.id}..."
      Embeddings::UpsertService.new.upsert(record: user, kind: "user_profile")
    end

    puts "Done!"
  end

  desc "Backfill all embeddings (food catalogs, user stats, user profiles)"
  task backfill_all: [:backfill_food_catalogs, :backfill_user_food_stats, :backfill_user_profiles] do
    puts "All embeddings backfilled!"
  end

  desc "Test semantic search for a user"
  task :test_search, [:user_id, :query] => :environment do |_t, args|
    user = User.find(args[:user_id])
    query = args[:query] || "something light for dinner"

    puts "Searching for: #{query}"
    puts "User: #{user.first_name} (#{user.health_goal})"
    puts "-" * 50

    results = user.search_foods(query, limit: 5)

    results.each_with_index do |result, idx|
      food = result.record
      name = food.respond_to?(:display_name) ? food.display_name : food.name
      puts "#{idx + 1}. #{name} (similarity: #{(result.similarity * 100).round(1)}%, source: #{result.source})"
    end
  end

  desc "Show RAG context for a user query"
  task :show_rag_context, [:user_id, :query] => :environment do |_t, args|
    user = User.find(args[:user_id])
    query = args[:query] || "something light for dinner"

    puts "RAG Context for: #{query}"
    puts "=" * 60
    puts user.rag_context(query: query)
  end
end
