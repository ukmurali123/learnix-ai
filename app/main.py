import pathlib
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app import db
from app.routes import coach, concept_studio, lab, path, reports, students

app = FastAPI(
    title="Learnix AI",
    description="Every child gets a robotics lab, even without a kit.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check():
    row = db.fetch_one("SELECT current_database() AS db, count(*) AS students_count FROM students")
    return {
        "status": "ok",
        "database": row.get("db") if row else "learnix",
        "students_count": row.get("students_count") if row else 0,
    }


app.include_router(students.router)
app.include_router(concept_studio.router)
app.include_router(lab.router)
app.include_router(coach.router)
app.include_router(reports.router)
app.include_router(path.router)

static_dir = pathlib.Path(__file__).resolve().parent.parent / "static"
static_dir.mkdir(parents=True, exist_ok=True)
app.mount("/", StaticFiles(directory=str(static_dir), html=True), name="static")
