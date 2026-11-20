-- Learnix AI: Day-wise Interactive Learning Path
-- Follows learnix-db-rules (snake_case, plural tables, primary key id, foreign keys, created_at TIMESTAMPTZ)

CREATE TABLE IF NOT EXISTS course_days (
    id SERIAL PRIMARY KEY,
    day_number INTEGER NOT NULL UNIQUE,
    title TEXT NOT NULL,
    concept_id INTEGER NOT NULL REFERENCES concepts(id),
    experiment_id INTEGER REFERENCES experiments(id),
    visual_type TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS student_day_progress (
    id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(id),
    day_number INTEGER NOT NULL,
    status TEXT NOT NULL, -- 'locked', 'current', 'done'
    quiz_score INTEGER,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(student_id, day_number)
);

-- Seed 10 Learning Path Days
INSERT INTO course_days (day_number, title, concept_id, experiment_id, visual_type) VALUES
(1, 'What is an LED', 1, NULL, 'animated_steps'),
(2, 'Resistors', 2, NULL, 'simulation'),
(3, 'Ground and complete circuits', 10, NULL, 'labelled_diagram'),
(4, 'Digital output pins + loops', 3, 1, 'animated_steps'),
(5, 'Buttons and digital input', 5, NULL, 'animated_steps'),
(6, 'Buzzers + if-else', 6, 2, 'simulation'),
(7, 'Variables', 9, NULL, 'story_comic'),
(8, 'Ultrasonic distance sensor', 8, 3, 'simulation'),
(9, 'What is AI', 13, NULL, 'story_comic'),
(10, 'Image recognition basics', 14, NULL, 'comparison')
ON CONFLICT (day_number) DO UPDATE SET
    title = EXCLUDED.title,
    concept_id = EXCLUDED.concept_id,
    experiment_id = EXCLUDED.experiment_id,
    visual_type = EXCLUDED.visual_type;

-- Initialize Day 1 as 'current' for student 1 if no progress exists yet
INSERT INTO student_day_progress (student_id, day_number, status, quiz_score) VALUES
(1, 1, 'current', NULL)
ON CONFLICT (student_id, day_number) DO NOTHING;
