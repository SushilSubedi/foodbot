class CreateEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :embeddings do |t|
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :kind, null: false
      t.string :model, null: false
      t.integer :dimensions, null: false
      t.text :content, null: false
      t.string :content_sha, null: false
      t.vector :embedding, limit: 1536, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :embedded_at

      t.timestamps
    end

    add_index :embeddings, [:record_type, :record_id, :kind], unique: true, name: "idx_embeddings_on_record_and_kind"
    add_index :embeddings, :kind
    add_index :embeddings, :content_sha
  end
end
