from typing import Any, Dict, List
from fastapi import APIRouter, HTTPException

from app import db

router = APIRouter(prefix="/api/coach", tags=["coach"])

ERROR_TO_CONCEPT_ID = {
    "missing_resistor": 2,   # Resistors and why we need them
    "reversed_polarity": 1,  # What is an LED
    "missing_ground": 10,    # Ground and complete circuits
    "wrong_pin": 3,          # Digital output pins
    "code_logic": 4,         # Loops in code
    "code_syntax": 7,        # If-else decisions
    "wrong_component": 8,    # Ultrasonic distance sensor
}


@router.get("/{student_id}")
def get_student_coach(student_id: int):
    student = db.fetch_one(
        """
        SELECT s.id, s.first_name, s.age, s.grade, s.language,
               s.centre_id, c.name AS centre_name
        FROM students s
        JOIN centres c ON c.id = s.centre_id
        WHERE s.id = %s
        """,
        (student_id,),
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    # 1. Find low quiz score concepts for this student
    quiz_stats = db.fetch_all(
        """
        SELECT c.id AS concept_id, c.title, c.level, c.category, c.summary,
               COUNT(q.id) AS attempts,
               ROUND(AVG((q.score::numeric / NULLIF(q.max_score, 0)) * 100), 1) AS avg_pct
        FROM quiz_attempts q
        JOIN concepts c ON c.id = q.concept_id
        WHERE q.student_id = %s
        GROUP BY c.id, c.title, c.level, c.category, c.summary
        ORDER BY avg_pct ASC, attempts DESC
        """,
        (student_id,),
    )

    # 2. Find recurring lab error types for this student
    lab_errors = db.fetch_all(
        """
        SELECT l.error_type, COUNT(*) AS error_count,
               MAX(l.experiment_id) AS last_experiment_id
        FROM lab_runs l
        WHERE l.student_id = %s AND l.success = FALSE AND l.error_type <> 'none'
        GROUP BY l.error_type
        ORDER BY error_count DESC
        """,
        (student_id,),
    )

    all_concepts = {
        int(c["id"]): c
        for c in db.fetch_all(
            "SELECT id, title, level, category, summary FROM concepts ORDER BY id"
        )
    }

    weak_map: Dict[int, Dict[str, Any]] = {}
    for qs in quiz_stats:
        pct = float(qs.get("avg_pct") or 0)
        if pct < 67.0:
            cid = int(qs["concept_id"])
            weak_map[cid] = {
                "concept_id": cid,
                "title": qs["title"],
                "level": qs["level"],
                "category": qs["category"],
                "summary": qs["summary"],
                "avg_quiz_pct": pct,
                "lab_error_count": 0,
                "reason": f"Quiz average is {pct}% across {qs['attempts']} attempt(s)",
            }

    for err in lab_errors:
        etype = str(err.get("error_type") or "")
        ecount = int(err.get("error_count") or 0)
        cid = ERROR_TO_CONCEPT_ID.get(etype)
        if cid and cid in all_concepts:
            c = all_concepts[cid]
            if cid in weak_map:
                weak_map[cid]["lab_error_count"] += ecount
                weak_map[cid]["reason"] += f" + {ecount}x '{etype}' in Virtual Lab"
            else:
                weak_map[cid] = {
                    "concept_id": cid,
                    "title": c["title"],
                    "level": c["level"],
                    "category": c["category"],
                    "summary": c["summary"],
                    "avg_quiz_pct": None,
                    "lab_error_count": ecount,
                    "reason": f"Had {ecount}x '{etype}' error(s) in Virtual Lab",
                }

    weak_concepts = sorted(
        weak_map.values(),
        key=lambda x: (
            -int(x.get("lab_error_count") or 0),
            float(x["avg_quiz_pct"]) if x["avg_quiz_pct"] is not None else 50.0,
        ),
    )

    # Pick next 2 recommended concepts: top 2 weak concepts, or unattempted concepts if < 2 weak
    attempted_ids = {int(q["concept_id"]) for q in quiz_stats}
    next_concepts: List[Dict[str, Any]] = []
    for wc in weak_concepts[:2]:
        next_concepts.append(
            {
                "concept_id": wc["concept_id"],
                "title": wc["title"],
                "level": wc["level"],
                "category": wc["category"],
                "summary": wc["summary"],
                "why_recommended": f"Strengthen weak area: {wc['reason']}",
            }
        )

    if len(next_concepts) < 2:
        for cid, c in all_concepts.items():
            if cid not in attempted_ids and all(
                nc["concept_id"] != cid for nc in next_concepts
            ):
                next_concepts.append(
                    {
                        "concept_id": cid,
                        "title": c["title"],
                        "level": c["level"],
                        "category": c["category"],
                        "summary": c["summary"],
                        "why_recommended": "New concept ready to unlock next!",
                    }
                )
                if len(next_concepts) >= 2:
                    break

    # Pick 1 recommended experiment matching weak areas or least successful experiment
    experiments = db.fetch_all(
        """
        SELECT e.id, e.title, e.concept_id, c.title AS concept_title,
               e.components, e.goal,
               COALESCE(SUM(CASE WHEN l.success = FALSE THEN 1 ELSE 0 END), 0) AS failures,
               COALESCE(SUM(CASE WHEN l.success = TRUE THEN 1 ELSE 0 END), 0) AS successes
        FROM experiments e
        JOIN concepts c ON c.id = e.concept_id
        LEFT JOIN lab_runs l ON l.experiment_id = e.id AND l.student_id = %s
        GROUP BY e.id, e.title, e.concept_id, c.title, e.components, e.goal
        ORDER BY failures DESC, successes ASC, e.id ASC
        """,
        (student_id,),
    )
    rec_exp = experiments[0] if experiments else None

    top_weak_title = weak_concepts[0]["title"] if weak_concepts else "Loops in code"
    next_titles = " + ".join(nc["title"] for nc in next_concepts)
    exp_title = rec_exp["title"] if rec_exp else "Buzzer + Button"
    coach_message = (
        f"Hi {student['first_name']}! You're building great momentum. "
        f"Let's focus on '{top_weak_title}' next — review {next_titles} in Concept Studio, "
        f"then try the '{exp_title}' project in the Virtual Lab!"
    )

    return {
        "student": student,
        "coach_message": coach_message,
        "weak_concepts": weak_concepts,
        "next_concepts": next_concepts[:2],
        "recommended_experiment": rec_exp,
        "top_lab_errors": lab_errors,
    }
