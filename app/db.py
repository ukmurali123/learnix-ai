import csv
import io
import json
import os
import pathlib
import re
import sqlite3
import datetime
from decimal import Decimal
from typing import Any, Dict, List, Optional, Sequence, Tuple, Union

import google.auth
import google.auth.transport.requests
import requests

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:
    psycopg = None

PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "learnix-ai-515213")
ALLOYDB_REGION = os.environ.get("ALLOYDB_REGION", "asia-southeast1")
ALLOYDB_CLUSTER = os.environ.get("ALLOYDB_CLUSTER", "learnix-cluster")
ALLOYDB_INSTANCE = os.environ.get("ALLOYDB_INSTANCE", "learnix-primary")
ALLOYDB_DATABASE = os.environ.get("ALLOYDB_DATABASE", "learnix")
ALLOYDB_HOST = os.environ.get(
    "ALLOYDB_HOST",
    "d286fb44-16ee-4db0-969a-e554263edfd6.a.asia-southeast1.alloydb.s.cloud.goog",
)
ALLOYDB_USER = os.environ.get("ALLOYDB_USER", "thinkzons@gmail.com")

INSTANCE_RESOURCE = (
    f"projects/{PROJECT_ID}/locations/{ALLOYDB_REGION}"
    f"/clusters/{ALLOYDB_CLUSTER}/instances/{ALLOYDB_INSTANCE}"
)

_creds = None
_use_http_api: Optional[bool] = None
_sqlite_conn: Optional[sqlite3.Connection] = None


