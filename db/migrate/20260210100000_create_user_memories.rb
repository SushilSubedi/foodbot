class CreateUserMemories < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    create_table :user_memories do |t|
      t.bigint :user_id, null: false
      t.string :source, default: "telegram"
      t.string :source_message_id
      t.text :text, null: false
      t.string :language
      t.jsonb :extraction, default: {}
      t.jsonb :applied_changes, default: {}
      t.decimal :confidence, precision: 3, scale: 2

      t.timestamps
    end

    add_foreign_key :user_memories, :users
    add_index :user_memories, :user_id
    add_index :user_memories, [:user_id, :source_message_id], unique: true, where: "source_message_id IS NOT NULL", name: "idx_user_memories_on_user_id_and_source_message_id"
    add_index :user_memories, :created_at

    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_user_memory_hnsw
      ON embeddings USING hnsw (embedding vector_cosine_ops)
      WHERE kind = 'user_memory';
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_embeddings_user_memory_hnsw"
    drop_table :user_memories
  end
end
