# RAG Architecture for FoodBot

This document describes the Retrieval-Augmented Generation (RAG) system used in FoodBot for semantic food search, personalized recommendations, and context-aware LLM responses.

## Table of Contents

1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Database Layer (pgvector)](#database-layer-pgvector)
4. [Embedding Generation](#embedding-generation)
5. [HNSW Indexes](#hnsw-indexes)
6. [Semantic Search](#semantic-search)
7. [RAG Context Building](#rag-context-building)
8. [LLM Integration](#llm-integration)
9. [Data Flow Examples](#data-flow-examples)
10. [Performance Considerations](#performance-considerations)
11. [Maintenance & Operations](#maintenance--operations)

---

## Overview

FoodBot uses RAG to enhance LLM responses with relevant context from the user's food history and a curated food catalog. The system enables:

- **Semantic food search**: Find foods by meaning, not just keywords ("something light for dinner" → Saag, Chiura)
- **Personalized recommendations**: Rank results based on user preferences, dietary restrictions, and eating history
- **Context-aware LLM responses**: Provide the LLM with relevant user data and food matches

### Key Technologies

| Technology                    | Purpose                              |
| ----------------------------- | ------------------------------------ |
| PostgreSQL + pgvector         | Vector storage and similarity search |
| OpenAI text-embedding-3-small | 1536-dimensional embeddings          |
| HNSW indexes                  | Approximate nearest neighbor search  |
| Ruby on Rails                 | Application framework                |
| Sidekiq (ActiveJob)           | Async embedding generation           |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FoodBot RAG System                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐      │
│  │ FoodCatalog  │ │ UserFoodStat │ │    User      │ │  UserMemory  │      │
│  │   (49 foods) │ │  (history)   │ │  (profile)   │ │ (messages)   │      │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘      │
│         │                │                │                │              │
│         └────────────────┼────────────────┼────────────────┘              │
│                             ▼                                              │
│                   ┌─────────────────┐                                      │
│                   │   Embeddable    │  after_commit hook                   │
│                   │    Concern      │  triggers on create/update           │
│                   └────────┬────────┘                                      │
│                            ▼                                               │
│                   ┌─────────────────┐                                      │
│                   │ UpsertEmbedding │  Async job (Sidekiq)                 │
│                   │      Job        │                                      │
│                   └────────┬────────┘                                      │
│                            ▼                                               │
│         ┌──────────────────────────────────────┐                           │
│         │        Embeddings Module             │                           │
│         │  ┌────────────┐  ┌────────────────┐  │                           │
│         │  │TextBuilder │  │ OpenAI Client  │  │                           │
│         │  │ (semantic  │→ │ (embed API)    │  │                           │
│         │  │   text)    │  │ 1536-dim       │  │                           │
│         │  └────────────┘  └────────────────┘  │                           │
│         │         │               │            │                           │
│         │         └───────┬───────┘            │                           │
│         │                 ▼                    │                           │
│         │        ┌─────────────────┐           │                           │
│         │        │  UpsertService  │           │                           │
│         │        │ (change detect) │           │                           │
│         │        └────────┬────────┘           │                           │
│         └─────────────────┼────────────────────┘                           │
│                           ▼                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     PostgreSQL + pgvector                            │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    embeddings table                            │  │  │
│  │  │  id | record_type | record_id | kind | embedding | content_sha│   │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                      │  │
│  │  HNSW Indexes (partial, by kind):                                    │  │
│  │  ├── idx_embeddings_food_catalog_hnsw    (WHERE kind='food_catalog') │  │
│  │  ├── idx_embeddings_user_food_stat_hnsw  (WHERE kind='user_food_stat')│ │
│  │  ├── idx_embeddings_user_profile_hnsw    (WHERE kind='user_profile') │  │
│  │  └── idx_embeddings_user_memory_hnsw     (WHERE kind='user_memory')  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                           │                                                │
│                           ▼                                                │
│         ┌─────────────────────────────────────┐                            │
│         │       SemanticFoodSearch            │                            │
│         │  • Query embedding                  │                            │
│         │  • Catalog + personal history       │                            │
│         │  • Hard filters (allergies)         │                            │
│         │  • Reranking (profile similarity)   │                            │
│         └────────────────┬────────────────────┘                            │
│                          ▼                                                 │
│         ┌─────────────────────────────────────┐                            │
│         │       RagContextBuilder             │                            │
│         │  • User constraints                 │                            │
│         │  • Eating patterns                  │                            │
│         │  • User memories (semantic recall)  │                            │
│         │  • Semantic matches                 │                            │
│         │  • Query intent                     │                            │
│         └────────────────┬────────────────────┘                            │
│                          ▼                                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        LLM Services                                  │  │
│  │  ┌─────────────────┐ ┌──────────────────┐ ┌───────────────────────┐  │  │
│  │  │ImageAnalysis    │ │TextClarification │ │    AiChatService      │  │  │
│  │  │Service          │ │Service           │ │                       │  │  │
│  │  └─────────────────┘ └──────────────────┘ └───────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Database Layer (pgvector)

### Extension Setup

pgvector is a PostgreSQL extension that adds vector similarity search capabilities.

```ruby
# db/migrate/20260208050808_enable_pgvector_extension.rb
class EnablePgvectorExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'vector'
  end
end
```

### Embeddings Table

The `embeddings` table stores vector embeddings with polymorphic associations:

```ruby
# db/migrate/20260208050820_create_embeddings.rb
create_table :embeddings do |t|
  t.string :record_type, null: false      # "FoodCatalog", "UserFoodStat", "User"
  t.bigint :record_id, null: false        # ID of the source record
  t.string :kind, null: false             # "food_catalog", "user_food_stat", "user_profile"
  t.string :model, null: false            # "text-embedding-3-small"
  t.integer :dimensions, null: false      # 1536
  t.text :content, null: false            # Source text that was embedded
  t.string :content_sha, null: false      # SHA256 for change detection
  t.vector :embedding, limit: 1536        # The actual vector (pgvector type)
  t.jsonb :metadata, default: {}          # Additional searchable metadata
  t.datetime :embedded_at                 # When embedding was generated
  t.timestamps
end

# Indexes for lookups
add_index :embeddings, [:record_type, :record_id, :kind], unique: true
add_index :embeddings, :kind
add_index :embeddings, :content_sha
```

### Embedding Model

```ruby
# app/models/embedding.rb
class Embedding < ApplicationRecord
  SUPPORTED_KINDS = %w[food_catalog user_food_stat user_profile user_memory].freeze
  DEFAULT_MODEL = "text-embedding-3-small".freeze
  DEFAULT_DIMENSIONS = 1536

  belongs_to :record, polymorphic: true, optional: true
  has_neighbors :embedding  # neighbor gem for similarity search

  scope :for_kind, ->(kind) { where(kind: kind) }
  scope :for_user, ->(user_id) { where("metadata->>'user_id' = ?", user_id.to_s) }

  def self.nearest_for_kind(embedding_vector, kind:, limit: 10, user_id: nil)
    scope = for_kind(kind)
    scope = scope.for_user(user_id) if user_id.present?
    scope.nearest_neighbors(:embedding, embedding_vector, distance: "cosine").limit(limit)
  end
end
```

---

## Embedding Generation

### Flow Diagram

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Model Save     │────▶│  Embeddable      │────▶│ UpsertEmbedding │
│  (create/update)│     │  after_commit    │     │ Job (async)     │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                        ┌─────────────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│                     UpsertService                                 │
│  1. Build semantic text via TextBuilder                          │
│  2. Check if content changed (SHA256 comparison)                 │
│  3. If changed: call OpenAI API for embedding                    │
│  4. Save embedding with metadata                                 │
└──────────────────────────────────────────────────────────────────┘
```

### Embeddable Concern

Models include this concern to automatically sync embeddings:

```ruby
# app/models/concerns/embeddable.rb
module Embeddable
  extend ActiveSupport::Concern

  included do
    after_commit :schedule_embedding_update, on: [:create, :update],
                 if: :should_update_embedding?
  end

  class_methods do
    def embedding_kind
      raise NotImplementedError, "Subclass must define embedding_kind"
    end

    def embedding_trigger_attributes
      []  # Override to specify which attributes trigger re-embedding
    end
  end

  def schedule_embedding_update
    UpsertEmbeddingJob.perform_later(
      record_type: self.class.name,
      record_id: id,
      kind: self.class.embedding_kind
    )
  end

  private

  def should_update_embedding?
    return true if previously_new_record?

    trigger_attrs = self.class.embedding_trigger_attributes
    return true if trigger_attrs.empty?

    trigger_attrs.any? { |attr| saved_change_to_attribute?(attr) }
  end
end
```

### Model Configuration

Each embeddable model defines what triggers re-embedding:

```ruby
# app/models/food_catalog.rb
class FoodCatalog < ApplicationRecord
  include Embeddable

  def self.embedding_kind
    "food_catalog"
  end

  def self.embedding_trigger_attributes
    %w[name name_nepali name_romanized aliases description cuisine_tags
       calories_per_serving protein_g carbs_g fat_g is_nepali]
  end
end
```

### Text Builder

Converts records into semantic text for embedding:

```ruby
# app/services/embeddings/text_builder.rb
module Embeddings
  class TextBuilder
    def self.for(record, kind:)
      new(record, kind: kind).build
    end

    def build
      case @kind
      when "food_catalog"    then build_food_catalog_text
      when "user_food_stat"  then build_user_food_stat_text
      when "user_profile"    then build_user_profile_text
      end
    end

    private

    def build_food_catalog_text
      # Example output:
      # "Food: Chicken Momo / चिकन मोमो / chicken momo. Cuisine: Nepali.
      #  Tags: nepali, tibetan, street-food, protein-rich.
      #  Calories: 350 kcal per serving. Macros: 18g protein, 35g carbs, 14g fat"
      parts = []
      names = [@record.name, @record.name_nepali, @record.name_romanized, *@record.aliases].compact.uniq
      parts << "Food: #{names.join(' / ')}"
      parts << "Cuisine: Nepali" if @record.is_nepali?
      parts << "Tags: #{@record.cuisine_tags.join(', ')}" if @record.cuisine_tags.any?
      # ... more fields
      parts.join(". ")
    end
  end
end
```

### OpenAI Client

```ruby
# app/services/embeddings/openai_client.rb
module Embeddings
  class OpenaiClient
    MODEL = "text-embedding-3-small".freeze
    DIMENSIONS = 1536

    def embed(text)
      response = @client.embeddings(
        parameters: { model: MODEL, input: text, dimensions: DIMENSIONS }
      )
      response.dig("data", 0, "embedding")
    end

    def embed_batch(texts)
      response = @client.embeddings(
        parameters: { model: MODEL, input: texts, dimensions: DIMENSIONS }
      )
      response["data"].sort_by { |d| d["index"] }.map { |d| d["embedding"] }
    end
  end
end
```

---

## HNSW Indexes

### What is HNSW?

HNSW (Hierarchical Navigable Small World) is an algorithm for approximate nearest neighbor (ANN) search. It provides:

- **Speed**: O(log n) search complexity vs O(n) for brute force
- **Accuracy**: Typically 95-99% recall for top-k queries
- **Scalability**: Handles millions of vectors efficiently

### Index Creation

We use **partial indexes** to separate embeddings by kind, improving query performance:

```ruby
# db/migrate/20260208050830_add_hnsw_indexes_to_embeddings.rb
class AddHnswIndexesToEmbeddings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!  # Required for CONCURRENTLY

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
end
```

### Why Partial Indexes?

| Approach            | Query Pattern           | Benefit                    |
| ------------------- | ----------------------- | -------------------------- |
| Single index        | Scan all embeddings     | Simple but slower          |
| **Partial indexes** | Scan only relevant kind | Faster, smaller index size |

### Distance Metrics

We use `vector_cosine_ops` (cosine distance) because:

- Text embeddings are normalized
- Cosine similarity measures semantic similarity
- Range: 0 (identical) to 2 (opposite)

---

## Semantic Search

### SemanticFoodSearch Service

The main search service combines multiple signals for ranking:

```ruby
# app/services/semantic_food_search.rb
class SemanticFoodSearch
  QUERY_WEIGHT = 0.55      # Weight for query-to-food similarity
  PROFILE_WEIGHT = 0.30    # Weight for user profile match
  FREQUENCY_WEIGHT = 0.15  # Weight for eating frequency

  def search(query:, limit: 10, include_catalog: true, include_personal: true)
    # 1. Embed the query
    normalized_query = normalize_query(query)
    query_embedding = @openai_client.embed(normalized_query)

    # 2. Load user profile embedding for reranking
    user_profile_embedding = load_user_profile_embedding

    # 3. Search personal history + catalog
    results = []
    results.concat(search_personal_foods(query_embedding)) if include_personal
    results.concat(search_catalog(query_embedding)) if include_catalog

    # 4. Apply hard filters (allergies, dislikes)
    results = apply_hard_filters(results)

    # 5. Rerank based on multiple signals
    results = rerank_results(results, query_embedding, user_profile_embedding)

    results.first(limit)
  end
end
```

### Search Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Search Flow                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   User Query: "something light for dinner"                          │
│         │                                                           │
│         ▼                                                           │
│   ┌─────────────────────────────────────────┐                       │
│   │         Query Normalization             │                       │
│   │  + User context (language, health goal) │                       │
│   │  → "something light for dinner.         │                       │
│   │     (Nepali food preference).           │                       │
│   │     low calorie, light"                 │                       │
│   └────────────────┬────────────────────────┘                       │
│                    ▼                                                │
│   ┌─────────────────────────────────────────┐                       │
│   │         OpenAI Embed API                │                       │
│   │         → 1536-dim vector               │                       │
│   └────────────────┬────────────────────────┘                       │
│                    │                                                │
│         ┌─────────┴─────────┐                                      │
│         ▼                   ▼                                      │
│  ┌──────────────┐   ┌──────────────┐                               │
│  │Personal Foods│   │Food Catalog  │                               │
│  │(user history)│   │(all foods)   │                               │
│  │  HNSW scan   │   │  HNSW scan   │                               │
│  └──────┬───────┘   └──────┬───────┘                               │
│         │                   │                                      │
│         └─────────┬─────────┘                                      │
│                   ▼                                                │
│   ┌─────────────────────────────────────────┐                      │
│   │           Hard Filters                   │                      │
│   │  - Remove allergens (user.allergies)    │                      │
│   │  - Remove dislikes (user.dislikes)      │                      │
│   └────────────────┬────────────────────────┘                      │
│                    ▼                                               │
│   ┌─────────────────────────────────────────┐                      │
│   │          Multi-Signal Reranking         │                      │
│   │                                         │                      │
│   │  final_score = 0.55 × query_similarity  │                      │
│   │             + 0.30 × profile_similarity │                      │
│   │             + 0.15 × frequency_score    │                      │
│   └────────────────┬────────────────────────┘                      │
│                    ▼                                               │
│   ┌─────────────────────────────────────────┐                      │
│   │          Ranked Results                 │                      │
│   │  1. Saag (37.2% similarity)             │                      │
│   │  2. Chiura (35.8% similarity)           │                      │
│   │  3. Dahi (34.5% similarity)             │                      │
│   └─────────────────────────────────────────┘                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Similarity Calculation

```ruby
# Cosine similarity = 1 - cosine_distance
# pgvector returns cosine distance (0-2), we convert to similarity (0-1)

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
      similarity: 1 - emb.neighbor_distance,  # Convert distance to similarity
      source: "catalog",
      metadata: emb.metadata
    )
  end
end
```

---

## RAG Context Building

### RagContextBuilder Service

Constructs rich context for LLM prompts:

```ruby
# app/services/rag_context_builder.rb
class RagContextBuilder
  def initialize(user:)
    @user = user
  end

  def build_for_recommendation(query:, limit: 5)
    search = SemanticFoodSearch.new(user: @user)
    results = search.search(query: query, limit: limit)

    build(query: query, semantic_results: results)
  end

  def build(query: nil, semantic_results: [], include_eating_patterns: true)
    sections = []
    sections << build_user_constraints_section
    sections << build_eating_patterns_section if include_eating_patterns
    sections << build_semantic_matches_section(semantic_results) if semantic_results.any?
    sections << build_query_context_section(query) if query.present?
    sections.compact.join("\n\n")
  end
end
```

### Context Sections

#### 1. User Constraints (Always Included)

```markdown
## User Constraints (Must Follow)

- Language: Nepali
- Health Goal: Weight loss (prefer lower calorie options)
- Daily Calorie Target: 1800 kcal
- Diet: Vegetarian (NO meat, fish, eggs)
- ALLERGIES (NEVER recommend): peanuts, shellfish
- Dislikes (avoid if possible): bitter gourd
- Intermittent Fasting: OUTSIDE eating window (fasting)
- Portion size: 80% of standard
```

#### 2. Eating Patterns (Last 14 Days)

```markdown
## User Eating Patterns (Last 14 Days)

- Total meals logged: 42
- Avg daily calories: 1650 kcal
- Avg protein: 65g, Carbs: 180g, Fat: 55g
- Top foods: Dal Bhat (12x), Roti (8x), Saag (6x)
- Healthy choices: Saag, Mixed Vegetable Curry, Dahi
- Could improve: Samosa, Jalebi
```

#### 3. Semantic Matches

```markdown
## Relevant Food Matches

1. Saag (80 kcal, 4.0g protein) [nepali, vegetarian, healthy] - Food catalog
2. Mixed Vegetable Curry (140 kcal, 5.0g protein) - Food catalog
3. Dal Bhat (450 kcal avg, eaten 12x) - User's history
```

#### 4. Query Context

```markdown
## User Query Context

Query: "something light for dinner"
Detected intent: Dinner recommendation
```

---

## LLM Integration

### Integration Points

RAG context is injected into three main LLM services:

```ruby
# 1. Image Analysis (food photo → nutrition)
# app/services/image_analysis_service.rb
def build_prompt
  builder = RagContextBuilder.new(user: @user)
  rag_context = builder.build(include_eating_patterns: true)

  <<~PROMPT
    #{rag_context}

    Analyze this food image and estimate nutrition...
  PROMPT
end

# 2. Text Clarification (ambiguous input → structured food)
# app/services/text_clarification_service.rb
def build_prompt(text)
  builder = RagContextBuilder.new(user: @user)
  rag_context = builder.build_for_recommendation(query: text)

  <<~PROMPT
    #{rag_context}

    Parse this food description: "#{text}"
  PROMPT
end

# 3. AI Chat (general food questions)
# app/services/ai_chat_service.rb
def build_messages
  builder = RagContextBuilder.new(user: @user)
  rag_context = builder.build_for_recommendation(query: @message)

  [
    { role: "system", content: system_prompt_with_rag(rag_context) },
    *conversation_history,
    { role: "user", content: @message }
  ]
end
```

### LLM Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         LLM Request Flow                                  │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   User Input                                                             │
│   (text/image)                                                           │
│        │                                                                 │
│        ▼                                                                 │
│   ┌────────────────────────────────────────────────────────────────┐     │
│   │                    LLM Service                                 │     │
│   │  (ImageAnalysis / TextClarification / AiChat)                  │     │
│   └────────────────────────────┬───────────────────────────────────┘     │
│                                │                                         │
│                                ▼                                         │
│   ┌────────────────────────────────────────────────────────────────┐     │
│   │                 RagContextBuilder                              │     │
│   │                                                                │     │
│   │   ┌─────────────────────────────────────────────────────────┐  │     │
│   │   │  1. User Constraints                                    │  │     │
│   │   │     - Allergies, diet, health goal, language            │  │     │
│   │   └─────────────────────────────────────────────────────────┘  │     │
│   │                           +                                    │     │
│   │   ┌─────────────────────────────────────────────────────────┐  │     │
│   │   │  2. SemanticFoodSearch                                  │  │     │
│   │   │     - Query → embedding → HNSW search → rerank          │  │     │
│   │   └─────────────────────────────────────────────────────────┘  │     │
│   │                           +                                    │     │
│   │   ┌─────────────────────────────────────────────────────────┐  │     │
│   │   │  3. Eating Patterns                                     │  │     │
│   │   │     - Recent stats, top foods, trends                   │  │     │
│   │   └─────────────────────────────────────────────────────────┘  │     │
│   │                           ↓                                    │     │
│   │              Combined RAG Context                              │     │
│   └────────────────────────────┬───────────────────────────────────┘     │
│                                │                                         │
│                                ▼                                         │
│   ┌────────────────────────────────────────────────────────────────┐     │
│   │                     LLM Prompt                                 │     │
│   │                                                                │     │
│   │   System: You are a Nepali nutrition assistant...              │     │
│   │                                                                │     │
│   │   ## User Constraints (Must Follow)                            │     │
│   │   - Language: Nepali                                           │     │
│   │   - Health Goal: Weight loss                                   │     │
│   │   - ALLERGIES: peanuts                                         │     │
│   │                                                                │     │
│   │   ## Relevant Food Matches                                     │     │
│   │   1. Saag (80 kcal) - low calorie, vegetarian                  │     │
│   │   2. Chiura (180 kcal) - quick, light                          │     │
│   │                                                                │     │
│   │   User: "What should I eat for dinner?"                        │     │
│   └────────────────────────────┬───────────────────────────────────┘     │
│                                │                                         │
│                                ▼                                         │
│   ┌────────────────────────────────────────────────────────────────┐     │
│   │                   OpenAI GPT-4                                 │     │
│   │              (with grounded context)                           │     │
│   └────────────────────────────┬───────────────────────────────────┘     │
│                                │                                         │
│                                ▼                                         │
│   ┌────────────────────────────────────────────────────────────────┐     │
│   │                  Contextual Response                           │     │
│   │                                                                │     │
│   │  "Based on your weight loss goal, I recommend Saag (80 kcal)   │     │
│   │   with Chiura. This is a light, vegetarian option that fits    │     │
│   │   your dietary preferences..."                                 │     │
│   └────────────────────────────────────────────────────────────────┘     │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Examples

### Example 1: New Food Added to Catalog

```
Admin adds "Sel Roti" to FoodCatalog
        │
        ▼
FoodCatalog.create!(name: "Sel Roti", name_nepali: "सेल रोटी", ...)
        │
        ▼
after_commit → should_update_embedding? → true (new record)
        │
        ▼
UpsertEmbeddingJob.perform_later(record_type: "FoodCatalog", ...)
        │
        ▼ (async)
TextBuilder: "Food: Sel Roti / सेल रोटी / sel roti. Cuisine: Nepali.
              Tags: nepali, festive, breakfast, sweet. Calories: 180 kcal..."
        │
        ▼
OpenAI API → [0.023, -0.015, 0.042, ...] (1536 dims)
        │
        ▼
Embedding.create!(record_type: "FoodCatalog", record_id: 49,
                  kind: "food_catalog", embedding: [...])
        │
        ▼
HNSW index automatically updated (idx_embeddings_food_catalog_hnsw)
```

### Example 2: User Searches for Food

```
User: "I want something sweet for Tihar"
        │
        ▼
SemanticFoodSearch.new(user: user).search(query: "something sweet for Tihar")
        │
        ▼
normalize_query: "something sweet for Tihar. (Nepali food preference)"
        │
        ▼
OpenAI API → query_embedding [0.031, 0.019, ...] (1536 dims)
        │
        ▼
┌─────────────────────────────────────────────────────────┐
│ PostgreSQL Query:                                        │
│                                                         │
│ SELECT * FROM embeddings                                │
│ WHERE kind = 'food_catalog'                             │
│ ORDER BY embedding <=> '[0.031, 0.019, ...]'            │
│ LIMIT 10;                                               │
│                                                         │
│ (Uses idx_embeddings_food_catalog_hnsw via planner)     │
└─────────────────────────────────────────────────────────┘
        │
        ▼
Results: Sel Roti (0.42), Yomari (0.40), Jalebi (0.38), Kheer (0.35)...
        │
        ▼
apply_hard_filters: Remove user allergies/dislikes
        │
        ▼
rerank_results: Combine query_score + profile_score + frequency_score
        │
        ▼
Final: [Sel Roti (38.5%), Yomari (36.2%), Kheer (34.8%), ...]
```

### Example 3: User Profile Update Triggers Re-embedding

```
User updates health_goal from "maintain" to "weight_loss"
        │
        ▼
user.update!(health_goal: "weight_loss")
        │
        ▼
after_commit → should_update_embedding?
        │
        ▼
User.embedding_trigger_attributes includes "health_goal"? → YES
        │
        ▼
saved_change_to_attribute?("health_goal") → true
        │
        ▼
UpsertEmbeddingJob.perform_later(record_type: "User", kind: "user_profile")
        │
        ▼
TextBuilder: "Language: English. Health goal: Weight loss.
              Activity level: Moderate. Daily calorie target: 1800 kcal.
              Frequently eaten: Dal Bhat, Roti, Saag..."
        │
        ▼
New embedding stored → Future searches will better match low-calorie foods
```

---

## Performance Considerations

### Index Tuning

HNSW indexes have two main parameters:

| Parameter         | Default | Description                                                     |
| ----------------- | ------- | --------------------------------------------------------------- |
| `m`               | 16      | Max connections per layer (higher = better recall, more memory) |
| `ef_construction` | 64      | Size of dynamic candidate list during build                     |

For large catalogs (100k+ foods), consider:

```sql
CREATE INDEX idx_embeddings_food_catalog_hnsw
ON embeddings USING hnsw (embedding vector_cosine_ops)
WITH (m = 24, ef_construction = 100)
WHERE kind = 'food_catalog';
```

### Query-Time Parameters

```sql
-- Increase ef_search for better recall (slower)
SET hnsw.ef_search = 100;  -- Default: 40
```

### Batch Embedding

Use batch API for bulk operations:

```ruby
# Instead of N API calls:
records.each { |r| Embeddings::UpsertService.new.upsert(record: r, kind: "food_catalog") }

# Use batch (1 API call):
Embeddings::UpsertService.new.upsert_batch(records: records, kind: "food_catalog")
```

### Monitoring

```ruby
# Check index usage
ActiveRecord::Base.connection.execute(<<-SQL).to_a
  SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
  FROM pg_stat_user_indexes
  WHERE indexrelname LIKE '%hnsw%';
SQL

# Embedding counts by kind
Embedding.group(:kind).count
# => {"food_catalog"=>49, "user_food_stat"=>156, "user_profile"=>12}
```

---

## Maintenance & Operations

### Rake Tasks

```bash
# Backfill all embeddings
bin/rails embeddings:backfill_all

# Backfill specific kinds
bin/rails embeddings:backfill_food_catalogs
bin/rails embeddings:backfill_user_food_stats
bin/rails embeddings:backfill_user_profiles

# Test semantic search
bin/rails "embeddings:test_search[1,momo]"

# Show RAG context for a query
bin/rails "embeddings:show_rag_context[1,high protein breakfast]"
```

### Re-indexing

If index becomes corrupted or needs rebuilding:

```sql
-- Drop and recreate
DROP INDEX CONCURRENTLY idx_embeddings_food_catalog_hnsw;

CREATE INDEX CONCURRENTLY idx_embeddings_food_catalog_hnsw
ON embeddings USING hnsw (embedding vector_cosine_ops)
WHERE kind = 'food_catalog';
```

### Monitoring Embedding Freshness

```ruby
# Find stale embeddings (content changed but not re-embedded)
FoodCatalog.find_each do |food|
  content = Embeddings::TextBuilder.for(food, kind: "food_catalog")
  embedding = food.embedding_record

  if embedding && embedding.content_changed?(content)
    puts "Stale: #{food.name}"
  end
end
```

### Cost Estimation

OpenAI `text-embedding-3-small` pricing (as of 2024):

- $0.02 per 1M tokens
- Average food description: ~50 tokens
- 1000 foods ≈ 50,000 tokens ≈ $0.001

---

## Preference Learning (Semantic Profile Updates)

FoodBot automatically learns user preferences from natural language messages — no slash commands required.

### How It Works

```
User sends: "म मासु खाँदिन, मलाई बदाम एलर्जी छ"
        │
        ▼
TelegramController → enqueue PreferenceLearningJob (async)
        │                    + respond via AiChatService (immediate)
        ▼
PreferenceLearningJob:
  1. PreferenceExtractionService (LLM call → structured signals)
     → {signals: [{field: "vegetarian", value: true, confidence: 0.92},
                  {field: "allergies", op: "add", value: "peanut", confidence: 0.88}]}
  2. PreferenceApplierService (safe, idempotent updates to User)
     → Sets vegetarian=true, adds "peanut" to allergies
  3. UserMemory.create! (stores raw message + extraction + changes)
     → Embeddable auto-triggers UpsertEmbeddingJob for user_memory embedding
  4. TelegramService → sends confirmation:
     "🧠 बुझें — शाकाहारी सिफारिसहरू दिनेछु।
      बुझें — *peanut* बाट टाढा राख्नेछु (एलर्जी)।"
```

### Supported Auto-Detected Fields

| Field | Example Message | Extraction |
|-------|----------------|------------|
| Vegetarian/Vegan | "I don't eat meat" | `vegetarian=true` |
| Allergies | "I'm allergic to peanuts" | `allergies += "peanuts"` |
| Dislikes | "I hate onions" | `dislikes += "onions"` |
| Health goal | "I want to lose weight" | `health_goal=weight_loss` |
| Activity level | "I'm very active, I run daily" | `activity_level=very_active` |
| Portions | "I eat big portions" | `portion_modifier=1.3` |
| Language | Message in Devanagari script | `language=ne` |
| Age | "I'm 25 years old" | `age=25` |
| Weight | "I weigh 70 kg" | `weight_kg=70` |
| Height | "I'm 5 feet 8 inches" | `height_cm=173` |
| Gender | "I'm male" | `gender=male` |
| Calorie goal | "My daily target is 1800 kcal" | `daily_calorie_goal=1800` |
| Fasting | "I do 16:8 intermittent fasting" | `fasting_schedule=16_8` |

### User Memory Embeddings

User messages are stored as `UserMemory` records with `user_memory` embeddings. These are retrieved during RAG context building to provide the LLM with conversational memory:

```ruby
# RagContextBuilder includes a "User Memories" section
## User Memories (Self-reported preferences & context)
- [2026-02-10] "I don't eat meat, I'm allergic to peanuts"
- [2026-02-09] "I want to lose weight, please suggest light foods"
```

### Safety Guardrails

- **Confidence threshold**: Only signals with ≥ 0.7 confidence are applied
- **Transient vs permanent**: "I'm skipping rice today" is NOT extracted; "I don't eat rice" IS
- **Idempotent**: Same message won't be processed twice (dedupe by `source_message_id`)
- **TDEE auto-update**: When biometrics change, TDEE is recalculated automatically
- **Existing commands still work**: `/vegetarian`, `/allergic`, etc. remain functional

---

## Summary

The FoodBot RAG system provides:

1. **Semantic Understanding**: Vector embeddings capture meaning, not just keywords
2. **Personalization**: User profile embeddings enable preference-aware search
3. **Performance**: HNSW indexes enable sub-millisecond similarity search
4. **Automatic Sync**: Embeddable concern keeps embeddings up-to-date
5. **Rich Context**: RagContextBuilder provides comprehensive LLM context
6. **Preference Learning**: Auto-detects user preferences from natural language — no commands needed
7. **Conversational Memory**: Stores and retrieves user messages for context-aware responses

This architecture scales to millions of embeddings while maintaining fast search performance and personalized results.