def _get_sqlite_db() -> sqlite3.Connection:
    global _sqlite_conn
    if _sqlite_conn is not None:
        return _sqlite_conn

    db_path = pathlib.Path(__file__).resolve().parent.parent / "learnix_local.db"
    conn = sqlite3.connect(str(db_path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    _sqlite_conn = conn

    # Initialize schema
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS centres (
            id INTEGER PRIMARY KEY,
            name TEXT,
            city TEXT,
            country TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY,
            first_name TEXT,
            age INTEGER,
            grade INTEGER,
            language TEXT,
            centre_id INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS concepts (
            id INTEGER PRIMARY KEY,
            title TEXT,
            level TEXT,
            category TEXT,
            summary TEXT,
            embedding TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS experiments (
            id INTEGER PRIMARY KEY,
            title TEXT,
            concept_id INTEGER,
            components TEXT,
            goal TEXT,
            starter_code TEXT,
            solution_code TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS quiz_attempts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            concept_id INTEGER,
            score INTEGER,
            max_score INTEGER,
            attempted_at TEXT DEFAULT CURRENT_TIMESTAMP,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS lab_runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            experiment_id INTEGER,
            success INTEGER,
            error_type TEXT,
            ai_hint TEXT,
            run_at TEXT DEFAULT CURRENT_TIMESTAMP,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS feedback (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            from_role TEXT,
            text TEXT,
            sentiment TEXT,
            topic TEXT,
            issue TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS visual_lessons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            source_type TEXT,
            concept_id INTEGER,
            visual_type TEXT,
            content_json TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS course_days (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day_number INTEGER NOT NULL UNIQUE,
            title TEXT NOT NULL,
            concept_id INTEGER NOT NULL,
            experiment_id INTEGER,
            visual_type TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS student_day_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            day_number INTEGER NOT NULL,
            status TEXT NOT NULL,
            quiz_score INTEGER,
            completed_at TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(student_id, day_number)
        );
    """)

    # Seed 10 Learning Path Days
    days_data = [
        (1, 'Battery (DC Power & Voltage)', 1, None, 'animated_steps'),
        (2, 'LED (Light Emitting Diode)', 2, None, 'simulation'),
        (3, 'Resistor (Current Limiter)', 3, None, 'labelled_diagram'),
        (4, 'Buzzer (Piezo Sounder)', 4, 2, 'animated_steps'),
        (5, 'SSD (7-Segment Display)', 5, None, 'animated_steps'),
        (6, 'Ground and complete circuits', 10, None, 'simulation'),
        (7, 'Digital output pins + loops', 9, 1, 'story_comic'),
        (8, 'Ultrasonic distance sensor', 8, 3, 'simulation'),
        (9, 'What is AI', 13, None, 'story_comic'),
        (10, 'Smart Robotics Project', 14, None, 'comparison'),
    ]
    for d in days_data:
        conn.execute(
            "INSERT OR IGNORE INTO course_days (day_number, title, concept_id, experiment_id, visual_type) VALUES (?, ?, ?, ?, ?)",
            d,
        )
        conn.execute(
            "UPDATE course_days SET title = ?, visual_type = ? WHERE day_number = ?",
            (d[1], d[4], d[0]),
        )
    conn.commit()

    # Seed data from CSVs if empty
    data_dir = pathlib.Path(__file__).resolve().parent.parent / "data"

    cur = conn.cursor()
    cur.execute("SELECT count(*) FROM students")
    if cur.fetchone()[0] == 0 and (data_dir / "students.csv").exists():
        with open(data_dir / "centres.csv", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                conn.execute(
                    "INSERT OR IGNORE INTO centres (id, name, city, country) VALUES (?, ?, ?, ?)",
                    (r["id"], r["name"], r["city"], r["country"]),
                )
        with open(data_dir / "students.csv", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                conn.execute(
                    "INSERT OR IGNORE INTO students (id, first_name, age, grade, language, centre_id) VALUES (?, ?, ?, ?, ?, ?)",
                    (r["id"], r["first_name"], r["age"], r["grade"], r["language"], r["centre_id"]),
                )
        with open(data_dir / "concepts.csv", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                conn.execute(
                    "INSERT OR IGNORE INTO concepts (id, title, level, category, summary) VALUES (?, ?, ?, ?, ?)",
                    (r["id"], r["title"], r["level"], r["category"], r["summary"]),
                )
        with open(data_dir / "experiments.csv", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                conn.execute(
                    "INSERT OR IGNORE INTO experiments (id, title, concept_id, components, goal, starter_code, solution_code) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (r["id"], r["title"], r["concept_id"], r["components"], r["goal"], r["starter_code"], r["solution_code"]),
                )
        if (data_dir / "quiz_attempts.csv").exists():
            with open(data_dir / "quiz_attempts.csv", encoding="utf-8") as f:
                for r in csv.DictReader(f):
                    conn.execute(
                        "INSERT OR IGNORE INTO quiz_attempts (id, student_id, concept_id, score, max_score, attempted_at) VALUES (?, ?, ?, ?, ?, ?)",
                        (r["id"], r["student_id"], r["concept_id"], r["score"], r["max_score"], r["attempted_at"]),
                    )
        if (data_dir / "lab_runs.csv").exists():
            with open(data_dir / "lab_runs.csv", encoding="utf-8") as f:
                for r in csv.DictReader(f):
                    is_success = 1 if str(r.get("success", "")).lower() in ("true", "1") else 0
                    conn.execute(
                        "INSERT OR IGNORE INTO lab_runs (id, student_id, experiment_id, success, error_type, ai_hint, run_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                        (r["id"], r["student_id"], r["experiment_id"], is_success, r.get("error_type", "none"), r.get("ai_hint", ""), r["run_at"]),
                    )
        if (data_dir / "feedback.csv").exists():
            with open(data_dir / "feedback.csv", encoding="utf-8") as f:
                for r in csv.DictReader(f):
                    txt = r["text"].lower()
                    sentiment = "positive"
                    topic = "Robotics Lab"
                    issue = "none"
                    if "slow" in txt or "stuck" in txt or "hard" in txt or "don't know" in txt or "difficult" in txt:
                        sentiment = "negative"
                        issue = "Performance or difficulty"
                    elif "not understand" in txt or "explain" in txt or "confusing" in txt:
                        sentiment = "neutral"
                        issue = "Needs concept clarification"
                    elif "happy" in txt or "fun" in txt or "love" in txt or "excited" in txt:
                        sentiment = "positive"
                        issue = "none"
                    conn.execute(
                        "INSERT OR IGNORE INTO feedback (id, student_id, from_role, text, sentiment, topic, issue) VALUES (?, ?, ?, ?, ?, ?, ?)",
                        (r["id"], r["student_id"], r["from_role"], r["text"], sentiment, topic, issue),
                    )
        conn.commit()

    return conn


def _execute_via_sqlite_fallback(
    sql: str, params: Optional[Sequence[Any]] = None
) -> List[Dict[str, Any]]:
    conn = _get_sqlite_db()
    cur = conn.cursor()

    # Translate Postgres syntax to SQLite
    s = sql.strip()
    # Replace RETURNING
    returning_match = re.search(r"\s+RETURNING\s+([\w\s,]+)$", s, re.IGNORECASE)
    returning_cols = [c.strip() for c in returning_match.group(1).split(",")] if returning_match else []
    if returning_match:
        s = s[: returning_match.start()]

    # Replace %s with ?
    s = s.replace("%s", "?")
    # Replace JSONB or other Postgres casts
    s = re.sub(r"::\w+", "", s)
    s = re.sub(r"current_database\(\)", "'learnix'", s, flags=re.IGNORECASE)
    s = re.sub(r"now\(\)", "datetime('now')", s, flags=re.IGNORECASE)
    s = re.sub(r"\bTRUE\b", "1", s, flags=re.IGNORECASE)
    s = re.sub(r"\bFALSE\b", "0", s, flags=re.IGNORECASE)

    # Convert complex params (dicts, lists) to JSON strings
    converted_params = []
    if params:
        for p in params:
            if isinstance(p, (dict, list)):
                converted_params.append(json.dumps(p, ensure_ascii=False))
            else:
                converted_params.append(p)

    cur.execute(s, converted_params)

    if returning_cols:
        last_id = cur.lastrowid
        conn.commit()
        ret_dict: Dict[str, Any] = {}
        for col in returning_cols:
            if col == "id":
                ret_dict["id"] = last_id
            elif "created_at" in col or "attempted_at" in col:
                ret_dict[col] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            else:
                ret_dict[col] = None
        return [ret_dict]

    if cur.description:
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        result = []
        for row in rows:
            d = {}
            for idx, col in enumerate(cols):
                val = row[idx]
                if isinstance(val, str) and (val.startswith("{") or val.startswith("[")):
                    try:
                        val = json.loads(val)
                    except Exception:
                        pass
                d[col] = val
            result.append(d)
        return result

    conn.commit()
    return []


def get_gcp_token() -> str:
    global _creds
    if _creds is None:
        _creds, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
    if not _creds.valid or _creds.expired or not _creds.token:
        req = google.auth.transport.requests.Request()
        _creds.refresh(req)
    return _creds.token


def _bind_param(val: Any) -> str:
    """Safely bind a single parameter value as a PostgreSQL literal."""
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "TRUE" if val else "FALSE"
    if isinstance(val, (int, float, Decimal)):
        return str(val)
    if isinstance(val, (datetime.datetime, datetime.date)):
        iso = val.isoformat()
        return "'" + iso.replace("'", "''") + "'"
    if isinstance(val, (dict, list)):
        s = json.dumps(val, ensure_ascii=False)
        return "'" + s.replace("'", "''") + "'::jsonb"
    s = str(val)
    return "'" + s.replace("'", "''") + "'"


def bind_sql_params(sql: str, params: Optional[Sequence[Any]] = None) -> str:
    """Safely bind positional %s parameters without raw user string concatenation."""
    if not params:
        return sql
    parts = sql.split("%s")
    if len(parts) - 1 != len(params):
        raise ValueError(
            f"SQL placeholder count ({len(parts) - 1}) does not match params ({len(params)})"
        )
    out = [parts[0]]
    for i, val in enumerate(params):
        out.append(_bind_param(val))
        out.append(parts[i + 1])
    return "".join(out)


def _coerce_value(val_obj: Dict[str, Any], col_type: str) -> Any:
    if val_obj.get("nullValue") is not None or "value" not in val_obj:
        return None
    raw = val_obj["value"]
    t = (col_type or "").upper()
    if t in ("INT2", "INT4", "INT8", "INTEGER", "BIGINT", "SMALLINT", "SERIAL"):
        try:
            return int(raw)
        except ValueError:
            return raw
    if t in ("FLOAT4", "FLOAT8", "NUMERIC", "DECIMAL", "REAL"):
        try:
            return float(raw)
        except ValueError:
            return raw
    if t in ("BOOL", "BOOLEAN"):
        if isinstance(raw, bool):
            return raw
        return str(raw).lower() in ("true", "t", "1")
    if t in ("JSON", "JSONB"):
        try:
            return json.loads(raw)
        except Exception:
            return raw
    return raw


def _execute_via_alloydb_http(
    sql: str, params: Optional[Sequence[Any]] = None
) -> List[Dict[str, Any]]:
    bound_sql = bind_sql_params(sql, params)
    token = get_gcp_token()
    url = f"https://alloydb.googleapis.com/v1beta/{INSTANCE_RESOURCE}:executeSql"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "X-Goog-User-Project": PROJECT_ID,
    }
    payload = {
        "database": ALLOYDB_DATABASE,
        "sqlStatement": bound_sql,
    }
    resp = requests.post(url, headers=headers, json=payload, timeout=90)
    if not resp.ok:
        raise RuntimeError(
            f"AlloyDB executeSql HTTP {resp.status_code}: {resp.text}"
        )
    data = resp.json()
    meta = data.get("metadata", {})
    if meta.get("status") == "ERROR":
        raise RuntimeError(f"AlloyDB SQL Error: {meta.get('message')}")
    results = data.get("sqlResults", [])
    if not results:
        return []
    # Use the last result set that has columns
    target = results[-1]
    for r in reversed(results):
        if "columns" in r:
            target = r
            break
    cols = target.get("columns", [])
    rows = target.get("rows", [])
    parsed_rows: List[Dict[str, Any]] = []
    for row in rows:
        vals = row.get("values", [])
        item: Dict[str, Any] = {}
        for idx, col in enumerate(cols):
            col_name = col.get("name", f"col_{idx}")
            col_type = col.get("type", "TEXT")
            v_obj = vals[idx] if idx < len(vals) else {"nullValue": True}
            item[col_name] = _coerce_value(v_obj, col_type)
        parsed_rows.append(item)
    return parsed_rows


def _execute_query(
    sql: str, params: Optional[Sequence[Any]] = None
) -> List[Dict[str, Any]]:
    global _use_http_api
    db_url = os.environ.get("DATABASE_URL")
    if db_url and psycopg is not None and _use_http_api is not True:
        try:
            with psycopg.connect(db_url, row_factory=dict_row, connect_timeout=5) as conn:
                with conn.cursor() as cur:
                    cur.execute(sql, params or ())
                    if cur.description:
                        return list(cur.fetchall())
                    return []
        except Exception:
            _use_http_api = True

    try:
        return _execute_via_alloydb_http(sql, params)
    except Exception as err:
        # Fall back to local SQLite database if AlloyDB is unreachable or not found
        return _execute_via_sqlite_fallback(sql, params)


def fetch_all(
    sql: str, params: Optional[Sequence[Any]] = None
) -> List[Dict[str, Any]]:
    return _execute_query(sql, params)


def fetch_one(
    sql: str, params: Optional[Sequence[Any]] = None
) -> Optional[Dict[str, Any]]:
    rows = _execute_query(sql, params)
    return rows[0] if rows else None


def execute(
    sql: str, params: Optional[Sequence[Any]] = None
) -> List[Dict[str, Any]]:
    return _execute_query(sql, params)
