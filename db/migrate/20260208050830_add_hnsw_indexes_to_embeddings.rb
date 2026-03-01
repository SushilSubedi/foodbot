class AddHnswIndexesToEmbeddings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_food_catalog_hnsw
      ON embeddings USING hnsw (embedding vector_cosine_ops)
      WHERE kind = 'food_catalog';
    SQL

    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_user_food_stat_hnsw
      ON embeddings USING hnsw (embedding vector_cosine_ops)
      WHERE kind = 'user_food_stat';
    SQL

    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_user_profile_hnsw
      ON embeddings USING hnsw (embedding vector_cosine_ops)
      WHERE kind = 'user_profile';
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_embeddings_food_catalog_hnsw"
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_embeddings_user_food_stat_hnsw"
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_embeddings_user_profile_hnsw"
  end
end
