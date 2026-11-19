import base64
import json
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from app import db, gemini

router = APIRouter(prefix="/api", tags=["lab"])


class BuildFromWordsRequest(BaseModel):
    student_id: int = 1
    idea: str
    language: Optional[str] = None


@router.get("/experiments")
def list_experiments():
    rows = db.fetch_all(
        """
        SELECT e.id, e.title, e.concept_id, c.title AS concept_title,
               c.category, c.level, e.components, e.goal,
               e.starter_code, e.solution_code
        FROM experiments e
        JOIN concepts c ON c.id = e.concept_id
        ORDER BY e.id
        """
    )
    return {"experiments": rows}


@router.get("/experiments/{experiment_id}")
def get_experiment(experiment_id: int):
    row = db.fetch_one(
        """
        SELECT e.id, e.title, e.concept_id, c.title AS concept_title,
               c.category, c.level, e.components, e.goal,
               e.starter_code, e.solution_code
        FROM experiments e
        JOIN concepts c ON c.id = e.concept_id
        WHERE e.id = %s
        """,
        (experiment_id,),
    )
    if not row:
        raise HTTPException(status_code=404, detail="Experiment not found")
    return row


@router.post("/lab/check")
async def check_lab(request: Request):
    """Accepts either application/json or multipart/form-data (for real-kit photo upload)."""
    content_type = request.headers.get("content-type", "")
    image_bytes: Optional[bytes] = None
    image_mime: Optional[str] = None
    ask_again = False
    language_override: Optional[str] = None

    if "multipart/form-data" in content_type:
        form = await request.form()
        experiment_id = int(form.get("experiment_id", 1))
        student_id = int(form.get("student_id", 1))
        circuit_raw = form.get("circuit", "[]")
        code = str(form.get("code", ""))
        ask_again = str(form.get("ask_again", "false")).lower() == "true"
        language_override = form.get("language")
        try:
            circuit = json.loads(str(circuit_raw)) if circuit_raw else []
        except Exception:
            circuit = []
        upload = form.get("image")
        if upload and hasattr(upload, "read"):
            image_bytes = await upload.read()
            image_mime = getattr(upload, "content_type", "image/jpeg") or "image/jpeg"
    else:
        body = await request.json()
        experiment_id = int(body.get("experiment_id", 1))
        student_id = int(body.get("student_id", 1))
        circuit = body.get("circuit") or []
        if isinstance(circuit, str):
            try:
                circuit = json.loads(circuit)
            except Exception:
                circuit = []
        code = str(body.get("code", ""))
        ask_again = bool(body.get("ask_again", False))
        language_override = body.get("language")
        img_b64 = body.get("image_base64") or body.get("image")
        if isinstance(img_b64, str) and img_b64:
            if "," in img_b64 and img_b64.startswith("data:"):
                header, b64data = img_b64.split(",", 1)
                image_mime = header.split(";")[0].replace("data:", "")
                image_bytes = base64.b64decode(b64data)
            else:
                image_mime = body.get("image_mime", "image/jpeg")
                image_bytes = base64.b64decode(img_b64)

    experiment = db.fetch_one(
        "SELECT id, title, concept_id, components, goal, starter_code, solution_code FROM experiments WHERE id = %s",
        (experiment_id,),
    )
    if not experiment:
        raise HTTPException(status_code=404, detail="Experiment not found")

    student = db.fetch_one(
        "SELECT id, first_name, age, grade, language FROM students WHERE id = %s",
        (student_id,),
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if language_override:
        student = dict(student)
        student["language"] = language_override

    # Rule 4 of learnix-lab-partner:
    # Give direct fix ONLY if the student asks again or has failed 3 runs in a row.
    recent_runs = db.fetch_all(
        """
        SELECT success
        FROM lab_runs
        WHERE student_id = %s AND experiment_id = %s
        ORDER BY run_at DESC, id DESC
        LIMIT 3
        """,
        (student_id, experiment_id),
    )
    consecutive_failures = 0
    for r in recent_runs:
        if r.get("success") is False:
            consecutive_failures += 1
        else:
            break

    allow_direct_fix = bool(ask_again or consecutive_failures >= 2)

    feedback = gemini.check_lab_submission(
        experiment=experiment,
        student=student,
        circuit=circuit,
        code=code,
        allow_direct_fix=allow_direct_fix,
        image_bytes=image_bytes,
        image_mime=image_mime,
    )

    is_success = bool(feedback.get("fixed") is True or feedback.get("error_type") == "none")
    error_type = "none" if is_success else str(feedback.get("error_type", "code_logic"))
    ai_hint = None if is_success else str(feedback.get("hint", ""))

    saved_run = db.fetch_one(
        """
        INSERT INTO lab_runs (student_id, experiment_id, success, error_type, ai_hint)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id, run_at
        """,
        (student_id, experiment_id, is_success, error_type, ai_hint),
    )
    if saved_run:
        feedback["lab_run_id"] = saved_run["id"]
    feedback["consecutive_failures"] = 0 if is_success else (consecutive_failures + 1)

    return feedback


@router.post("/lab/build-from-words")
def build_from_words(req: BuildFromWordsRequest):
    student = db.fetch_one(
        "SELECT id, first_name, age, grade, language FROM students WHERE id = %s",
        (req.student_id,),
    )
    if not student:
        student = {"id": 1, "first_name": "Student", "age": 12, "grade": 7, "language": "English"}
    if req.language:
        student = dict(student)
        student["language"] = req.language
    return gemini.build_circuit_from_words(req.idea, student)
