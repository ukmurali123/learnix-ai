"""Concept Studio, live-Learnix style: a typed request and/or page photos or a PDF -> ONE interactive HTML visual
plus a written explanation. Ported from the live Learnix edge function `concept-visual`, using Gemini on Vertex AI.

POST /api/concept-studio/visual  {question?, files?: [{kind: 'image'|'pdf', data: dataUrl}], dim?: '2d'|'3d', language?}
  -> {lesson: {kind: 'visual', title, topic, summary, blocks: [{type:'interactive', title, html}, {type:'explain', title, text}]}}
POST /api/concept-studio/text       {system, prompt, temperature?, maxTokens?} -> {success, text}
POST /api/concept-studio/translate  {texts: [...], lang: 'ta'|'hi'} -> {texts: [...]}
"""
import json
import re
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict, List, Optional

import requests
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.concept_visual_prompts import BUILD, CHECK, EXPLAIN, THREE_RULES
from app.db import PROJECT_ID, get_gcp_token
from app.gemini import GEMINI_MODEL

router = APIRouter(prefix="/api/concept-studio", tags=["concept_visual"])

THREE = THREE_RULES.replace("\\n", "\n")
MAX_FILES = 3
MAX_IMG_B64 = 5_600_000
MAX_PDF_B64 = 11_200_000
LANG_NAMES = {"ta": "Tamil", "hi": "Hindi", "mr": "Marathi", "ar": "Arabic"}


def _url(model: str) -> str:
    return (f"https://aiplatform.googleapis.com/v1/projects/{PROJECT_ID}/locations/global"
            f"/publishers/google/models/{model}:generateContent")


