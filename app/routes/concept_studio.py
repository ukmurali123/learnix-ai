from typing import Any, Dict, List, Optional
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from app import db, gemini

router = APIRouter(prefix="/api", tags=["concept_studio"])


class TopicLessonRequest(BaseModel):
    topic: str
    student_id: int
    language: Optional[str] = None


class DoubtRequest(BaseModel):
    student_id: int
    concept_title: str
    question: str
    language: Optional[str] = None


class QuizResultRequest(BaseModel):
    student_id: int
    concept_id: int
    score: int
    max_score: int = 3


def _find_closest_concept(query_text: str) -> Optional[Dict[str, Any]]:
    row = db.fetch_one(
        """
        WITH q AS (
            SELECT ai.embedding('text-embedding-005', %s)::vector AS q_vec
        )
        SELECT c.id, c.title, c.level, c.category, c.summary,
               ROUND((1 - (c.embedding <=> q.q_vec))::numeric, 4) AS similarity
        FROM concepts c, q
        WHERE c.embedding IS NOT NULL
        ORDER BY c.embedding <=> q.q_vec
        LIMIT 1
        """,
        (query_text,),
    )
    return row


@router.post("/concept-studio")
def create_concept_lesson(req: TopicLessonRequest):
    student = db.fetch_one(
        "SELECT id, first_name, age, grade, language, centre_id FROM students WHERE id = %s",
        (req.student_id,),
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if req.language:
        student = dict(student)
        student["language"] = req.language

    matched = _find_closest_concept(req.topic)
    strong_match = matched and float(matched.get("similarity") or 0) >= 0.40
    concept_id = int(matched["id"]) if strong_match else (int(matched["id"]) if matched else 1)

    lesson = gemini.generate_topic_lesson(
        topic=req.topic,
        student=student,
        matched_concept=matched if strong_match else None,
    )

    lesson["concept_id"] = concept_id
    if matched:
        lesson["matched_concept"] = {
            "id": matched["id"],
            "title": matched["title"],
            "level": matched["level"],
            "category": matched["category"],
            "similarity": matched["similarity"],
        }

    visual_obj = lesson.get("visual") or {}
    visual_type = visual_obj.get("type", "animated_steps")

    # Save to visual_lessons so it can reopen without a new Gemini call
    saved = db.fetch_one(
        """
        INSERT INTO visual_lessons (student_id, source_type, concept_id, visual_type, content_json)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id, created_at
        """,
        (req.student_id, "topic", concept_id, visual_type, lesson),
    )
    if saved:
        lesson["visual_lesson_id"] = saved["id"]

    return lesson


@router.post("/concept-studio/from-page")
async def create_visuals_from_page(
    student_id: int = Form(...),
    language: Optional[str] = Form(None),
    file: UploadFile = File(...),
):
    student = db.fetch_one(
        "SELECT id, first_name, age, grade, language, centre_id FROM students WHERE id = %s",
        (student_id,),
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if language:
        student = dict(student)
        student["language"] = language

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")

    mime_type = file.content_type or "image/jpeg"
    all_concepts = db.fetch_all(
        "SELECT id, title, level, category, summary FROM concepts ORDER BY id"
    )

    spec = gemini.generate_page_visual_spec(
        file_bytes=file_bytes,
        mime_type=mime_type,
        student=student,
        all_concepts=all_concepts,
    )

    # Note: per learnix-concept-studio rule, we NEVER store the uploaded page image.
    spec["source"] = "page"
    concepts_list: List[Dict[str, Any]] = spec.get("concepts") or []

    valid_ids = {int(c["id"]) for c in all_concepts}
    saved_ids: List[int] = []

    for c_item in concepts_list:
        c_title = c_item.get("title") or ""
        c_summary = c_item.get("summary") or ""
        c_id = c_item.get("concept_id")
        if not c_id or int(c_id) not in valid_ids:
            matched = _find_closest_concept(f"{c_title} {c_summary}".strip() or "LED circuit")
            c_id = int(matched["id"]) if matched else 1
        else:
            c_id = int(c_id)
        c_item["concept_id"] = c_id

        v_type = c_item.get("type") or "animated_steps"
        saved = db.fetch_one(
            """
            INSERT INTO visual_lessons (student_id, source_type, concept_id, visual_type, content_json)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
            """,
            (student_id, "page", c_id, v_type, c_item),
        )
        if saved:
            c_item["visual_lesson_id"] = saved["id"]
            saved_ids.append(saved["id"])

    spec["saved_visual_lesson_ids"] = saved_ids
    return spec


@router.post("/concept-studio/doubt")
def ask_concept_doubt(req: DoubtRequest):
    student = db.fetch_one(
        "SELECT id, first_name, age, grade, language FROM students WHERE id = %s",
        (req.student_id,),
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if req.language:
        student = dict(student)
        student["language"] = req.language
    return gemini.answer_concept_doubt(req.concept_title, req.question, student)


@router.get("/visual-lessons/{student_id}")
def list_visual_lessons(student_id: int):
    rows = db.fetch_all(
        """
        SELECT v.id, v.student_id, v.source_type, v.concept_id,
               c.title AS concept_title, v.visual_type, v.content_json, v.created_at
        FROM visual_lessons v
        LEFT JOIN concepts c ON c.id = v.concept_id
        WHERE v.student_id = %s
        ORDER BY v.created_at DESC, v.id DESC
        LIMIT 20
        """,
        (student_id,),
    )
    return {"visual_lessons": rows}


@router.post("/quiz-result")
def save_quiz_result(req: QuizResultRequest):
    student = db.fetch_one("SELECT id FROM students WHERE id = %s", (req.student_id,))
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    concept = db.fetch_one("SELECT id, title FROM concepts WHERE id = %s", (req.concept_id,))
    concept_id = int(concept["id"]) if concept else 1

    saved = db.fetch_one(
        """
        INSERT INTO quiz_attempts (student_id, concept_id, score, max_score)
        VALUES (%s, %s, %s, %s)
        RETURNING id, student_id, concept_id, score, max_score, attempted_at
        """,
        (req.student_id, concept_id, req.score, req.max_score),
    )
    return {"status": "saved", "quiz_attempt": saved}
