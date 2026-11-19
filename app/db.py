import json
import os
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

    return _execute_via_alloydb_http(sql, params)


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