def _gemini(system: str, files: List[Dict[str, str]], text: str, max_tokens: int,
            want_json: bool = False, timeout: int = 110) -> Optional[Dict[str, Any]]:
    parts: List[Dict[str, Any]] = [{"inlineData": {"mimeType": f["mime"], "data": f["b64"]}} for f in files]
    parts.append({"text": text})
    cfg: Dict[str, Any] = {"maxOutputTokens": max_tokens, "temperature": 0.7}
    if want_json:
        cfg["responseMimeType"] = "application/json"
    body = {
        "systemInstruction": {"role": "system", "parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": cfg,
    }
    headers = {"Authorization": f"Bearer {get_gcp_token()}", "Content-Type": "application/json",
               "X-Goog-User-Project": PROJECT_ID}
    try:
        r = requests.post(_url(GEMINI_MODEL), headers=headers, json=body, timeout=timeout)
    except Exception as e:  # network / timeout
        print("concept-visual gemini call failed:", e)
        return None
    if not r.ok:
        print("concept-visual gemini error", r.status_code, r.text[:300])
        return None
    j = r.json()
    c = (j.get("candidates") or [{}])[0]
    out = "".join(p.get("text", "") for p in (c.get("content") or {}).get("parts", []) if not p.get("thought"))
    return {"text": out, "stop": "max_tokens" if c.get("finishReason") == "MAX_TOKENS" else c.get("finishReason", "")}


def _extract_json(t: str) -> Any:
    a, b = t.find("{"), t.rfind("}")
    if a < 0 or b <= a:
        return None
    try:
        return json.loads(t[a:b + 1])
    except Exception:
        return None


def wrap_html(inner: str) -> Optional[str]:
    """Same safety checks as the live app: strip page tags, block network calls, allow only the three.js CDN."""
    h = re.sub(r"```[a-zA-Z]*", "", inner).strip()
    h = re.sub(r"<!doctype[^>]*>", "", h, flags=re.I)
    h = re.sub(r"</?(html|head|body)[^>]*>", "", h, flags=re.I)
    h = re.sub(r"<meta[^>]*>", "", h, flags=re.I)
    h = re.sub(r"<(iframe|object|embed|form|link|base)\b[\s\S]*?>", "", h, flags=re.I)
    if len(h) < 300 or len(h) > 70000:
        return None
    if len(re.findall(r"<script\b", h, re.I)) != len(re.findall(r"</script>", h, re.I)):
        return None
    if re.search(r"\bfetch\s*\(|XMLHttpRequest|WebSocket|EventSource|sendBeacon|document\.cookie|localStorage|sessionStorage|"
                 r"window\.(top|parent|open)|\btop\.location|location\s*=|import\s*\(", h):
        return None
    for src in re.findall(r"<script[^>]*\ssrc\s*=\s*[\"']([^\"']+)[\"']", h, re.I):
        if not src.startswith("https://cdnjs.cloudflare.com/ajax/libs/three.js/"):
            return None
    if re.search(r"CapsuleGeometry|RoundedBoxGeometry|CSS2DRenderer|CSS3DRenderer|OrbitControls\s*\(|new\s+THREE\.(GLTFLoader|EffectComposer)", h):
        return None
    return ('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'unsafe-inline\' https://cdnjs.cloudflare.com; '
            'style-src \'unsafe-inline\'; img-src data: blob:; font-src data:; connect-src \'none\'; frame-src \'none\'; form-action \'none\'">'
            '<style>html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:#0f172a;color:#fff;'
            'font-family:system-ui,Segoe UI,Roboto,sans-serif}*{box-sizing:border-box}</style></head><body>' + h + '</body></html>')


class VisualFile(BaseModel):
    kind: str
    data: str


class VisualRequest(BaseModel):
    question: str = ""
    files: List[VisualFile] = []
    dim: str = ""
    language: str = "en"
    subject: str = ""
    grade: str = ""
    student_id: Optional[int] = None


@router.post("/visual")
def make_visual(req: VisualRequest):
    files = req.files[:MAX_FILES]
    is_pdf = len(files) == 1 and files[0].kind == "pdf"
    img_ok = bool(files) and all(f.kind == "image" and re.match(r"^data:image/(jpeg|png);base64,", f.data) and len(f.data) <= MAX_IMG_B64 for f in files)
    pdf_ok = is_pdf and files[0].data.startswith("data:application/pdf;base64,") and len(files[0].data) <= MAX_PDF_B64
    if files and not img_ok and not pdf_ok:
        raise HTTPException(400, "Send up to 3 images (JPEG or PNG, 4 MB each) or one PDF (8 MB).")
    ask = req.question.strip()[:300]
    if not files and len(ask) < 3:
        raise HTTPException(400, "Type what you want to learn, or add a page.")

    g_files = []
    for f in files:
        m = re.match(r"^data:([^;]+);base64,(.*)$", f.data, re.S)
        if m:
            g_files.append({"mime": m.group(1), "b64": m.group(2)})

    dim_note = ("\nSTYLE: build this as a 3D scene with three.js (the allowed r128 script), with drag-to-rotate and at least two controls, "
                "the whole subject centred and visible in the stage above the control bar, and 6 or more examples to pick from. Keep the code compact."
                if req.dim == "3d" else
                "\nSTYLE: build this as a flat 2D visual with canvas or SVG. Do NOT use three.js." if req.dim == "2d" else "")
    lang = LANG_NAMES.get(req.language)
    lang_note = f"\nLANGUAGE: write every word the student reads in {lang}. Keep technical words (LED, sensor, Arduino) in English." if lang else ""
    context = (f"(A student{' in class ' + req.grade if req.grade else ''} asked this{' for ' + req.subject if req.subject else ''}. "
               f"Pitch the words and depth at that class.)\n") if (req.subject or req.grade) else ""
    user_text = context + (f"Request: {ask}" if ask else "Show what is on this page as an interactive visual.")

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=3) as ex:
        f_check = ex.submit(_gemini, CHECK, g_files, user_text, 1024, True, 60)
        f_build = ex.submit(_gemini, BUILD + THREE + dim_note + lang_note, g_files, user_text, 16000, False, 115)
        f_explain = ex.submit(_gemini, EXPLAIN + lang_note, g_files, user_text, 4000, False, 90)
        checked, first, wrote = f_check.result(), f_build.result(), f_explain.result()

    chk = _extract_json(checked["text"]) if checked else None
    if chk and chk.get("ok") is False:
        return {"rejected": True, "reason": str(chk.get("reason") or "I can't show that. Ask about something you want to understand.")[:300]}

    html = wrap_html(first["text"]) if first and first["stop"] != "max_tokens" else None
    retried = False
    if not html:
        retried = True
        again = _gemini(BUILD + THREE + dim_note + lang_note +
                        "\nYour previous attempt was too long or unfinished, so the screen was blank. Build a SIMPLER version, "
                        "under 9000 characters, and finish every script and tag.", g_files, user_text, 12000, False, 70)
        html = wrap_html(again["text"]) if again and again["stop"] != "max_tokens" else None
    if not html:
        raise HTTPException(502, "The visual could not be built this time. Please try again.")

    title = str((chk or {}).get("title") or ask or "Your visual")[:80]
    topic = str((chk or {}).get("topic") or "")[:80]
    words = re.sub(r"```[a-zA-Z]*", "", (wrote or {}).get("text", "")).strip()
    blocks: List[Dict[str, Any]] = [{"type": "interactive", "title": title, "html": html}]
    if len(words) >= 120:
        blocks.append({"type": "explain", "title": "Explanation", "text": words[:6000]})
    return {"lesson": {"kind": "visual", "title": title, "topic": topic, "summary": "", "blocks": blocks},
            "meta": {"model": GEMINI_MODEL, "ms": int((time.time() - t0) * 1000), "chars": len(html), "retried": retried}}


class TextRequest(BaseModel):
    system: str
    prompt: str
    temperature: float = 0.3
    maxTokens: int = 400
    check_text: str = ""  # what the child typed: checked for safety first


@router.post("/text")
def gemini_text(req: TextRequest):
    if req.check_text.strip():
        from app.gemini import child_safety_check
        safe = child_safety_check(req.check_text)
        if not safe["ok"]:
            return {"success": True, "text": safe["reason"], "blocked": True}
    r = _gemini(req.system, [], req.prompt, max(64, min(req.maxTokens, 4000)), False, 40)
    return {"success": bool(r), "text": (r or {}).get("text", "")}


class TranslateRequest(BaseModel):
    texts: List[str]
    lang: str


@router.post("/translate")
def translate(req: TranslateRequest):
    name = LANG_NAMES.get(req.lang)
    if not name or not req.texts:
        raise HTTPException(400, "Unsupported language.")
    system = (f"Translate each item of the JSON array into {name} for a school student. Keep **bold** markers, numbers and technical words "
              f"(LED, sensor, Arduino) as they are. Reply ONLY with a JSON object {{\"items\": [...]}} with the same number of items, in order.")
    r = _gemini(system, [], json.dumps(req.texts[:80], ensure_ascii=False), 8000, True, 60)
    j = _extract_json(r["text"]) if r else None
    items = j.get("items") if isinstance(j, dict) else None
    if not isinstance(items, list) or len(items) != len(req.texts[:80]):
        raise HTTPException(502, "Could not translate right now.")
    return {"texts": [str(x) for x in items]}
