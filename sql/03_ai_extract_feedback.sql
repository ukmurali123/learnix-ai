ALTER DATABASE learnix SET google_ml_integration.enable_preview_ai_functions = on;
SET google_ml_integration.enable_preview_ai_functions = on;

-- Register global Gemini 3.8 Flash endpoint for AlloyDB AI functions
DO $$
BEGIN
  IF NOT google_ml.model_exists('gemini-flash-global') THEN
    CALL google_ml.create_model(
      model_id => 'gemini-flash-global',
      model_request_url => 'https://aiplatform.googleapis.com/v1/projects/learnix-ai-515213/locations/global/publishers/google/models/gemini-3.8-flash:generateContent',
      model_provider => 'google',
      model_type => 'llm',
      model_qualified_name => 'gemini-3.8-flash',
      model_auth_type => 'alloydb_service_agent_iam'
    );
  END IF;
END $$;

ALTER DATABASE learnix SET google_ml_integration.default_llm_model = 'gemini-flash-global';
SET google_ml_integration.default_llm_model = 'gemini-flash-global';

-- Populate feedback.sentiment (positive | neutral | negative), topic, and issue via AI.EXTRACT()
WITH unique_feedback AS (
  SELECT array_agg(text ORDER BY text) AS texts
  FROM (SELECT DISTINCT text FROM feedback) d
),
batch_extracted AS (
  SELECT unnest(texts) AS text,
         (unnest(ai.extract(
           texts,
           '{"sentiment": "one of: positive, neutral, negative", "topic": "short topic name", "issue": "main issue or none"}',
           15,
           'gemini-flash-global'
         )))::jsonb AS ext
  FROM unique_feedback
)
UPDATE feedback f
SET sentiment = LOWER(e.ext->>'sentiment'),
    topic = e.ext->>'topic',
    issue = e.ext->>'issue'
FROM batch_extracted e
WHERE f.text = e.text;

SELECT id, from_role, text, sentiment, topic, issue
FROM feedback
ORDER BY id
LIMIT 5;
