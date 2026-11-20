---
name: learnix-db-rules
description: Database rules for the Learnix app on AlloyDB (PostgreSQL). Use whenever creating tables, writing SQL, loading CSVs, generating embeddings or editing any .sql file in this project.
---

# Learnix database rules

## Naming
1. Table and column names use snake_case and are plural for tables (students, concepts, lab_runs).
2. Every table has a primary key named `id`. Foreign keys are named `<table_singular>_id` (student_id, concept_id).
3. Every table has `created_at TIMESTAMPTZ DEFAULT now()`.

## Safety
4. Never write DROP TABLE, DROP DATABASE or TRUNCATE. To change a table, use ALTER TABLE.
5. Never store passwords, phone numbers or full addresses of students. Students are identified by first name + centre only.
6. Always use parameterised queries in application code. Never build SQL by joining strings with user input.

## Core tables (create in this order)
- centres(id, name, city, country)
- students(id, first_name, age, grade, language, centre_id)
- concepts(id, title, level, category, summary, embedding VECTOR(768))
- experiments(id, title, concept_id, components, goal, starter_code, solution_code)
- quiz_attempts(id, student_id, concept_id, score, max_score, attempted_at)
- lab_runs(id, student_id, experiment_id, success, error_type, ai_hint, run_at)
- feedback(id, student_id, from_role, text, sentiment, topic, issue)
- visual_lessons(id, student_id, source_type, concept_id, visual_type, content_json JSONB)  -- source_type: page | topic
- course_days(id, day_number, title, concept_id, experiment_id, visual_type)
- student_day_progress(id, student_id, day_number, status, quiz_score, completed_at)

## AI in SQL
7. Create concept embeddings inside the database (AlloyDB AI embedding function with a Google text-embedding model). Do not call an external vector database.
8. Use a ScaNN index on concepts.embedding for "find similar concept" search.
9. Fill feedback.sentiment, feedback.topic and feedback.issue with AI.EXTRACT() from feedback.text. Allowed sentiment values: positive, neutral, negative.

## Checks before finishing
- Run `SELECT count(*)` on every table after loading data and report the counts.
- Confirm every foreign key value exists in its parent table.
