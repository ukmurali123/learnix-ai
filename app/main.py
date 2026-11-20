import pathlib
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles

from app import db
from app.routes import coach, concept_studio, concept_visual, lab, path, reports, students

app = FastAPI(
    title="Learnix AI",
    description="Every child gets a robotics lab, even without a kit.",
    version="1.0.0",
)

# Compress responses (Flutter's main.dart.js shrinks from several MB to about a third)
app.add_middleware(GZipMiddleware, minimum_size=1000)

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
app.include_router(concept_visual.router)
app.include_router(concept_studio.router)
app.include_router(lab.router)
app.include_router(coach.router)
app.include_router(reports.router)
app.include_router(path.router)

flutter_dir = pathlib.Path(__file__).resolve().parent.parent / "learnix_flutter" / "build" / "web"
static_dir = pathlib.Path(__file__).resolve().parent.parent / "static"
static_dir.mkdir(parents=True, exist_ok=True)
# The older HTML version stays available at /classic
app.mount("/classic", StaticFiles(directory=str(static_dir), html=True), name="static")
if flutter_dir.exists():
    # The Flutter app is the main site: opening the Cloud Run URL shows it directly
    app.mount("/", StaticFiles(directory=str(flutter_dir), html=True), name="flutter")
else:
    app.mount("/", StaticFiles(directory=str(static_dir), html=True), name="static_root")
