CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS centres (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS students (
    id SERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    age INTEGER NOT NULL,
    grade INTEGER NOT NULL,
    language TEXT NOT NULL,
    centre_id INTEGER NOT NULL REFERENCES centres(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS concepts (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    level TEXT NOT NULL,
    category TEXT NOT NULL,
    summary TEXT NOT NULL,
    embedding VECTOR(768),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS experiments (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    concept_id INTEGER NOT NULL REFERENCES concepts(id),
    components TEXT NOT NULL,
    goal TEXT NOT NULL,
    starter_code TEXT NOT NULL,
    solution_code TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quiz_attempts (
    id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(id),
    concept_id INTEGER NOT NULL REFERENCES concepts(id),
    score INTEGER NOT NULL,
    max_score INTEGER NOT NULL,
    attempted_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lab_runs (
    id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(id),
    experiment_id INTEGER NOT NULL REFERENCES experiments(id),
    success BOOLEAN NOT NULL,
    error_type TEXT NOT NULL,
    ai_hint TEXT,
    run_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS feedback (
    id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(id),
    from_role TEXT NOT NULL,
    text TEXT NOT NULL,
    sentiment TEXT,
    topic TEXT,
    issue TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS visual_lessons (
    id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(id),
    source_type TEXT NOT NULL,
    concept_id INTEGER REFERENCES concepts(id),
    visual_type TEXT NOT NULL,
    content_json JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
