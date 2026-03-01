class BackfillEmbeddingsJob < ApplicationJob
  queue_as :embeddings

  BATCH_SIZE = 50

  def perform(kind:, scope: nil)
    case kind
    when "food_catalog"
      backfill_food_catalogs
    when "user_food_stat"
      backfill_user_food_stats(scope)
    when "user_profile"
      backfill_user_profiles(scope)
    else
      raise ArgumentError, "Unknown kind: #{kind}"
    end
  end

  private

  def backfill_food_catalogs
    FoodCatalog.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      Embeddings::UpsertService.new.upsert_batch(records: batch, kind: "food_catalog")
    end
  end

  def backfill_user_food_stats(scope)
    relation = UserFoodStat.includes(:user)
    relation = relation.where(user_id: scope[:user_ids]) if scope&.dig(:user_ids)
    relation = relation.joins(:user).merge(User.active_recently) if scope&.dig(:active_only)

    relation.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      Embeddings::UpsertService.new.upsert_batch(records: batch, kind: "user_food_stat")
    end
  end

  def backfill_user_profiles(scope)
    relation = User.all
    relation = relation.where(id: scope[:user_ids]) if scope&.dig(:user_ids)
    relation = relation.active_recently if scope&.dig(:active_only)

    relation.find_each do |user|
      Embeddings::UpsertService.new.upsert(record: user, kind: "user_profile")
    end
  end
end
