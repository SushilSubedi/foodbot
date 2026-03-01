# FoodBot RAG System — Deep Technical Dive

A complete explanation of how vector databases, embeddings, HNSW indexes, semantic search,
and retrieval-augmented generation work in FoodBot — from first principles to production code.

---

## Table of Contents

1. [The Problem: Why Traditional Search Fails](#1-the-problem-why-traditional-search-fails)
2. [What Are Embeddings?](#2-what-are-embeddings)
3. [Technology Choices and Why](#3-technology-choices-and-why)
4. [Vector Database Layer (pgvector)](#4-vector-database-layer-pgvector)
5. [Embedding Generation Pipeline](#5-embedding-generation-pipeline)
6. [HNSW Indexes: Making Search Fast](#6-hnsw-indexes-making-search-fast)
7. [Semantic Search: Finding Relevant Foods](#7-semantic-search-finding-relevant-foods)
8. [RAG Context Building](#8-rag-context-building)
9. [LLM Integration: Grounding AI Responses](#9-llm-integration-grounding-ai-responses)
10. [Complete Data Flow Walkthrough](#10-complete-data-flow-walkthrough)
11. [File Reference Map](#11-file-reference-map)
12. [Operations and Maintenance](#12-operations-and-maintenance)
13. [Cost Analysis](#13-cost-analysis)
14. [Performance and Scaling](#14-performance-and-scaling)

---

## 1. The Problem: Why Traditional Search Fails

FoodBot is a Nepali nutrition assistant. Users send messages like:

- "बिहानको लागि हल्का खाना" (something light for breakfast)
- "I want something like momo but healthier"
- "high protein dinner after gym"

**Traditional SQL search cannot handle this:**

```sql
-- This finds NOTHING useful
SELECT * FROM food_catalogs WHERE name ILIKE '%light%';  -- no food named "light"
SELECT * FROM food_catalogs WHERE name ILIKE '%healthy momo%';  -- no exact match
```

The problem is that traditional search matches **characters**, not **meaning**. The word "light"
means low-calorie food, but no food in our database literally has "light" in its name.

**What we need:**

| User Says | They Mean | Should Return |
|-----------|-----------|---------------|
| "something light" | Low calorie food | Saag (80 kcal), Chiura (180 kcal) |
| "like momo but healthier" | Steamed, protein-rich, not fried | Veg Momo, Thukpa |
| "बिहान" (bihaan) | Breakfast in Nepali | Sel Roti, Paratha, Egg Bhurji |
| "high protein" | Foods rich in protein | Choila (28g), Chicken Curry (28g) |

This requires **semantic search** — searching by meaning. This is what our RAG system provides.

---

## 2. What Are Embeddings?

### The Core Idea

An **embedding** is a way to represent text as a list of numbers (a vector) where **similar
meanings produce similar numbers**. Think of it as translating human language into math.

```
"Chicken Momo"     → [0.023, -0.015, 0.042, 0.008, ..., -0.031]  (1536 numbers)
"Steamed dumpling"  → [0.021, -0.013, 0.040, 0.009, ..., -0.029]  (similar numbers!)
"Chocolate cake"    → [0.089,  0.054, -0.067, -0.032, ..., 0.076]  (very different!)
```

### Intuition: GPS for Meaning

Think of regular GPS — two numbers (latitude, longitude) that locate a place on Earth.
Places near each other geographically have similar coordinates:

```
Kathmandu:   [27.7172, 85.3240]
Bhaktapur:   [27.6710, 85.4298]   ← close to Kathmandu
New York:    [40.7128, -74.0060]  ← very far from Kathmandu
```

Embeddings work the same way, but instead of 2 dimensions for geography, we use
**1536 dimensions** for meaning. Each dimension captures some aspect of meaning —
things like "is it a protein?" "is it a breakfast food?" "is it spicy?" "is it Nepali?"
(The exact dimensions are learned by the AI model and don't have human-readable labels.)

### How OpenAI Creates Embeddings

OpenAI's embedding model was trained on billions of text pairs. During training, it learned:
- "momo" and "dumpling" should have similar vectors (same food concept)
- "momo" and "car" should have very different vectors (unrelated concepts)
- "high protein breakfast" should be close to "egg bhurji" but far from "jalebi"

We don't train this model — we just send text to OpenAI's API and get back 1536 numbers.

### Vector Math: Measuring Similarity

Once we have vectors, we can measure how similar two texts are using **cosine similarity**:

```
cosine_similarity(A, B) = (A · B) / (|A| × |B|)

Where:
  A · B = sum of (a₁×b₁ + a₂×b₂ + ... + a₁₅₃₆×b₁₅₃₆)   (dot product)
  |A|   = sqrt(a₁² + a₂² + ... + a₁₅₃₆²)                   (magnitude)
```

The result ranges from -1 to 1:
- **1.0** = identical meaning
- **0.0** = no relationship
- **-1.0** = opposite meaning

In practice, OpenAI embeddings rarely go below 0 for food-related text, so typical
similarity scores for food search are 0.25–0.55 (higher = more relevant).

### Concrete Example

When a user searches for "momo":

```
query_embedding = OpenAI.embed("momo")  →  [0.045, -0.023, 0.067, ...]

Stored embeddings in database:
  Chicken Momo:  [0.044, -0.021, 0.065, ...]  → cosine_distance = 0.31  → similarity = 0.69 ✓ HIGH
  Veg Momo:      [0.042, -0.020, 0.063, ...]  → cosine_distance = 0.33  → similarity = 0.67 ✓ HIGH
  Thukpa:        [0.038, -0.018, 0.055, ...]  → cosine_distance = 0.42  → similarity = 0.58   MEDIUM
  Jalebi:        [0.089,  0.054, -0.032, ...]  → cosine_distance = 0.72  → similarity = 0.28   LOW
```

The system correctly identifies that momos are most relevant, thukpa is somewhat related
(another Tibetan-Nepali dish), and jalebi (a sweet) is not relevant.

---

## 3. Technology Choices and Why

### 3.1 Why pgvector? (Not Pinecone, Weaviate, Qdrant)

We evaluated several vector database options:

| Technology | Type | Pros | Cons | Decision |
|------------|------|------|------|----------|
| **pgvector** | Postgres extension | Same DB, no extra infra, ACID, free, Rails-native | Less features than dedicated | **CHOSEN** |
| Pinecone | Managed cloud | Fast, auto-scaling, easy API | Extra service, $70+/mo, vendor lock-in, network latency | Overkill |
| Weaviate | Self-hosted | Feature-rich, hybrid search built-in | Requires separate deployment, ops overhead | Overkill |
| Qdrant | Self-hosted | Fast, rich filtering | Another service to manage | Overkill |
| ChromaDB | In-process | Simple, good for prototyping | Not production-grade, Python only | Wrong language |

**Why pgvector wins for FoodBot:**

1. **No new infrastructure**: We already run PostgreSQL. pgvector is just `CREATE EXTENSION vector;`.
   No extra servers, no extra costs, no extra monitoring.

2. **ACID transactions**: Embeddings are created in the same transaction as the source record.
   No syncing issues between a SQL database and a separate vector store.

3. **Co-located queries**: We can JOIN embeddings with food_catalogs, users, etc. in a single query.
   With Pinecone, you'd need: query Pinecone → get IDs → query Postgres → merge results.

4. **Scale fit**: At our current scale (49 food catalogs + user embeddings), pgvector handles
   searches in < 5ms. Dedicated vector DBs shine at millions of vectors — we don't need that yet.

5. **Cost**: Free (part of Postgres) vs $70+/month for Pinecone Starter.

### 3.2 Why `text-embedding-3-small`? (Not ada-002, Not 3-large)

| Model | Dimensions | Cost per 1M tokens | Quality (MTEB) | Decision |
|-------|-----------|---------------------|-----------------|----------|
| text-embedding-ada-002 | 1536 | $0.10 | 61.0% | Outdated |
| **text-embedding-3-small** | 1536 | $0.02 | 62.3% | **CHOSEN** |
| text-embedding-3-large | 3072 | $0.13 | 64.6% | Overkill |

**Why 3-small:**
- **5x cheaper** than ada-002 with **better quality**
- 1536 dimensions is the sweet spot (6 KB per embedding)
- For food search, the marginal quality gain of 3-large (2.3%) doesn't justify 6.5x cost and 2x storage
- Our text inputs are short (50-100 tokens per food description) — simpler models handle these well

### 3.3 Why the `neighbor` Gem? (Not raw SQL)

The [`neighbor`](https://github.com/ankane/neighbor) gem by Andrew Kane provides ActiveRecord
integration with pgvector. Without it, we'd write:

```ruby
# Without neighbor gem — raw SQL, error-prone, not composable
Embedding.find_by_sql(<<-SQL)
  SELECT *, embedding <=> '#{vector}' AS distance
  FROM embeddings
  WHERE kind = 'food_catalog'
  ORDER BY embedding <=> '#{vector}'
  LIMIT 10
SQL
```

With the neighbor gem:

```ruby
# With neighbor gem — clean, composable, safe
Embedding.for_kind("food_catalog")
         .nearest_neighbors(:embedding, vector, distance: "cosine")
         .limit(10)
```

The gem handles:
- SQL injection prevention (parameterized vectors)
- Distance metric selection (cosine, euclidean, inner product)
- Composability with ActiveRecord scopes
- Automatic `neighbor_distance` attribute on results

### 3.4 Why Cosine Distance? (Not Euclidean, Not Inner Product)

pgvector supports three distance metrics:

| Metric | Operator | Best For | Our Use |
|--------|----------|----------|---------|
| **Cosine** | `<=>` | Normalized embeddings | **CHOSEN** |
| Euclidean (L2) | `<->` | Spatial data | Not suitable |
| Inner Product | `<#>` | When magnitudes matter | Not needed |

OpenAI embeddings are **normalized** (magnitude ≈ 1.0), which means cosine distance and
euclidean distance would give similar rankings. However, cosine is the standard for text
embeddings because it measures the **angle** between vectors, ignoring magnitude — it answers
"how similar is the direction?" rather than "how close are the points?"

```
Cosine Distance = 1 - cos(θ)

  0.0 = vectors point same direction (identical meaning)
  1.0 = vectors are perpendicular (unrelated)
  2.0 = vectors point opposite directions (opposite meaning)

Cosine Similarity = 1 - Cosine Distance = cos(θ)
  1.0 = identical, 0.0 = unrelated
```

---

## 4. Vector Database Layer (pgvector)

### 4.1 Enabling pgvector

```ruby
# db/migrate/20260208050808_enable_pgvector_extension.rb
class EnablePgvectorExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'vector'
  end
end
```

This runs `CREATE EXTENSION IF NOT EXISTS vector;` in Postgres, which adds:
- The `vector(n)` data type
- Distance operators (`<=>`, `<->`, `<#>`)
- Index access methods (ivfflat, hnsw)

### 4.2 The Embeddings Table

```ruby
# db/migrate/20260208050820_create_embeddings.rb
create_table :embeddings do |t|
  t.string  :record_type, null: false      # "FoodCatalog", "UserFoodStat", "User"
  t.bigint  :record_id,   null: false      # ID of the source record
  t.string  :kind,        null: false      # "food_catalog", "user_food_stat", "user_profile"
  t.string  :model,       null: false      # "text-embedding-3-small"
  t.integer :dimensions,  null: false      # 1536
  t.text    :content,     null: false      # The source text that was embedded
  t.string  :content_sha, null: false      # SHA256 for change detection
  t.vector  :embedding, limit: 1536        # THE VECTOR (pgvector native type)
  t.jsonb   :metadata, default: {}         # Structured metadata for filtering
  t.datetime :embedded_at                  # When this embedding was last generated

  t.timestamps
end

# Unique constraint: one embedding per record per kind
add_index :embeddings, [:record_type, :record_id, :kind], unique: true

# B-tree index for filtering by kind before vector search
add_index :embeddings, :kind

# For change detection lookups
add_index :embeddings, :content_sha
```

**Design Decisions:**

**Single table vs multiple tables?** We use a single `embeddings` table with polymorphic
associations (`record_type` + `record_id`) rather than `food_catalog_embeddings`,
`user_food_stat_embeddings`, etc. This gives us:
- One model class, one set of indexes, simpler queries
- The `kind` column + partial HNSW indexes give per-type performance
- Easier to add new embeddable types (just add a new `kind`)

**Why store `content`?** For debugging. We can see exactly what text was embedded.
When search results are unexpected, we inspect the stored content to see if the
TextBuilder is producing good semantic text.

**Why `content_sha`?** To avoid unnecessary OpenAI API calls. Before calling the API
(which costs money and takes 200-500ms), we check: has the content changed since
the last embedding? If the SHA matches, we skip the API call entirely.

**Why `metadata` (JSONB)?** For filtering without JOINs. For example, when searching
user_food_stat embeddings, we filter by `metadata->>'user_id'` to scope results
to a specific user. This avoids joining the embeddings table with user_food_stats.

### 4.3 How pgvector Stores Vectors

Internally, pgvector stores each vector as a compact array of 32-bit floats.
A 1536-dimensional vector takes:

```
Storage per embedding = 1536 × 4 bytes = 6,144 bytes ≈ 6 KB

For 1000 embeddings: 6 MB
For 100,000 embeddings: 600 MB
For 1,000,000 embeddings: 6 GB
```

This is manageable. The entire food catalog (49 embeddings) uses about 300 KB of vector data.

---

## 5. Embedding Generation Pipeline

### 5.1 Overview

When a FoodCatalog, UserFoodStat, or User record is created or updated, the system
automatically generates/updates its embedding through this pipeline:

```
Record saved → after_commit → check trigger attrs → async job → build text → 
check SHA → call OpenAI → store embedding
```

Each step has a specific purpose and safeguard.

### 5.2 Step 1: Embeddable Concern (Trigger Detection)

```ruby
# app/models/concerns/embeddable.rb
module Embeddable
  extend ActiveSupport::Concern

  included do
    after_commit :schedule_embedding_update, on: [:create, :update],
                 if: :should_update_embedding?
  end
end
```

**Why `after_commit` (not `after_save`)?**

`after_save` runs inside the database transaction. If we enqueue a job during `after_save`,
the job might run before the transaction commits — the job would try to load a record
that doesn't exist yet in the database. `after_commit` guarantees the record is persisted
before the job runs.

**Why conditional with `should_update_embedding?`?**

Not every update needs re-embedding. If a user updates their `first_name`, their
dietary profile hasn't changed — no need to call OpenAI.

```ruby
def should_update_embedding?
  return true if previously_new_record?  # Always embed new records

  trigger_attrs = self.class.embedding_trigger_attributes
  return true if trigger_attrs.empty?    # If no specific triggers, always update

  # Only re-embed if a relevant attribute changed
  trigger_attrs.any? { |attr| saved_change_to_attribute?(attr) }
end
```

Each model defines which attributes are semantically meaningful:

```ruby
# FoodCatalog — re-embed when nutritional or naming info changes
%w[name name_nepali name_romanized aliases description cuisine_tags
   calories_per_serving protein_g carbs_g fat_g is_nepali]

# User — re-embed when dietary preferences change
%w[health_goal activity_level dietary_preferences ai_context
   daily_calorie_goal portion_modifier intermittent_fasting_enabled
   fasting_schedule language]

# UserFoodStat — re-embed when eating patterns change
%w[normalized_name avg_calories avg_protein_g avg_carbs_g avg_fat_g
   times_eaten health_score most_common_meal_type]
```

### 5.3 Step 2: Async Job (Background Processing)

```ruby
# app/jobs/upsert_embedding_job.rb
class UpsertEmbeddingJob < ApplicationJob
  queue_as :embeddings

  def perform(record_type:, record_id:, kind:)
    record = record_type.constantize.find_by(id: record_id)
    return unless record  # Record might have been deleted between enqueue and execution

    Embeddings::UpsertService.new.upsert(record: record, kind: kind)
  end
end
```

**Why async?** The OpenAI API call takes 200-500ms. If we did this synchronously,
every food catalog update would take half a second longer. By using SolidQueue
(our job backend), the user's request completes immediately and the embedding
updates in the background.

**Why `find_by` (not `find`)?** The record might be deleted between when the job
was enqueued and when it executes. `find` would raise `ActiveRecord::RecordNotFound`;
`find_by` returns `nil` and we gracefully exit.

### 5.4 Step 3: Text Building (Record → Semantic Text)

This is the most important step for search quality. The TextBuilder converts a
database record into a rich natural-language description that the embedding model
can understand.

```ruby
# app/services/embeddings/text_builder.rb
def build_food_catalog_text
  parts = []

  # Include ALL name variants for multilingual search
  names = [@record.name]                                          # "Chicken Momo"
  names << @record.name_nepali if @record.name_nepali.present?    # "चिकन मोमो"
  names << @record.name_romanized if @record.name_romanized.present? # "chicken momo"
  names.concat(@record.aliases) if @record.aliases.present?       # ["kukhura ko momo"]
  parts << "Food: #{names.uniq.join(' / ')}"

  # Cuisine context helps the model understand cultural category
  parts << "Cuisine: Nepali" if @record.is_nepali?

  # Tags provide semantic richness
  parts << "Tags: #{@record.cuisine_tags.join(', ')}" if @record.cuisine_tags.any?

  # Description gives the model more semantic signal
  parts << "Description: #{@record.description}" if @record.description.present?

  # Nutritional data lets searches like "high protein" work
  parts << "Calories: #{@record.calories_per_serving} kcal per serving"
  parts << "Macros: #{@record.protein_g}g protein, #{@record.carbs_g}g carbs, #{@record.fat_g}g fat"

  parts.join(". ")
end
```

**Example output for Chicken Momo:**

```
"Food: Chicken Momo / चिकन मोमो / chicken momo / kukhura ko momo / steamed momo.
 Cuisine: Nepali. Tags: nepali, tibetan, street-food, protein-rich.
 Description: Steamed dumplings filled with spiced chicken, served with tomato chutney.
 Serving: 10 pieces. Calories: 350 kcal per serving.
 Macros: 18g protein, 35g carbs, 14g fat"
```

**Why include multilingual names?** When a user searches in Nepali ("मोमो"), the query
embedding will be in the same vector space as the Nepali text in our stored embedding.
Without "चिकन मोमो" in the source text, Nepali searches would have weaker matches.

**Why include nutrition data in text?** So that queries like "high protein" or "low calorie"
can be semantically matched to foods with high protein or low calories. The embedding
model understands that "18g protein" is semantically related to "high protein".

**User Profile text is even richer:**

```
"Language: Nepali. Health goal: Weight loss. Activity level: Moderate.
 Daily calorie target: 1800 kcal. Diet: Vegetarian. Allergies: peanuts.
 Dislikes: bitter gourd. Portion preference: smaller than average.
 Frequently eaten: dal bhat, roti, saag, dahi, mixed vegetable curry.
 Recently eaten: aloo gobi, panipuri"
```

This profile embedding captures the user's entire dietary identity in vector space.
When we compare a food's embedding against this profile embedding, vegetarian foods
will score higher for a vegetarian user.

### 5.5 Step 4: Change Detection (SHA Comparison)

```ruby
# app/services/embeddings/upsert_service.rb
def upsert(record:, kind:)
  content = TextBuilder.for(record, kind: kind)
  embedding_record = Embedding.find_or_initialize_for(record: record, kind: kind)

  # SKIP if content hasn't changed
  return embedding_record unless embedding_record.new_record? || embedding_record.content_changed?(content)

  # Only call OpenAI if content actually changed
  embedding_vector = @openai_client.embed(content)
  # ... save
end
```

The SHA is computed from the content + model + dimensions:

```ruby
# app/models/embedding.rb
def compute_sha(text)
  Digest::SHA256.hexdigest("#{text}:#{DEFAULT_MODEL}:#{DEFAULT_DIMENSIONS}")
end
```

**Why include model and dimensions in the SHA?** If we switch embedding models (e.g., from
3-small to 3-large), all embeddings need to be regenerated even if the content hasn't
changed, because different models produce different vectors for the same text.

### 5.6 Step 5: OpenAI API Call

```ruby
# app/services/embeddings/openai_client.rb
module Embeddings
  class OpenaiClient
    MODEL = "text-embedding-3-small".freeze
    DIMENSIONS = 1536

    def embed(text)
      response = @client.embeddings(
        parameters: {
          model: MODEL,
          input: text,
          dimensions: DIMENSIONS
        }
      )
      response.dig("data", 0, "embedding")  # Returns [Float] of length 1536
    end

    def embed_batch(texts)
      # Sends multiple texts in ONE API call — more efficient
      response = @client.embeddings(
        parameters: { model: MODEL, input: texts, dimensions: DIMENSIONS }
      )
      response["data"].sort_by { |d| d["index"] }.map { |d| d["embedding"] }
    end
  end
end
```

**Why `embed_batch`?** The OpenAI embeddings API accepts arrays of text. Instead of
49 separate API calls for 49 foods (49 × 200ms = 10 seconds), we send them all in
one call (200ms total). The `upsert_batch` method in UpsertService uses this for
bulk operations like backfilling.

**API response structure:**

```json
{
  "data": [
    {
      "object": "embedding",
      "index": 0,
      "embedding": [0.023, -0.015, 0.042, ..., -0.031]
    }
  ],
  "model": "text-embedding-3-small",
  "usage": { "prompt_tokens": 47, "total_tokens": 47 }
}
```

### 5.7 Step 6: Storage with Metadata

```ruby
# app/services/embeddings/upsert_service.rb
def build_metadata(record, kind)
  case kind
  when "food_catalog"
    { name: record.name, is_nepali: record.is_nepali?, calories: record.calories_per_serving }
  when "user_food_stat"
    { user_id: record.user_id, normalized_name: record.normalized_name,
      times_eaten: record.times_eaten, health_score: record.health_score }
  when "user_profile"
    { user_id: record.id, health_goal: record.health_goal,
      allergies: record.allergies, dislikes: record.dislikes }
  end
end
```

Metadata is stored as JSONB and enables filtering without JOINs. For example,
`user_food_stat` embeddings include `user_id` so we can scope searches to a specific user:

```ruby
scope :for_user, ->(user_id) { where("metadata->>'user_id' = ?", user_id.to_s) }
```

### 5.8 Special Case: User Profile Refresh

```ruby
# app/models/user.rb
after_commit :refresh_profile_embedding_on_food_changes, on: :update

def refresh_profile_embedding_on_food_changes
  return unless meals_updated_recently?
  RefreshUserProfileEmbeddingJob.perform_later(user_id: id)
end

def meals_updated_recently?
  meals.where("created_at > ?", 1.hour.ago).exists?
end
```

User profile embeddings include "Frequently eaten" and "Recently eaten" foods.
When a user logs a new meal, their profile text changes, so we re-embed their profile.
But we don't do this on every meal — only if they've logged food in the last hour
(debouncing to avoid excessive API calls).

---

## 6. HNSW Indexes: Making Search Fast

### 6.1 The Problem: Brute Force is Slow

Without an index, finding the 5 nearest vectors to a query requires computing the
distance to EVERY stored vector:

```sql
-- O(n) scan — compares against every row
SELECT *, embedding <=> '[0.031, 0.019, ...]' AS distance
FROM embeddings
WHERE kind = 'food_catalog'
ORDER BY distance
LIMIT 5;
```

| Rows | Time (brute force) | Time (HNSW) |
|------|-------------------|-------------|
| 49 | 0.5ms | 0.3ms |
| 10,000 | 50ms | 2ms |
| 100,000 | 500ms | 5ms |
| 1,000,000 | 5,000ms | 8ms |

At 49 rows, brute force is fine. But as we add user food stats, the table grows.
HNSW ensures searches stay fast at any scale.

### 6.2 How HNSW Works (Simplified)

HNSW stands for **Hierarchical Navigable Small World**. It builds a multi-layered graph:

```
Layer 3 (very sparse):   A ─────────────── M
                          │                 │
Layer 2 (sparse):         A ──── F ──── M ──── T
                          │      │      │      │
Layer 1 (medium):         A ── C ── F ── I ── M ── P ── T
                          │    │    │    │    │    │    │
Layer 0 (all nodes):      A-B-C-D-E-F-G-H-I-J-K-L-M-N-O-P-Q-R-S-T
```

**Search algorithm:**
1. Start at the top layer (fewest nodes, biggest jumps)
2. Greedily move to the neighbor closest to the query vector
3. When you can't get closer, drop to the next layer
4. Repeat until you reach Layer 0
5. At Layer 0, explore the local neighborhood thoroughly

This is like navigating a city: first take the highway (Layer 3), then the main road
(Layer 2), then side streets (Layer 1), then walk to the exact address (Layer 0).

**Result: O(log n) search time** instead of O(n).

### 6.3 Our HNSW Index Configuration

```ruby
# db/migrate/20260208050830_add_hnsw_indexes_to_embeddings.rb
class AddHnswIndexesToEmbeddings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!  # Required for CREATE INDEX CONCURRENTLY

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

**Key decisions explained:**

**`disable_ddl_transaction!`** — Normal Rails migrations wrap everything in a transaction.
But `CREATE INDEX CONCURRENTLY` cannot run inside a transaction (Postgres restriction).
`disable_ddl_transaction!` tells Rails not to wrap this migration in a transaction.

**`CONCURRENTLY`** — Without this, `CREATE INDEX` locks the entire table for writes during
index creation. With `CONCURRENTLY`, existing reads and writes continue normally.
Essential for production deployments.

**`IF NOT EXISTS`** — Makes the migration idempotent. If it fails partway through and
you re-run it, it won't error on already-created indexes.

**`vector_cosine_ops`** — Tells pgvector to build the HNSW graph optimized for cosine
distance queries. This matches our search query's `distance: "cosine"`.

**Partial indexes (`WHERE kind = '...'`)** — We create three separate indexes instead
of one large index. Benefits:
- Each index is smaller (faster to search, fits in memory)
- Food catalog searches don't scan user profile vectors
- Index builds are faster (less data)
- Can be rebuilt independently

### 6.4 HNSW Tuning Parameters

HNSW has two build-time parameters (using defaults currently):

| Parameter | Default | Description | Trade-off |
|-----------|---------|-------------|-----------|
| `m` | 16 | Max connections per node per layer | Higher = better recall, more memory |
| `ef_construction` | 64 | Search width during build | Higher = better index quality, slower build |

And one query-time parameter:

| Parameter | Default | Description | Trade-off |
|-----------|---------|-------------|-----------|
| `hnsw.ef_search` | 40 | Search width during query | Higher = better recall, slower query |

For future tuning (if catalog grows to 100k+):

```sql
-- Better recall for large datasets
CREATE INDEX idx_embeddings_food_catalog_hnsw
ON embeddings USING hnsw (embedding vector_cosine_ops)
WITH (m = 24, ef_construction = 100)
WHERE kind = 'food_catalog';

-- At query time
SET hnsw.ef_search = 100;
```

---

## 7. Semantic Search: Finding Relevant Foods

### 7.1 SemanticFoodSearch Service

This is the main search orchestrator. It combines embedding-based retrieval with
business logic (filtering, reranking).

```ruby
# app/services/semantic_food_search.rb
class SemanticFoodSearch
  Result = Struct.new(:record, :similarity, :source, :metadata, keyword_init: true)

  QUERY_WEIGHT = 0.55      # Direct query relevance
  PROFILE_WEIGHT = 0.30    # User preference alignment
  FREQUENCY_WEIGHT = 0.15  # Personal eating history
end
```

### 7.2 Step-by-Step Search Process

**Step 1: Query Normalization**

The raw user query is enriched with context to steer the embedding:

```ruby
def normalize_query(query)
  parts = [query]

  # Steer toward Nepali foods for Nepali speakers
  parts << "(Nepali food preference)" if @user.language == "ne"

  # Steer toward health-goal-appropriate foods
  case @user.health_goal
  when "diabetic_friendly" then parts << "low glycemic index, diabetic-friendly"
  when "weight_loss"       then parts << "low calorie, light"
  when "muscle_gain"       then parts << "high protein"
  end

  parts.join(". ")
end
```

**Example transformations:**

```
Input:  "momo"
User:   language=ne, health_goal=weight_loss
Output: "momo. (Nepali food preference). low calorie, light"

Input:  "breakfast ideas"
User:   language=en, health_goal=muscle_gain
Output: "breakfast ideas. high protein"
```

**Why do this?** The embedding model captures the full context. By appending
"low calorie, light", the resulting vector will be closer to low-calorie foods
in the embedding space. Without normalization, "momo" returns all momos equally;
with normalization, steamed momos rank higher than fried momos for weight-loss users.

**Step 2: Embed the Query**

```ruby
query_embedding = @openai_client.embed(normalized_query)
# Returns [Float] of length 1536
```

This is the same OpenAI model that embedded our stored foods. Both vectors exist
in the same 1536-dimensional space, so distances between them are meaningful.

**Step 3: Dual-Source Vector Search**

We search two pools of embeddings simultaneously:

```ruby
# Pool 1: User's personal food history
def search_personal_foods(query_embedding, limit:)
  Embedding
    .for_kind("user_food_stat")
    .for_user(@user.id)  # Only THIS user's foods
    .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
    .limit(limit)
end

# Pool 2: Global food catalog
def search_catalog(query_embedding, limit:)
  Embedding
    .for_kind("food_catalog")  # All 49 curated foods
    .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
    .limit(limit)
end
```

The generated SQL (for catalog search) looks like:

```sql
SELECT "embeddings".*,
       "embeddings"."embedding" <=> $1 AS neighbor_distance
FROM "embeddings"
WHERE "embeddings"."kind" = 'food_catalog'
ORDER BY "embeddings"."embedding" <=> $1
LIMIT 10

-- $1 = the 1536-dim query vector
-- <=> = cosine distance operator
-- PostgreSQL query planner uses idx_embeddings_food_catalog_hnsw (HNSW index scan)
```

**Why search both pools?** Personal foods give personalized results ("you usually eat
dal bhat for dinner"), while the catalog provides variety ("here are foods you haven't
tried that match your query").

**Why `limit: limit * 2`?** We fetch 2× the requested results from each pool because
hard filters (next step) might remove some. If user asks for 5 results and we only
fetch 5, filtering might leave us with 3.

**Step 4: Hard Filters (Safety)**

```ruby
def apply_hard_filters(results)
  allergies = @user.allergies.map(&:downcase)  # e.g., ["peanuts", "shellfish"]
  dislikes = @user.dislikes.map(&:downcase)    # e.g., ["bitter gourd"]

  results.reject do |result|
    food_name = extract_food_name(result).downcase
    # Remove if ANY allergy or dislike matches any name variant
    allergies.any? { |a| food_name.include?(a) } ||
      dislikes.any? { |d| food_name.include?(d) }
  end
end
```

This is a hard safety filter. Even if "Peanut Chutney" is the most semantically similar
result, it MUST be removed if the user has a peanut allergy. We check against all name
variants (English, Nepali, romanized) to catch matches in any language.

**Step 5: Multi-Signal Reranking**

This is where the magic happens. We combine three signals:

```ruby
def rerank_results(results, query_embedding, user_profile_embedding)
  max_frequency = [results.map { |r| r.metadata[:times_eaten] || 0 }.max || 1, 1].max

  results.map do |result|
    query_score     = result.similarity || 0.0
    profile_score   = calculate_profile_similarity(result, user_profile_embedding)
    frequency_score = (result.metadata[:times_eaten] || 0).to_f / max_frequency

    final_score = (0.55 * query_score) +
                  (0.30 * profile_score) +
                  (0.15 * frequency_score)

    result.similarity = final_score.nan? ? 0.0 : final_score
    result
  end.sort_by { |r| -(r.similarity || 0.0) }
end
```

**Signal 1: Query Similarity (55% weight)**

How close is the food to what the user asked for? This comes directly from pgvector's
cosine distance: `1 - neighbor_distance`.

```
User: "momo"
  Chicken Momo:  0.52 (high — directly relevant)
  Thukpa:        0.38 (medium — related Tibetan food)
  Jalebi:        0.25 (low — not relevant)
```

**Signal 2: Profile Similarity (30% weight)**

How well does this food align with the user's overall dietary profile? Calculated by
comparing the food's embedding with the user's profile embedding:

```ruby
def calculate_profile_similarity(result, user_profile_embedding)
  return 0.5 unless user_profile_embedding  # Neutral if no profile

  record_embedding = Embedding.find_by(
    record_type: result.record.class.name,
    record_id: result.record.id
  )&.embedding

  return 0.5 unless record_embedding

  1 - cosine_distance(user_profile_embedding, record_embedding)
end
```

A vegetarian user's profile embedding (which includes "Diet: Vegetarian") will be
geometrically closer to Veg Momo's embedding (tagged "vegetarian") than to Buff Momo's
embedding. So Veg Momo gets a higher profile score for vegetarian users.

```
Vegetarian user profile:
  Veg Momo:     profile_score = 0.35 (high alignment)
  Chicken Momo: profile_score = 0.22 (lower alignment)
```

**Signal 3: Frequency Score (15% weight)**

Has the user eaten this food before? How often? This gives a slight boost to familiar foods.

```ruby
frequency_score = times_eaten / max_frequency
```

If the most-eaten food was eaten 12 times:
```
Dal Bhat (12x):  12/12 = 1.0  (full boost)
Roti (6x):        6/12 = 0.5  (half boost)
New food (0x):     0/12 = 0.0  (no boost)
```

**Final Score Calculation:**

```
Veg Momo for a vegetarian weight-loss user searching "momo":
  final = 0.55 × 0.52 (query)  +  0.30 × 0.35 (profile)  +  0.15 × 0.0 (frequency)
        = 0.286                 +  0.105                    +  0.0
        = 0.391  (39.1% similarity)
```

### 7.3 The Cosine Distance Implementation

For profile similarity, we compute cosine distance in Ruby (not in Postgres) because
we're comparing arbitrary embedding pairs, not doing nearest-neighbor search:

```ruby
def cosine_distance(vec1, vec2)
  return 1.0 unless vec1 && vec2 && vec1.length == vec2.length

  dot_product = vec1.zip(vec2).sum { |a, b| a * b }
  magnitude1 = Math.sqrt(vec1.sum { |x| x * x })
  magnitude2 = Math.sqrt(vec2.sum { |x| x * x })

  return 1.0 if magnitude1.zero? || magnitude2.zero?

  result = 1 - (dot_product / (magnitude1 * magnitude2))
  result.nan? ? 1.0 : result.clamp(0.0, 2.0)
end
```

The `.clamp(0.0, 2.0)` handles floating-point edge cases where rounding errors
might produce values slightly outside the theoretical [0, 2] range.

### 7.4 Similar Foods Feature

SemanticFoodSearch also supports "find foods similar to X" without a text query:

```ruby
def similar_foods(food_name:, limit: 5)
  # Find the food's existing embedding
  embedding = Embedding.find_by(record_type: "FoodCatalog", kind: "food_catalog")
                       &.then { |e| e if e.content.downcase.include?(food_name.downcase) }

  # Use that food's vector to find nearest neighbors
  Embedding.for_kind(embedding.kind)
           .nearest_neighbors(:embedding, embedding.embedding, distance: "cosine")
           .limit(limit)
end
```

This is useful for "You ate Chicken Momo → you might also like: Buff Momo, Jhol Momo,
Thukpa, Veg Momo" — food-to-food similarity without any text query.

---

## 8. RAG Context Building

### 8.1 What is RAG?

**Retrieval-Augmented Generation** is a technique where we:
1. **Retrieve** relevant data from our database (via semantic search)
2. **Augment** the LLM prompt with this data
3. **Generate** a response grounded in real facts

Without RAG, the LLM might hallucinate:
```
User: "How many calories in dal bhat?"
LLM (no RAG): "Dal bhat has approximately 300-400 calories."  ← made up!
LLM (with RAG): "Dal bhat has 450 calories per plate."        ← from our catalog
```

### 8.2 RagContextBuilder: Assembling Context

```ruby
# app/services/rag_context_builder.rb
class RagContextBuilder
  def build_for_recommendation(query:, limit: 5)
    # 1. Run semantic search
    search = SemanticFoodSearch.new(user: @user)
    results = search.search(query: query, limit: limit)

    # 2. Build structured context from 4 sections
    build(query: query, semantic_results: results)
  end

  def build(query: nil, semantic_results: [], include_eating_patterns: true)
    sections = []
    sections << build_user_constraints_section          # Always: allergies, diet, goals
    sections << build_eating_patterns_section if include_eating_patterns  # 14-day stats
    sections << build_semantic_matches_section(semantic_results) if semantic_results.any?
    sections << build_query_context_section(query) if query.present?
    sections.compact.join("\n\n")
  end
end
```

### 8.3 The Four Context Sections

**Section 1: User Constraints (Always Included)**

Critical safety information the LLM must respect:

```markdown
## User Constraints (Must Follow)
- Language: Nepali
- Health Goal: Weight loss (prefer lower calorie options)
- Daily Calorie Target: 1800 kcal
- Diet: Vegetarian (NO meat, fish, eggs)
- ALLERGIES (NEVER recommend): peanuts, shellfish
- Dislikes (avoid if possible): bitter gourd
- Intermittent Fasting: OUTSIDE eating window (fasting)
- Portion size: 80% of standard (adjust recommendations accordingly)
```

The "NEVER recommend" and "NO meat, fish, eggs" language is deliberately strong
to prevent the LLM from violating dietary constraints.

**Section 2: Eating Patterns (Last 14 Days)**

Real data from the user's meal history:

```markdown
## User Eating Patterns (Last 14 Days)
- Total meals logged: 42
- Avg daily calories: 1650 kcal
- Avg protein: 65g, Carbs: 180g, Fat: 55g
- Top foods: Dal Bhat (12x), Roti (8x), Saag (6x), Dahi (5x)
- Healthy choices: Saag, Mixed Vegetable Curry, Dahi
- Could improve: Samosa, Jalebi
```

This lets the LLM say things like "You've been eating well this week, averaging
1650 kcal against your 1800 target" or "I notice you've had samosa 3 times this
week — want to try a lighter snack?"

**Section 3: Semantic Matches (From Vector Search)**

The top foods returned by SemanticFoodSearch, with real nutritional data:

```markdown
## Relevant Food Matches
1. Saag (80 kcal, 4.0g protein) [nepali, vegetarian, healthy] - Food catalog
2. Chiura (180 kcal, 3.0g protein) [nepali, snack, quick] - Food catalog
3. Gundruk (60 kcal, 3.0g protein) [nepali, fermented, probiotic] - Food catalog
4. Dal Bhat (450 kcal avg, eaten 12x) - User's history
5. Mixed Vegetable Curry (140 kcal, 5.0g protein) - Food catalog
```

These are **real facts** from our database. The LLM can reference these exact
calorie counts and protein values instead of guessing.

**Section 4: Query Intent Detection**

Simple regex-based intent classification for Nepali and English:

```ruby
def detect_intent(query)
  query_lower = query.downcase
  if query_lower.match?(/breakfast|morning|बिहान/)     then "Breakfast recommendation"
  elsif query_lower.match?(/lunch|दिउँसो|khana/)       then "Lunch recommendation"
  elsif query_lower.match?(/dinner|evening|साँझ|beluka/) then "Dinner recommendation"
  elsif query_lower.match?(/protein|muscle|प्रोटिन/)    then "High-protein food"
  elsif query_lower.match?(/quick|fast|छिटो/)           then "Quick meal"
  end
end
```

```markdown
## User Query Context
Query: "something light for dinner"
Detected intent: Dinner recommendation
```

---

## 9. LLM Integration: Grounding AI Responses

### 9.1 Three Integration Points

RAG context is injected into three LLM services, each for a different use case:

**1. ImageAnalysisService** — User sends a food photo

```ruby
# app/services/image_analysis_service.rb
def build_rag_context
  return @user.ai_context_summary unless semantic_search_enabled?

  builder = RagContextBuilder.new(user: @user)
  query = @caption.presence || "food meal"

  builder.build(
    query: query,
    semantic_results: fetch_semantic_results(query),
    include_eating_patterns: true
  )
rescue StandardError => e
  Rails.logger.warn("[ImageAnalysis] RAG context failed: #{e.message}")
  @user.ai_context_summary  # Graceful fallback
end
```

When analyzing a food photo, the RAG context helps the LLM:
- Know the user's allergies (important for safety)
- Use catalog data for accurate calorie estimates
- Know the user is Nepali (likely Nepali food in photo)

**2. TextClarificationService** — User types ambiguous food name

```ruby
# app/services/text_clarification_service.rb
def build_rag_context
  builder = RagContextBuilder.new(user: @user)
  query = [@text, @possible_foods].flatten.compact.join(" ")

  builder.build(
    query: query,
    semantic_results: fetch_semantic_results(query),
    include_eating_patterns: true
  )
end
```

When a user types "khasi ko masu", semantic search matches it to "Mutton Curry"
in our catalog. The LLM gets the exact calorie count (380 kcal) and nutritional data.

**3. AiChatService** — General conversation about food

```ruby
# app/services/ai_chat_service.rb
def build_rag_context
  builder = RagContextBuilder.new(user: @user)
  builder.build_for_recommendation(query: @message, limit: 5)
end
```

### 9.2 Graceful Degradation

Every integration point has fallback handling:

```ruby
def semantic_search_enabled?
  Embedding.exists? && @user.present?
end

rescue StandardError => e
  Rails.logger.warn("[Service] RAG context failed: #{e.message}")
  @user.ai_context_summary  # Falls back to basic user context
end
```

If embeddings haven't been generated yet, or the OpenAI API is down, the system
gracefully degrades to basic user context (allergies, health goal) without semantic
search results. The LLM still gets some personalization, just less.

### 9.3 Convenience Methods on User

```ruby
# app/models/user.rb
def search_foods(query, limit: 10)
  SemanticFoodSearch.new(user: self).search(query: query, limit: limit)
end

def rag_context(query: nil)
  RagContextBuilder.new(user: self).build_for_recommendation(query: query)
end
```

These allow concise calls from anywhere: `user.search_foods("momo")`.

---

## 10. Complete Data Flow Walkthrough

### Scenario: User sends "I want momo" via Telegram

```
Step 1: Telegram → AiChatService
        @message = "I want momo", @user = User#1

Step 2: AiChatService calls build_rag_context
        → RagContextBuilder.new(user: User#1).build_for_recommendation(query: "I want momo")

Step 3: RagContextBuilder creates SemanticFoodSearch
        → SemanticFoodSearch.new(user: User#1).search(query: "I want momo", limit: 5)

Step 4: SemanticFoodSearch normalizes query
        → "I want momo. (Nepali food preference)"
        (User#1's language is 'ne')

Step 5: Query is embedded via OpenAI API
        POST https://api.openai.com/v1/embeddings
        Body: { model: "text-embedding-3-small", input: "I want momo. (Nepali food preference)", dimensions: 1536 }
        Response: [0.045, -0.023, 0.067, ...]  (1536 floats)

Step 6: Search personal foods (user_food_stat embeddings)
        SQL: SELECT * FROM embeddings
             WHERE kind = 'user_food_stat'
             AND metadata->>'user_id' = '1'
             ORDER BY embedding <=> '[0.045, -0.023, ...]'
             LIMIT 10
        Index: idx_embeddings_user_food_stat_hnsw
        Result: (empty — user has no food stats yet)

Step 7: Search food catalog
        SQL: SELECT * FROM embeddings
             WHERE kind = 'food_catalog'
             ORDER BY embedding <=> '[0.045, -0.023, ...]'
             LIMIT 10
        Index: idx_embeddings_food_catalog_hnsw
        Results:
          Fried Momo:    distance=0.475 → similarity=0.525
          Veg Momo:      distance=0.482 → similarity=0.518
          Chicken Momo:  distance=0.486 → similarity=0.514
          Jhol Momo:     distance=0.490 → similarity=0.510
          Buff Momo:     distance=0.492 → similarity=0.508
          Thukpa:        distance=0.540 → similarity=0.460
          ... (more results)

Step 8: Hard filters
        User#1 allergies: []
        User#1 dislikes: []
        → No results removed

Step 9: Reranking (with user profile embedding)
        Load User#1's profile embedding from DB
        For each result, compute:
          final = 0.55 × query_score + 0.30 × profile_score + 0.15 × frequency_score

        Veg Momo:     0.55 × 0.518 + 0.30 × 0.299 + 0.15 × 0.0 = 0.374
        Fried Momo:   0.55 × 0.525 + 0.30 × 0.236 + 0.15 × 0.0 = 0.360
        Jhol Momo:    0.55 × 0.510 + 0.30 × 0.278 + 0.15 × 0.0 = 0.352
        Chicken Momo: 0.55 × 0.514 + 0.30 × 0.226 + 0.15 × 0.0 = 0.350
        Buff Momo:    0.55 × 0.508 + 0.30 × 0.220 + 0.15 × 0.0 = 0.345

        (Veg Momo ranks highest because User#1 is vegetarian —
         their profile embedding is closer to vegetarian foods)

Step 10: RagContextBuilder assembles context
         
         ## User Constraints (Must Follow)
         - Language: Nepali
         - Health Goal: Maintain weight
         - Daily Calorie Target: 2000 kcal
         - Diet: Vegetarian (NO meat, fish, eggs)

         ## User Eating Patterns (Last 14 Days)
         - Total meals logged: 3
         - Avg daily calories: 1100 kcal

         ## Relevant Food Matches
         1. Veg Momo (280 kcal, 8.0g protein) [nepali, vegetarian] - Food catalog
         2. Fried Momo (450 kcal, 16.0g protein) [nepali, fried] - Food catalog
         3. Jhol Momo (420 kcal, 18.0g protein) [nepali, spicy] - Food catalog
         4. Chicken Momo (350 kcal, 18.0g protein) [nepali, protein-rich] - Food catalog
         5. Buff Momo (380 kcal, 20.0g protein) [nepali, protein-rich] - Food catalog

         ## User Query Context
         Query: "I want momo"

Step 11: AiChatService builds LLM prompt
         System: "You are a friendly Nepali nutrition assistant..."
         + RAG context from Step 10
         User: "I want momo"

Step 12: OpenAI GPT-4 generates response
         "तपाईंको लागि भेज मोमो (280 kcal) राम्रो विकल्प हो! यो तपाईंको
          शाकाहारी डाइटमा मिल्छ र 8g प्रोटिन पनि पाउनुहुन्छ।"
         
         (Translation: "Veg Momo (280 kcal) is a good option for you! It fits
          your vegetarian diet and gives you 8g protein.")

Step 13: Response sent back to user via Telegram
```

**Note how the LLM's response:**
- Used the exact calorie count (280 kcal) from our catalog ← not hallucinated
- Recommended Veg Momo (not chicken/buff) because user is vegetarian ← from constraints
- Mentioned protein content (8g) from catalog data ← grounded in facts
- Responded in Nepali because the user's language preference is 'ne' ← personalized

---

## 11. File Reference Map

### Database Migrations

| File | Purpose |
|------|---------|
| `db/migrate/20260208050808_enable_pgvector_extension.rb` | Enables `vector` extension in Postgres |
| `db/migrate/20260208050820_create_embeddings.rb` | Creates the `embeddings` table with `vector(1536)` column |
| `db/migrate/20260208050830_add_hnsw_indexes_to_embeddings.rb` | Creates 3 partial HNSW indexes |
| `db/migrate/20260208051046_add_language_fields_to_food_catalogs.rb` | Adds `name_nepali`, `name_romanized`, `aliases` |

### Models

| File | Purpose |
|------|---------|
| `app/models/embedding.rb` | Embedding record: `has_neighbors`, scopes, SHA, similarity search |
| `app/models/concerns/embeddable.rb` | Concern: `after_commit` hook, trigger attribute detection |
| `app/models/food_catalog.rb` | Food record: `include Embeddable`, defines trigger attributes |
| `app/models/user_food_stat.rb` | Eating history: `include Embeddable`, defines trigger attributes |
| `app/models/user.rb` | User profile: `include Embeddable`, `search_foods`, `rag_context` |

### Embedding Services

| File | Purpose |
|------|---------|
| `app/services/embeddings/text_builder.rb` | Converts records → rich semantic text for embedding |
| `app/services/embeddings/openai_client.rb` | Calls OpenAI API for single/batch embeddings |
| `app/services/embeddings/upsert_service.rb` | Orchestrates: text build → change detect → API call → save |

### Background Jobs

| File | Purpose |
|------|---------|
| `app/jobs/upsert_embedding_job.rb` | Async single-record embedding update |
| `app/jobs/backfill_embeddings_job.rb` | Batch backfill by kind (food_catalog, user_food_stat, user_profile) |
| `app/jobs/refresh_user_profile_embedding_job.rb` | Re-embeds user profile after meal changes |

### Search & RAG

| File | Purpose |
|------|---------|
| `app/services/semantic_food_search.rb` | Query → embed → HNSW search → filter → rerank → results |
| `app/services/rag_context_builder.rb` | Results + user data → structured LLM context |

### LLM Integration

| File | Purpose |
|------|---------|
| `app/services/image_analysis_service.rb` | Photo analysis with RAG context |
| `app/services/text_clarification_service.rb` | Ambiguous text parsing with RAG context |
| `app/services/ai_chat_service.rb` | General chat with RAG context |

### Operations

| File | Purpose |
|------|---------|
| `lib/tasks/embeddings.rake` | Rake tasks: `backfill_all`, `test_search`, `show_rag_context` |
| `db/seeds/food_catalogs.rb` | 49 Nepali/South Asian foods with multilingual data |

---

## 12. Operations and Maintenance

### Backfilling Embeddings

```bash
# Backfill everything
bin/rails embeddings:backfill_all

# Backfill specific types
bin/rails embeddings:backfill_food_catalogs
bin/rails embeddings:backfill_user_food_stats
bin/rails embeddings:backfill_user_profiles
```

### Testing Search Quality

```bash
# Test semantic search for a user
bin/rails "embeddings:test_search[1,momo]"
bin/rails "embeddings:test_search[1,something light for dinner]"
bin/rails "embeddings:test_search[1,high protein breakfast]"

# Show full RAG context
bin/rails "embeddings:show_rag_context[1,momo]"
```

### Monitoring

```ruby
# In Rails console:

# Embedding counts by kind
Embedding.group(:kind).count
# => {"food_catalog"=>49, "user_food_stat"=>0, "user_profile"=>1}

# Check HNSW index usage
ActiveRecord::Base.connection.execute(<<-SQL).to_a
  SELECT indexrelname, idx_scan, idx_tup_read
  FROM pg_stat_user_indexes
  WHERE indexrelname LIKE '%hnsw%'
SQL

# Find stale embeddings
FoodCatalog.find_each do |food|
  content = Embeddings::TextBuilder.for(food, kind: "food_catalog")
  emb = food.embedding_record
  if emb && emb.content_changed?(content)
    puts "Stale: #{food.name}"
  end
end
```

### Re-indexing

```sql
-- Drop and rebuild (if index corrupted or params need changing)
DROP INDEX CONCURRENTLY idx_embeddings_food_catalog_hnsw;

CREATE INDEX CONCURRENTLY idx_embeddings_food_catalog_hnsw
ON embeddings USING hnsw (embedding vector_cosine_ops)
WHERE kind = 'food_catalog';
```

---

## 13. Cost Analysis

### OpenAI Embedding API Costs

| Item | Tokens | Cost |
|------|--------|------|
| 1 food catalog entry (~60 tokens) | 60 | $0.0000012 |
| 49 food catalogs (batch) | ~3,000 | $0.00006 |
| 1 user profile (~80 tokens) | 80 | $0.0000016 |
| 1 search query (~30 tokens) | 30 | $0.0000006 |
| 100 searches/day | ~3,000 | $0.00006 |
| **Monthly estimate (100 searches/day)** | **~90,000** | **$0.0018** |

**Bottom line: Embedding costs are negligible.** Even at 1000 searches/day, the monthly
embedding cost is about $0.02. The LLM generation calls (GPT-4) cost orders of magnitude more.

### Storage Costs

```
Per embedding:  6 KB (1536 × 4 bytes vector) + ~500 bytes (metadata, content)
Per 1000 embeddings: ~6.5 MB
Per 100,000 embeddings: ~650 MB
```

Well within standard PostgreSQL capacity.

---

## 14. Performance and Scaling

### Current Scale

| Metric | Value |
|--------|-------|
| Food catalog embeddings | 49 |
| User profile embeddings | 1 |
| User food stat embeddings | 0 |
| Search latency (end-to-end) | ~300ms (dominated by OpenAI API call) |
| HNSW search time | < 1ms |
| Index size | ~300 KB |

### Bottleneck Analysis

```
Search latency breakdown:
  OpenAI embed query:     200-500ms  ← THE BOTTLENECK
  HNSW vector search:     < 1ms
  Hard filters + rerank:  < 5ms
  RagContextBuilder:      < 10ms
  Total:                  ~300ms
```

The OpenAI API call is the bottleneck. Strategies to reduce this:
1. **Cache query embeddings** — Same queries (e.g., "momo") produce same vectors
2. **Pre-compute common queries** — "breakfast", "dinner", "snack" etc.
3. **Use a local model** — Replace OpenAI with a local embedding model (removes network latency)

### Scaling Roadmap

| Scale | Foods | Users | Strategy |
|-------|-------|-------|----------|
| Current | 49 | 1 | Works fine as-is |
| Medium | 1,000 | 100 | Still fine, consider query caching |
| Large | 10,000 | 1,000 | Tune HNSW params (m=24, ef=100) |
| Very Large | 100,000+ | 10,000+ | Consider dedicated vector DB |

### HNSW Index Tuning for Scale

```sql
-- For 100k+ embeddings
CREATE INDEX idx_embeddings_food_catalog_hnsw
ON embeddings USING hnsw (embedding vector_cosine_ops)
WITH (m = 24, ef_construction = 100)
WHERE kind = 'food_catalog';

-- At query time for better recall
SET hnsw.ef_search = 100;  -- Default is 40
```

---

*This document reflects the FoodBot RAG system as of February 2026.
For operational details, see `docs/rag_architecture.md`.*
