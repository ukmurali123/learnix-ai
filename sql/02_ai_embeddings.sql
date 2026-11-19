CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS alloydb_scann;
CREATE EXTENSION IF NOT EXISTS google_ml_integration;

-- Generate 768-d embeddings for concepts (title + summary) inside AlloyDB
UPDATE concepts
SET embedding = ai.embedding('text-embedding-005', title || ': ' || summary)::vector;

-- Create ScaNN cosine similarity index
CREATE INDEX IF NOT EXISTS concepts_embedding_scann_idx
ON concepts USING scann (embedding cosine)
WITH (num_leaves = 1);

-- Test query: 3 concepts most similar to "how does a robot measure distance"
WITH q AS (
  SELECT ai.embedding('text-embedding-005', 'how does a robot measure distance')::vector AS q_vec
)
SELECT c.id, c.title, c.level, c.category, c.summary,
       ROUND((1 - (c.embedding <=> q.q_vec))::numeric, 4) AS cosine_similarity
FROM concepts c, q
ORDER BY c.embedding <=> q.q_vec
LIMIT 3;
