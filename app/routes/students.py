from fastapi import APIRouter, HTTPException
from app import db

router = APIRouter(prefix="/api/students", tags=["students"])


@router.get("")
def list_students():
    rows = db.fetch_all(
        """
        SELECT s.id, s.first_name, s.age, s.grade, s.language,
               s.centre_id, c.name AS centre_name, c.city, c.country
        FROM students s
        JOIN centres c ON c.id = s.centre_id
        ORDER BY s.id
        """
    )
    return {"students": rows}


@router.get("/{student_id}/progress")
def get_student_progress(student_id: int):
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

    quizzes = db.fetch_all(
        """
        SELECT q.id, q.concept_id, co.title AS concept_title, co.category, co.level,
               q.score, q.max_score, q.attempted_at
        FROM quiz_attempts q
        JOIN concepts co ON co.id = q.concept_id
        WHERE q.student_id = %s
        ORDER BY q.attempted_at DESC, q.id DESC
        """,
        (student_id,),
    )

    lab_runs = db.fetch_all(
        """
        SELECT l.id, l.experiment_id, e.title AS experiment_title,
               l.success, l.error_type, l.ai_hint, l.run_at
        FROM lab_runs l
        JOIN experiments e ON e.id = l.experiment_id
        WHERE l.student_id = %s
        ORDER BY l.run_at DESC, l.id DESC
        """,
        (student_id,),
    )

    visual_lessons = db.fetch_all(
        """
        SELECT v.id, v.source_type, v.concept_id, co.title AS concept_title,
               v.visual_type, v.content_json, v.created_at
        FROM visual_lessons v
        LEFT JOIN concepts co ON co.id = v.concept_id
        WHERE v.student_id = %s
        ORDER BY v.created_at DESC, v.id DESC
        LIMIT 10
        """,
        (student_id,),
    )

    total_quizzes = len(quizzes)
    total_score = sum(int(q.get("score") or 0) for q in quizzes)
    total_max = sum(int(q.get("max_score") or 0) for q in quizzes)
    avg_quiz_pct = round((total_score / total_max) * 100, 1) if total_max > 0 else 0.0

    mastered_concepts = {
        q["concept_id"]
        for q in quizzes
        if int(q.get("max_score") or 0) > 0
        and (int(q.get("score") or 0) / int(q.get("max_score") or 1)) >= 0.67
    }

    total_lab_runs = len(lab_runs)
    successful_lab_runs = sum(1 for r in lab_runs if r.get("success") is True)
    completed_experiments = {
        r["experiment_id"] for r in lab_runs if r.get("success") is True
    }
    lab_success_rate_pct = (
        round((successful_lab_runs / total_lab_runs) * 100, 1)
        if total_lab_runs > 0
        else 0.0
    )

    # Progress ring percentage (out of 15 concepts + 3 experiments)
    overall_progress_pct = min(
        100,
        round(((len(mastered_concepts) + len(completed_experiments) * 2) / 21.0) * 100),
    )

    return {
        "student": student,
        "summary": {
            "total_quizzes": total_quizzes,
            "avg_quiz_pct": avg_quiz_pct,
            "concepts_mastered_count": len(mastered_concepts),
            "total_concepts": 15,
            "total_lab_runs": total_lab_runs,
            "successful_lab_runs": successful_lab_runs,
            "lab_success_rate_pct": lab_success_rate_pct,
            "experiments_completed_count": len(completed_experiments),
            "total_experiments": 3,
            "overall_progress_pct": overall_progress_pct,
        },
        "quiz_attempts": quizzes,
        "lab_runs": lab_runs,
        "visual_lessons": visual_lessons,
    }
