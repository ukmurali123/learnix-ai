from typing import Optional
from fastapi import APIRouter, HTTPException, Query

from app import db, gemini
from app.routes.coach import get_student_coach

router = APIRouter(prefix="/api/reports", tags=["reports"])


@router.get("/parent/{student_id}")
def get_parent_report(
    student_id: int,
    language: Optional[str] = Query(None, description="Optional language override"),
):
    student = db.fetch_one(
        """
        SELECT s.id, s.first_name, s.age, s.grade, s.language,
               s.centre_id, c.name AS centre_name, c.city, c.country
        FROM students s
        JOIN centres c ON c.id = s.centre_id
        WHERE s.id = %s
        """,
        (student_id,),
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    quiz_row = db.fetch_one(
        """
        SELECT COUNT(*) AS total_quizzes,
               COALESCE(ROUND(AVG((score::numeric / NULLIF(max_score, 0)) * 100), 1), 0) AS avg_quiz_pct
        FROM quiz_attempts
        WHERE student_id = %s
        """,
        (student_id,),
    ) or {"total_quizzes": 0, "avg_quiz_pct": 0}

    lab_row = db.fetch_one(
        """
        SELECT COUNT(*) AS total_lab_runs,
               COALESCE(SUM(CASE WHEN success = TRUE THEN 1 ELSE 0 END), 0) AS successful_lab_runs
        FROM lab_runs
        WHERE student_id = %s
        """,
        (student_id,),
    ) or {"total_lab_runs": 0, "successful_lab_runs": 0}

    strong_rows = db.fetch_all(
        """
        SELECT DISTINCT c.title
        FROM quiz_attempts q
        JOIN concepts c ON c.id = q.concept_id
        WHERE q.student_id = %s AND q.score = q.max_score
        LIMIT 3
        """,
        (student_id,),
    )

    coach_data = get_student_coach(student_id)
    weak_concepts = coach_data.get("weak_concepts", [])[:2]

    stats = {
        "total_quizzes": quiz_row.get("total_quizzes", 0),
        "avg_quiz_pct": quiz_row.get("avg_quiz_pct", 0),
        "total_lab_runs": lab_row.get("total_lab_runs", 0),
        "successful_lab_runs": lab_row.get("successful_lab_runs", 0),
        "strong_concepts": [r["title"] for r in strong_rows],
    }

    report = gemini.generate_parent_report(
        student=student,
        stats=stats,
        weak_concepts=weak_concepts,
        language_override=language,
    )
    return {
        "student": student,
        "stats": stats,
        "weak_concepts": weak_concepts,
        "report": report,
    }


@router.get("/centres")
def get_centres_report():
    centres = db.fetch_all(
        """
        WITH student_metrics AS (
            SELECT s.id AS student_id,
                   s.centre_id,
                   COALESCE(AVG((q.score::numeric / NULLIF(q.max_score, 0)) * 100), 0) AS student_quiz_pct,
                   COALESCE(
                       (SUM(CASE WHEN l.success = TRUE THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(l.id), 0)) * 100,
                       0
                   ) AS student_lab_pct
            FROM students s
            LEFT JOIN quiz_attempts q ON q.student_id = s.id
            LEFT JOIN lab_runs l ON l.student_id = s.id
            GROUP BY s.id, s.centre_id
        ),
        quiz_agg AS (
            SELECT s.centre_id,
                   ROUND(AVG((q.score::numeric / NULLIF(q.max_score, 0)) * 100), 1) AS avg_quiz_score_pct
            FROM students s
            JOIN quiz_attempts q ON q.student_id = s.id
            GROUP BY s.centre_id
        ),
        lab_agg AS (
            SELECT s.centre_id,
                   COUNT(l.id) AS total_lab_runs,
                   ROUND(
                       (SUM(CASE WHEN l.success = TRUE THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(l.id), 0)) * 100,
                       1
                   ) AS lab_success_rate_pct
            FROM students s
            JOIN lab_runs l ON l.student_id = s.id
            GROUP BY s.centre_id
        ),
        help_agg AS (
            SELECT centre_id,
                   COUNT(*) AS student_count,
                   SUM(CASE WHEN student_quiz_pct < 55 OR student_lab_pct < 35 THEN 1 ELSE 0 END) AS students_needing_help
            FROM student_metrics
            GROUP BY centre_id
        )
        SELECT c.id, c.name, c.city, c.country,
               COALESCE(h.student_count, 0) AS student_count,
               COALESCE(q.avg_quiz_score_pct, 0) AS avg_quiz_score_pct,
               COALESCE(l.lab_success_rate_pct, 0) AS lab_success_rate_pct,
               COALESCE(l.total_lab_runs, 0) AS total_lab_runs,
               COALESCE(h.students_needing_help, 0) AS students_needing_help
        FROM centres c
        LEFT JOIN quiz_agg q ON q.centre_id = c.id
        LEFT JOIN lab_agg l ON l.centre_id = c.id
        LEFT JOIN help_agg h ON h.centre_id = c.id
        ORDER BY c.id
        """
    )

    sentiment_summary = db.fetch_all(
        """
        SELECT COALESCE(sentiment, 'neutral') AS sentiment, COUNT(*) AS count
        FROM feedback
        GROUP BY COALESCE(sentiment, 'neutral')
        ORDER BY sentiment
        """
    )

    feedback_items = db.fetch_all(
        """
        SELECT f.id, f.student_id, s.first_name AS student_name,
               c.name AS centre_name, f.from_role, f.text,
               f.sentiment, f.topic, f.issue
        FROM feedback f
        JOIN students s ON s.id = f.student_id
        JOIN centres c ON c.id = s.centre_id
        ORDER BY f.id
        """
    )

    top_issues = db.fetch_all(
        """
        SELECT topic, issue, sentiment, COUNT(*) AS occurrences
        FROM feedback
        WHERE issue IS NOT NULL AND LOWER(issue) <> 'none' AND issue <> ''
        GROUP BY topic, issue, sentiment
        ORDER BY occurrences DESC, topic ASC
        LIMIT 10
        """
    )

    return {
        "centres": centres,
        "feedback_sentiment_summary": {
            row["sentiment"]: int(row["count"]) for row in sentiment_summary
        },
        "top_issues": top_issues,
        "feedback_rows": feedback_items,
    }
