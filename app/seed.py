import csv
import pathlib


def esc(v):
    if v is None or v == "":
        return "NULL"
    return "'" + str(v).replace("'", "''") + "'"


def generate_seed_sql(data_dir: pathlib.Path, out_path: pathlib.Path) -> str:
    out = []

    # 1. centres
    with open(data_dir / "centres.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    vals = [
        f"({int(r['id'])}, {esc(r['name'])}, {esc(r['city'])}, {esc(r['country'])})"
        for r in rows
    ]
    out.append(
        "INSERT INTO centres (id, name, city, country) VALUES\n"
        + ",\n".join(vals)
        + "\nON CONFLICT (id) DO NOTHING;"
    )

    # 2. students
    with open(data_dir / "students.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    vals = [
        f"({int(r['id'])}, {esc(r['first_name'])}, {int(r['age'])}, {int(r['grade'])}, {esc(r['language'])}, {int(r['centre_id'])})"
        for r in rows
    ]
    out.append(
        "INSERT INTO students (id, first_name, age, grade, language, centre_id) VALUES\n"
        + ",\n".join(vals)
        + "\nON CONFLICT (id) DO NOTHING;"
    )

    # 3. concepts
    with open(data_dir / "concepts.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    vals = [
        f"({int(r['id'])}, {esc(r['title'])}, {esc(r['level'])}, {esc(r['category'])}, {esc(r['summary'])})"
        for r in rows
    ]
    out.append(
        "INSERT INTO concepts (id, title, level, category, summary) VALUES\n"
        + ",\n".join(vals)
        + "\nON CONFLICT (id) DO NOTHING;"
    )

    # 4. experiments
    with open(data_dir / "experiments.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    vals = [
        f"({int(r['id'])}, {esc(r['title'])}, {int(r['concept_id'])}, {esc(r['components'])}, {esc(r['goal'])}, {esc(r['starter_code'])}, {esc(r['solution_code'])})"
        for r in rows
    ]
    out.append(
        "INSERT INTO experiments (id, title, concept_id, components, goal, starter_code, solution_code) VALUES\n"
        + ",\n".join(vals)
        + "\nON CONFLICT (id) DO NOTHING;"
    )

    # 5. quiz_attempts
    with open(data_dir / "quiz_attempts.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    vals = [
        f"({int(r['id'])}, {int(r['student_id'])}, {int(r['concept_id'])}, {int(r['score'])}, {int(r['max_score'])}, {esc(r['attempted_at'])})"
        for r in rows
    ]
    out.append(
        "INSERT INTO quiz_attempts (id, student_id, concept_id, score, max_score, attempted_at) VALUES\n"
        + ",\n".join(vals)
        + "\nON CONFLICT (id) DO NOTHING;"
    )

    # 6. lab_runs
    with open(data_dir / "lab_runs.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    vals = [
        f"({int(r['id'])}, {int(r['student_id'])}, {int(r['experiment_id'])}, {'TRUE' if r['success'].lower() == 'true' else 'FALSE'}, {esc(r['error_type'])}, {esc(r['ai_hint'])}, {esc(r['run_at'])})"
        for r in rows
    ]
    out.append(
        "INSERT INTO lab_runs (id, student_id, experiment_id, success, error_type, ai_hint, run_at) VALUES\n"
        + ",\n".join(vals)
        + "\nON CONFLICT (id) DO NOTHING;"
    )

    # 7. feedback
    with open(data_dir / "feedback.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    vals = [
        f"({int(r['id'])}, {int(r['student_id'])}, {esc(r['from_role'])}, {esc(r['text'])}, {esc(r['sentiment'])}, {esc(r['topic'])}, {esc(r['issue'])})"
        for r in rows
    ]
    out.append(
        "INSERT INTO feedback (id, student_id, from_role, text, sentiment, topic, issue) VALUES\n"
        + ",\n".join(vals)
        + "\nON CONFLICT (id) DO NOTHING;"
    )

    for t in [
        "centres",
        "students",
        "concepts",
        "experiments",
        "quiz_attempts",
        "lab_runs",
        "feedback",
    ]:
        out.append(
            f"SELECT setval(pg_get_serial_sequence('{t}', 'id'), COALESCE((SELECT MAX(id) FROM {t}), 1));"
        )

    sql_text = "\n\n".join(out)
    out_path.write_text(sql_text, encoding="utf-8")
    return sql_text


if __name__ == "__main__":
    base = pathlib.Path(__file__).resolve().parent.parent
    generate_seed_sql(base / "data", base / "sql" / "01b_seed_data.sql")
    print("Generated sql/01b_seed_data.sql")
