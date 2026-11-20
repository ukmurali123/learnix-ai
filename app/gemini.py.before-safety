import base64
import json
import os
import re
from typing import Any, Dict, List, Optional

import requests

from app.db import PROJECT_ID, get_gcp_token

GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")
VERTEX_GLOBAL_URL = (
    f"https://aiplatform.googleapis.com/v1/projects/{PROJECT_ID}"
    f"/locations/global/publishers/google/models/{GEMINI_MODEL}:generateContent"
)

ALLOWED_ERROR_TYPES = {
    "wrong_pin",
    "missing_ground",
    "missing_resistor",
    "reversed_polarity",
    "code_logic",
    "code_syntax",
    "wrong_component",
    "none",
}


def _extract_json(text: str) -> Any:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except Exception:
        match = re.search(r"(\{[\s\S]*\}|\[[\s\S]*\])", text)
        if match:
            return json.loads(match.group(1))
        raise


def call_gemini_json(
    prompt: str,
    system_instruction: Optional[str] = None,
    media_bytes: Optional[bytes] = None,
    media_mime_type: Optional[str] = None,
    temperature: float = 0.2,
) -> Dict[str, Any]:
    token = get_gcp_token()
    parts: List[Dict[str, Any]] = []
    if media_bytes and media_mime_type:
        b64 = base64.b64encode(media_bytes).decode("ascii")
        parts.append(
            {
                "inlineData": {
                    "mimeType": media_mime_type,
                    "data": b64,
                }
            }
        )
    parts.append({"text": prompt})

    payload: Dict[str, Any] = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "temperature": temperature,
            "responseMimeType": "application/json",
        },
    }
    if system_instruction:
        payload["systemInstruction"] = {
            "role": "system",
            "parts": [{"text": system_instruction}],
        }

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "X-Goog-User-Project": PROJECT_ID,
    }
    resp = requests.post(VERTEX_GLOBAL_URL, headers=headers, json=payload, timeout=75)
    if not resp.ok:
        raise RuntimeError(f"Vertex AI Gemini error {resp.status_code}: {resp.text}")
    data = resp.json()
    candidates = data.get("candidates", [])
    if not candidates:
        raise RuntimeError("Vertex AI Gemini returned no candidates")
    text = (
        candidates[0]
        .get("content", {})
        .get("parts", [{}])[0]
        .get("text", "{}")
    )
    return _extract_json(text)


def generate_topic_lesson(
    topic: str,
    student: Dict[str, Any],
    matched_concept: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    age = int(student.get("age", 11))
    grade = student.get("grade", 6)
    language = student.get("language", "English")
    age_rule = (
        "Student is aged 8-11: DO NOT use formulas; use simple stories and analogies."
        if age <= 11
        else "Student is aged 12-16: at most ONE simple formula is allowed."
    )
    concept_context = ""
    if matched_concept:
        concept_context = (
            f"Matched curriculum concept: ID={matched_concept['id']}, "
            f"Title='{matched_concept['title']}', Level='{matched_concept['level']}', "
            f"Category='{matched_concept['category']}', Summary='{matched_concept['summary']}'."
        )

    system_prompt = f"""You are Learnix Concept Studio, an expert visual robotics & STEM teacher for kids aged 8-16.
Rules:
1. {age_rule}
2. Write in the student's preferred language: {language}. Keep technical words (LED, sensor, Arduino, resistor, GND, HIGH, LOW, INPUT_PULLUP, loop, pinMode) in English.
3. Explanation must be max 120 words, using simple words for age {age} (Grade {grade}).
4. Facts must be accurate; if unsure, keep it simpler rather than guess.
5. No brand names other than Arduino and the components in the kit (LED, 220 ohm resistor, push button, buzzer, HC-SR04 ultrasonic sensor, wires).
6. Return valid JSON with the exact lesson schema AND a visual spec so the frontend can draw an interactive SVG diagram (`animated_steps` or `simulation` or `labelled_diagram`).
7. Quiz must have EXACTLY 3 questions, 4 options each, one correct answer index (0-3), and a short `why`.
8. `try_it` links to one of our 3 Virtual Lab experiments when relevant:
   - experiment_id 1: LED Blink (LED, resistor, digital output pin D13, complete circuit/GND, loops)
   - experiment_id 2: Buzzer + Button (push button INPUT_PULLUP on D2, buzzer tone() on D8, if-else)
   - experiment_id 3: Distance Alarm (HC-SR04 ultrasonic sensor TRIG D9/ECHO D10, distance < 20cm, buzzer on D8)
   Otherwise set `try_it` to null.
"""

    user_prompt = f"""Student topic: "{topic}"
{concept_context}

Return JSON with this exact structure:
{{
  "title": "clear title in {language}",
  "explanation": "max 120 words explanation in {language} for age {age}",
  "analogy": "one comparison from daily life in {language}",
  "real_life_example": "one real life example in {language}",
  "try_it": {{"experiment_id": 1, "instruction": "short instruction in {language}"}} or null,
  "diagram_prompt": "clear labelled diagram prompt on white background, flat colours, labels in {language}",
  "quiz": [
    {{"question": "...", "options": ["A", "B", "C", "D"], "answer": 0, "why": "..."}},
    {{"question": "...", "options": ["A", "B", "C", "D"], "answer": 1, "why": "..."}},
    {{"question": "...", "options": ["A", "B", "C", "D"], "answer": 2, "why": "..."}}
  ],
  "visual": {{
    "type": "animated_steps" or "simulation" or "labelled_diagram",
    "steps": [
      {{"caption": "Step 1 caption in {language}", "highlight": ["battery_plus", "pin"]}},
      {{"caption": "Step 2 caption in {language}", "highlight": ["resistor"]}},
      {{"caption": "Step 3 caption in {language}", "highlight": ["led", "gnd"]}}
    ],
    "parts": [
      {{"id": "battery_plus", "label": "5V / Pin", "explain": "Pushes electrical current into the circuit"}},
      {{"id": "resistor", "label": "Resistor (220Ω)", "explain": "Limits current to protect the LED"}},
      {{"id": "led", "label": "LED", "explain": "Glows when current flows from anode (+) to cathode (-)"}},
      {{"id": "gnd", "label": "GND", "explain": "Completes the circuit path back to ground"}}
    ],
    "sliders": [
      {{"id": "resistor", "label": "Resistor (ohm)", "min": 100, "max": 1000, "value": 220, "unit": "Ω", "effect": "led_brightness goes down as value goes up"}}
    ]
  }}
}}"""
    try:
        result = call_gemini_json(user_prompt, system_instruction=system_prompt)
    except Exception:
        result = {
            "title": topic,
            "explanation": f"{topic}: Current flows from positive 5V through a current-limiting resistor (220Ω–330Ω) into the component and returns to GND (0V) to complete the closed circuit loop.",
            "analogy": "Like a water pipe loop where a narrow valve keeps water pressure safe for a spinning waterwheel.",
            "real_life_example": "Used in traffic signals, TV remote indicators, smart alarms, and Arduino robotics kits.",
            "try_it": {"experiment_id": 1, "instruction": "Wire an LED and 220Ω resistor to Pin D13 and GND in the Virtual Lab!"},
            "quiz": [
                {
                    "question": "Which leg of an LED connects toward the positive (+) supply?",
                    "options": ["The longer leg (Anode +)", "The shorter leg (Cathode −)", "Either leg", "Neither leg"],
                    "answer": 0,
                    "why": "The longer leg is the positive Anode (+) and must face the positive voltage through a resistor.",
                },
                {
                    "question": "Why is a resistor needed in series with an LED?",
                    "options": ["It limits current so the LED does not burn out", "It increases battery voltage", "It blocks all current", "It changes wire color"],
                    "answer": 0,
                    "why": "Ohm's Law (I = (5V − LED drop) ÷ R) keeps current at a safe ~9–15 mA.",
                },
                {
                    "question": "Where must the negative path of every circuit return?",
                    "options": ["Ground (GND 0V)", "Pin A5", "An open wire", "Reset pin"],
                    "answer": 0,
                    "why": "Electricity requires a complete closed loop back to Ground (GND).",
                },
            ],
            "visual": {
                "type": "simulation",
                "steps": [
                    {"caption": "Step 1: 5V supply pushes current out of the positive (+) terminal.", "highlight": ["battery_plus"]},
                    {"caption": "Step 2: The 330Ω resistor limits current to a safe 9.1 mA.", "highlight": ["resistor"]},
                    {"caption": "Step 3: Current enters the LED anode (+), makes it glow, and returns to GND (−).", "highlight": ["led", "gnd"]},
                ],
                "parts": [
                    {"id": "battery_plus", "label": "5V Supply (+)", "explain": "Pushes electrical current into the circuit"},
                    {"id": "resistor", "label": "Resistor (330Ω)", "explain": "Limits current so the LED never burns out"},
                    {"id": "led", "label": "LED (Anode + / Cathode −)", "explain": "Glows when current flows from long leg (+) to short leg (−)"},
                    {"id": "gnd", "label": "GND (0V)", "explain": "Completes the closed circuit loop back to ground"},
                ],
                "sliders": [
                    {"id": "resistor", "label": "Resistor (Ω)", "min": 100, "max": 1000, "value": 330, "unit": "Ω", "effect": "led_brightness goes down as value goes up"}
                ],
            },
        }
    quiz = result.get("quiz", [])
    if len(quiz) > 3:
        result["quiz"] = quiz[:3]
    return result


def _extract_pdf_or_binary_text(file_bytes: bytes, filename: str = "") -> str:
    """Extract readable ASCII/UTF-8 text strings from a PDF or binary document."""
    chunks = re.findall(rb"[A-Za-z0-9][A-Za-z0-9\s,\.\-\+\(\)\/\:\;\?]{4,120}", file_bytes)
    filtered = []
    skip_tokens = {b"obj", b"endobj", b"stream", b"endstream", b"xref", b"trailer", b"Type", b"Font", b"Page", b"Filter", b"FlateDecode"}
    for c in chunks[:250]:
        if any(tok in c for tok in skip_tokens):
            continue
        try:
            s = c.decode("utf-8", errors="ignore").strip()
            if len(s) >= 5:
                filtered.append(s)
        except Exception:
            pass
    extracted = " ".join(filtered)[:3000].strip()
    if filename:
        extracted = f"Filename: {filename}. {extracted}".strip()
    return extracted


def _build_fallback_page_visual_spec(
    language: str,
    filename: str = "",
    extracted_hint: str = "",
) -> Dict[str, Any]:
    combined = f"{filename} {extracted_hint}".lower()
    clean_name = (
        re.sub(r"\.(pdf|png|jpg|jpeg|webp)$", "", filename, flags=re.IGNORECASE)
        .replace("_", " ")
        .replace("-", " ")
        .strip()
        or "Pythagoras' Theorem"
    )

    # Detect if the uploaded PDF/image is about Pythagoras / Geometry / Maths
    if any(k in combined for k in ("pythag", "hypotenuse", "triangle", "math", "class 7", "class_7", "geometry", "theorem")):
        return {
            "source": "page",
            "blurred": False,
            "message": "",
            "concepts": [
                {
                    "concept_id": 1,
                    "subject_badge": "CLASS 7 MATHS",
                    "visual_domain": "pythagoras",
                    "title": "Pythagoras' Theorem",
                    "summary": "In any right-angled triangle, the square of the longest side (the hypotenuse) equals the sum of the squares of the other two sides: a² + b² = c².",
                    "what_is_on_page": "This worksheet covers Pythagoras' Theorem for Class 7 mathematics, focusing on right-angled triangles with sides labeled a, b, and hypotenuse c opposite the 90° angle. It presents the formula a² + b² = c² alongside three step-by-step solved examples using numbers like 3 cm, 4 cm, and 5 cm. It also includes real-life applications, seven practice problems about ladders and rectangular diagonals, and a complete answer key.",
                    "in_one_line": "Pythagoras' Theorem states that in a right-angled triangle, the square of the longest side equals the sum of the squares of the two shorter sides.",
                    "how_it_works": "Here is how to find the hypotenuse using Example 1 from the worksheet:\n1. Identify the two shorter legs forming the 90° right angle: Side a = 3 cm and Side b = 4 cm.\n2. Square both sides: a² = 3² = 9 and b² = 4² = 16.\n3. Add the two squares together: c² = 9 + 16 = 25.\n4. Take the square root: c = √25 = 5 cm.",
                    "type": "simulation",
                    "steps": [
                        {"caption": "Step 1/6: Identify the 90° right angle at vertex B and the hypotenuse c opposite to it."},
                        {"caption": "Step 2/6: Build a square on Side a (3 × 3) — its area is a² = 9 unit squares."},
                        {"caption": "Step 3/6: Build a square on Side b (4 × 4) — its area is b² = 16 unit squares."},
                        {"caption": "Step 4/6: Combine the unit squares from a² (9) and b² (16) via Proof Flow."},
                        {"caption": "Step 5/6: They fill the hypotenuse square c² = 9 + 16 = 25 unit squares exactly!"},
                        {"caption": "Step 6/6: Take the square root √25 to find the hypotenuse length c = 5.0."},
                    ],
                    "presets": [
                        {"label": "3-4-5 Basic", "a": 3, "b": 4},
                        {"label": "5-12-13 Example", "a": 5, "b": 12},
                        {"label": "6-8-10 Practice", "a": 6, "b": 8},
                        {"label": "8-15-17 Challenge", "a": 8, "b": 15},
                    ],
                    "sliders": [
                        {"id": "side_a", "label": "Side a", "min": 1, "max": 15, "value": 3},
                        {"id": "side_b", "label": "Side b", "min": 1, "max": 15, "value": 4},
                    ],
                    "quiz": [
                        {
                            "kind": "predict",
                            "question": "If a right-angled triangle has legs a = 3 cm and b = 4 cm, what is the length of the hypotenuse c?",
                            "options": ["5 cm", "7 cm", "12 cm", "25 cm"],
                            "answer": 0,
                            "why": "a² + b² = 3² + 4² = 9 + 16 = 25, so c = √25 = 5 cm.",
                        },
                        {
                            "kind": "predict",
                            "question": "In the 5-12-13 right-angled triangle example, what is 5² + 12²?",
                            "options": ["169 (which is 13²)", "144", "25", "17"],
                            "answer": 0,
                            "why": "5² + 12² = 25 + 144 = 169, and √169 = 13.",
                        },
                        {
                            "kind": "label",
                            "question": "Which side of a right-angled triangle is always the hypotenuse?",
                            "options": [
                                "The longest side, directly opposite the 90° right angle",
                                "The shortest vertical side",
                                "The bottom base side",
                                "Any side next to the 90° angle",
                            ],
                            "answer": 0,
                            "why": "The hypotenuse is always opposite the 90° angle and is the longest side of the right triangle.",
                        },
                    ],
                },
                {
                    "concept_id": 2,
                    "subject_badge": "CLASS 7 MATHS",
                    "visual_domain": "pythagoras",
                    "title": "Solving for an Unknown Leg & Ladder Problems",
                    "summary": "When the hypotenuse c and one leg a are known, rearrange the formula to b² = c² − a² to find the missing side.",
                    "what_is_on_page": "The second part of the worksheet shows how to find a missing shorter side when the hypotenuse is already given (such as a 10 m ladder leaning against a wall with its base 6 m away). By subtracting a² from c², students solve for the wall height b = √(10² − 6²) = 8 m.",
                    "in_one_line": "To find a missing shorter leg of a right triangle, subtract the known leg's square from the hypotenuse's square: b² = c² − a².",
                    "how_it_works": "Using the Ladder Problem from the worksheet:\n1. Hypotenuse (ladder) c = 10 m, Base distance a = 6 m.\n2. Compute c² − a² = 100 − 36 = 64.\n3. Height up the wall b = √64 = 8 m.",
                    "type": "simulation",
                    "steps": [
                        {"caption": "Step 1/6: A 10 m ladder leans against a vertical wall (c = 10, a = 6)."},
                        {"caption": "Step 2/6: Square the hypotenuse: c² = 10² = 100."},
                        {"caption": "Step 3/6: Square the known base: a² = 6² = 36."},
                        {"caption": "Step 4/6: Subtract: b² = c² − a² = 100 − 36 = 64."},
                        {"caption": "Step 5/6: Take the square root: b = √64 = 8 m high up the wall."},
                        {"caption": "Step 6/6: Verify: 6² + 8² = 36 + 64 = 100 = 10²!"},
                    ],
                    "presets": [
                        {"label": "6-8-10 Ladder", "a": 6, "b": 8},
                        {"label": "5-12-13 Wall", "a": 5, "b": 12},
                        {"label": "3-4-5 Basic", "a": 3, "b": 4},
                        {"label": "8-15-17 Diagonal", "a": 8, "b": 15},
                    ],
                    "sliders": [
                        {"id": "side_a", "label": "Side a", "min": 1, "max": 15, "value": 6},
                        {"id": "side_b", "label": "Side b", "min": 1, "max": 15, "value": 8},
                    ],
                    "quiz": [
                        {
                            "kind": "predict",
                            "question": "A 10 m ladder leans against a wall with its base 6 m from the wall. How high up the wall does it reach?",
                            "options": ["8 m", "4 m", "16 m", "10 m"],
                            "answer": 0,
                            "why": "b = √(10² − 6²) = √(100 − 36) = √64 = 8 m.",
                        }
                    ],
                },
            ],
        }

    return {
        "source": "page",
        "blurred": False,
        "message": "",
        "concepts": [
            {
                "concept_id": 1,
                "subject_badge": "STEM & PHYSICS",
                "visual_domain": "circuit",
                "title": f"{clean_name}",
                "summary": "Current in an electrical circuit is directly proportional to voltage and inversely proportional to resistance: I = (V − V_led) ÷ R.",
                "what_is_on_page": f"This page ({clean_name}) explains how voltage sources drive electric current through components and how a series resistor safely limits current so LEDs and sensors operate within their rated milliamps.",
                "in_one_line": "A resistor limits electric current according to Ohm's Law (I = V ÷ R) so circuit components glow safely without burning out.",
                "how_it_works": "1. A 5V source provides electrical potential.\n2. Placing a 330 Ω resistor in series limits current to I = (5V − 2V) ÷ 330Ω = 9.1 mA.\n3. Current flows from the LED anode (+) to cathode (−) and returns to GND.",
                "type": "simulation",
                "steps": [
                    {"caption": "Step 1/6: 5V battery pushes current out of the positive (+) terminal."},
                    {"caption": "Step 2/6: Current enters the 330 Ω series resistor."},
                    {"caption": "Step 3/6: The resistor drops excess voltage and limits current to 9.1 mA."},
                    {"caption": "Step 4/6: Current enters the LED Anode (+) and causes photons to emit."},
                    {"caption": "Step 5/6: Current exits the LED Cathode (−) toward the ground wire."},
                    {"caption": "Step 6/6: Electrons return to the negative (−) terminal to complete the closed loop."},
                ],
                "sliders": [
                    {"id": "resistor", "label": "Resistor (Ω)", "min": 100, "max": 1000, "value": 330, "unit": "Ω", "effect": "led_brightness goes down as value goes up"}
                ],
                "nodes": [],
                "links": [],
                "panels": [],
                "left": None,
                "right": None,
                "quiz": [
                    {
                        "kind": "label",
                        "question": "Why does an LED burn out without a resistor?",
                        "options": [
                            "Too much current flows through the low-resistance LED junction",
                            "The resistor creates extra voltage",
                            "The battery stops working",
                            "Current flows backwards from GND",
                        ],
                        "answer": 0,
                        "why": "By Ohm's Law, I = (5 V − LED drop) ÷ R. A 330 Ω resistor keeps current around a safe 9.1 mA.",
                    },
                ],
                "try_it": {"experiment_id": 1, "instruction": "Build the LED + Resistor circuit in the Virtual Lab!"},
            },
        ],
    }


def generate_page_visual_spec(
    file_bytes: bytes,
    mime_type: str,
    student: Dict[str, Any],
    all_concepts: List[Dict[str, Any]],
    filename: str = "",
) -> Dict[str, Any]:
    age = int(student.get("age", 11))
    language = student.get("language", "English")
    age_rule = (
        "Age 8-11: no formulas, use stories and analogies."
        if age <= 11
        else "Age 12-16: at most one simple formula allowed."
    )
    concepts_catalog = "\n".join(
        f"- id={c['id']}: {c['title']} ({c['category']}, {c['level']}) — {c['summary']}"
        for c in all_concepts
    )

    system_prompt = f"""You are Learnix Concept Studio (Visual Learning: Textbook to Visuals).
Read the uploaded textbook page image or PDF and extract 1 to 4 key learning concepts.
Rules:
1. If the image is completely unreadable, blurred, or unrelated to learning/science/STEM, set `"blurred": true` and `"message"` asking for a clearer photo in {language}.
2. Keep facts from the textbook page; simplify wording for age {age} in language `{language}`, never change the science. Keep technical terms (LED, resistor, Arduino, sensor, GND) in English.
3. {age_rule}
4. For each concept pick ONE visual format `type`:
   - `animated_steps`: Process or flow (e.g. current flowing in a circuit, sensor echo pulse)
   - `simulation`: Cause and effect with 1-2 interactive sliders (e.g. bigger resistor -> dimmer LED, closer object -> faster beep)
   - `labelled_diagram`: Parts of a thing (e.g. parts of an LED, Arduino board, ultrasonic sensor)
   - `mind_map`: Whole chapter overview (`nodes` + `links`)
   - `story_comic`: Abstract idea in 4 panels (`panels`: list of 4 objects with `caption` and `scene`)
   - `comparison`: Comparing two things (`left` and `right` objects with matching keys)
   IMPORTANT: Prioritise `animated_steps` and `simulation` whenever possible so students can play animations and move sliders!
5. Limits: Max 6 `steps`, max 8 `parts`, max 2 `sliders` per concept.
6. Every visual part in `parts` MUST have `{{"id": "...", "label": "...", "explain": "one-line explanation in {language}"}}`.
7. End each concept with a visual `quiz` (1-3 questions of kind `order`, `label`, or `predict`; include `options` array of 4 choices and integer `answer` 0-3 plus `ordered_items` if `kind` is `order`, and `why`).
8. Link `try_it` to `experiment_id` 1 (LED Blink), 2 (Buzzer + Button), or 3 (Distance Alarm) when relevant, else null.

Available curriculum concepts for matching `concept_id`:
{concepts_catalog}
"""

    user_prompt = f"""Extract 1-4 concepts from this textbook page (filename: {filename or 'textbook_page'}) and return JSON in this exact format:
{{
  "source": "page",
  "blurred": false,
  "message": "",
  "concepts": [
    {{
      "concept_id": 1,
      "subject_badge": "Subject & Grade badge in uppercase (e.g. CLASS 7 MATHS, CLASS 8 PHYSICS, ELECTRONICS)",
      "visual_domain": "pythagoras" or "geometry" or "physics" or "circuit" or "science",
      "title": "Concept title in {language}",
      "summary": "Short 1-2 sentence summary in {language}",
      "what_is_on_page": "Detailed 3-4 sentence overview in {language} describing what this worksheet/page covers, the formula presented, the step-by-step solved examples, and practice problems on the page.",
      "in_one_line": "Crisp 1-sentence core definition/theorem statement in {language}",
      "how_it_works": "Step-by-step worked example from the page in {language}",
      "analogy": "Simple daily-life analogy in {language}",
      "why": "Why this matters in {language}",
      "real_life_example": "Where it is used in real life in {language}",
      "type": "simulation",
      "steps": [
        {{"caption": "Step 1/6 in {language}"}},
        {{"caption": "Step 2/6 in {language}"}},
        {{"caption": "Step 3/6 in {language}"}},
        {{"caption": "Step 4/6 in {language}"}},
        {{"caption": "Step 5/6 in {language}"}},
        {{"caption": "Step 6/6 in {language}"}}
      ],
      "presets": [
        {{"label": "Example 1 label", "a": 3, "b": 4}},
        {{"label": "Example 2 label", "a": 5, "b": 12}},
        {{"label": "Practice 1 label", "a": 6, "b": 8}},
        {{"label": "Challenge label", "a": 8, "b": 15}}
      ],
      "sliders": [
        {{"id": "param_a", "label": "Parameter 1 label", "min": 1, "max": 15, "value": 3}},
        {{"id": "param_b", "label": "Parameter 2 label", "min": 1, "max": 15, "value": 4}}
      ],
      "parts": [],
      "nodes": [],
      "links": [],
      "panels": [],
      "left": null,
      "right": null,
      "quiz": [
        {{
          "kind": "predict",
          "question": "Question in {language}",
          "options": ["Option A", "Option B", "Option C", "Option D"],
          "answer": 0,
          "why": "One-line explanation in {language}"
        }}
      ],
      "try_it": null
    }}
  ]
}}"""

    try:
        res = call_gemini_json(
            user_prompt,
            system_instruction=system_prompt,
            media_bytes=file_bytes,
            media_mime_type=mime_type,
        )
        if res and isinstance(res.get("concepts"), list) and len(res["concepts"]) > 0:
            return res
    except Exception:
        pass

    # Fallback 1: extract readable text from PDF/document and call Gemini with text prompt
    extracted_text = _extract_pdf_or_binary_text(file_bytes, filename)
    if extracted_text:
        try:
            text_prompt = f"Textbook document text:\n{extracted_text}\n\n{user_prompt}"
            res2 = call_gemini_json(text_prompt, system_instruction=system_prompt)
            if res2 and isinstance(res2.get("concepts"), list) and len(res2["concepts"]) > 0:
                return res2
        except Exception:
            pass

    # Fallback 2: guaranteed multi-concept interactive visual spec
    return _build_fallback_page_visual_spec(language, filename, extracted_text)


def answer_concept_doubt(
    concept_title: str,
    question: str,
    student: Dict[str, Any],
) -> Dict[str, Any]:
    age = int(student.get("age", 11))
    language = student.get("language", "English")
    system_prompt = (
        f"You are Learnix Concept Studio answering a student's doubt about '{concept_title}'. "
        f"Student age: {age}, preferred language: {language}. "
        "Reply in 2-3 short, friendly sentences using a simple analogy. Keep technical words (LED, Arduino, resistor, sensor, GND) in English."
    )
    prompt = f'Student question: "{question}"\nReturn JSON: {{"answer": "...", "tip": "..."}}'
    try:
        return call_gemini_json(prompt, system_instruction=system_prompt)
    except Exception as e:
        print('Gemini failed in answer_concept_doubt -> using built-in sample:', e)
        q_low = question.lower()
        if "resistor" in q_low or "burn" in q_low:
            return {
                "answer": f"Think of a resistor like a narrow speed bump on a water pipe for '{concept_title}'. Without a 220Ω–330Ω resistor, too much electric current (over 80 mA) rushes from the 5V pin through the LED and burns it out instantly!",
                "tip": "Always wire a 220Ω or 330Ω resistor in series with either leg of your LED."
            }
        if "ground" in q_low or "gnd" in q_low:
            return {
                "answer": "Electricity only flows when it has a complete circular track from 5V or a digital pin all the way back to GND (0V). If the GND wire is missing, the bridge is open and no electrons can move!",
                "tip": "Trace your circuit from the positive pin through the component and verify the negative leg returns to Arduino GND."
            }
        return {
            "answer": f"Great question about {concept_title}! In electronics and physics, every component works like part of a team—voltage provides the push, resistors control the flow, and sensors measure changes in the real world.",
            "tip": "Try adjusting the interactive slider in the simulation to see how changing values affects the output in real time!"
        }


def check_lab_submission(
    experiment: Dict[str, Any],
    student: Dict[str, Any],
    circuit: List[Dict[str, Any]],
    code: str,
    allow_direct_fix: bool = False,
    image_bytes: Optional[bytes] = None,
    image_mime: Optional[str] = None,
) -> Dict[str, Any]:
    age = int(student.get("age", 11))
    language = student.get("language", "English")
    exp_title = experiment.get("title", "")
    exp_goal = experiment.get("goal", "")
    exp_components = experiment.get("components", "")
    exp_solution = experiment.get("solution_code", "")

    fix_instruction = (
        "The student has asked again or failed 3 runs in a row: populate `fix` with the clear, direct solution to fix the mistake."
        if allow_direct_fix
        else "Do NOT give the direct answer yet: `fix` MUST be an empty string `\"\"`."
    )

    system_prompt = f"""You are the Learnix AI Lab Partner, a patient robotics teacher helping a student aged {age} (language: {language}) find and fix mistakes in a robotics experiment.
Follow these strict rules from learnix-lab-partner:
1. First say one thing the student did right (`praise`).
2. Find the SINGLE most important mistake only. Do not list every problem at once.
3. Name the mistake type (`error_type`), using EXACTLY ONE of:
   `wrong_pin`, `missing_ground`, `missing_resistor`, `reversed_polarity`, `code_logic`, `code_syntax`, `wrong_component`, `none`
4. Give a `hint` as a Socratic question first (e.g. "Which pin did you connect the LED to? Which pin does your code use?").
   {fix_instruction}
5. Use short sentences and simple words for age {age}. Reply in `{language}` (keep technical names like LED, D13, GND, resistor, INPUT_PULLUP, tone, loop in English).
6. Never use unsafe advice: no mains electricity (230V/110V), no lithium battery opening, no soldering without an adult.
7. If a real-kit photo is attached and is unclear/blurry, set `error_type` to `"wrong_component"`, ask for a clearer photo in `hint`, and do not guess.

Reference experiment details:
- Title: {exp_title}
- Goal: {exp_goal}
- Components: {exp_components}
- Expected wiring rules:
  * Exp 1 (LED Blink): Pin D13 -> 220 ohm resistor -> LED anode (+), and LED cathode (-) -> GND (or D13 -> LED anode, LED cathode -> resistor -> GND). Code must set pinMode(13, OUTPUT) and alternate digitalWrite(13, HIGH) and digitalWrite(13, LOW) with delay().
  * Exp 2 (Buzzer + Button): Button connected between D2 and GND (with pinMode(2, INPUT_PULLUP)); Buzzer positive (+) on D8 and negative (-) on GND. Code must check if(digitalRead(2)==LOW) tone(8, ...) else noTone(8).
  * Exp 3 (Distance Alarm): HC-SR04 VCC->5V, GND->GND, TRIG->D9, ECHO->D10; Buzzer (+) on D8 and (-) on GND. Code must readDistance() and if(d < 20) tone(8, ...) else noTone(8).
- Reference solution code:
{exp_solution}
"""

    user_prompt = f"""Student submission:
Circuit connections JSON: {json.dumps(circuit, ensure_ascii=False)}
Student Arduino code:
```cpp
{code}
```
{"A photo of the student's real robotics kit is also attached. Inspect the breadboard wiring, resistor, LED polarity, pins, and components in the photo." if image_bytes else ""}

Return ONLY valid JSON in this exact format:
{{
  "praise": "One specific thing the student did right in {language}",
  "error_type": "wrong_pin | missing_ground | missing_resistor | reversed_polarity | code_logic | code_syntax | wrong_component | none",
  "hint": "Question-style hint in {language} (or congratulations if error_type is none)",
  "fix": "Direct fix in {language} ONLY if allowed, otherwise empty string",
  "fixed": true or false
}}"""

    try:
        result = call_gemini_json(
            user_prompt,
            system_instruction=system_prompt,
            media_bytes=image_bytes,
            media_mime_type=image_mime,
            temperature=0.1,
        )
        err = str(result.get("error_type", "code_logic")).strip().lower()
        if err not in ALLOWED_ERROR_TYPES:
            err = "code_logic"
        result["error_type"] = err
        result["fixed"] = bool(err == "none" or result.get("fixed") is True)
        if result["fixed"]:
            result["error_type"] = "none"
        if not allow_direct_fix and not result["fixed"]:
            result["fix"] = ""
        return result
    except Exception:
        wires_str = json.dumps(circuit).upper()
        has_gnd = "GND" in wires_str
        has_res = "R1" in wires_str or "RESISTOR" in wires_str
        if not has_gnd:
            return {
                "praise": "Nice start placing your components on the workbench!",
                "error_type": "missing_ground",
                "hint": "Every circuit needs a complete loop back to 0V. Which pin on the Arduino closes the return path to Ground (GND)?",
                "fix": "Connect the negative (-) cathode or GND terminal of your component to Arduino GND." if allow_direct_fix else "",
                "fixed": False,
            }
        if "LED" in wires_str and not has_res:
            return {
                "praise": "Great job connecting your LED and ground wire!",
                "error_type": "missing_resistor",
                "hint": "If 5V goes straight into an LED without slowing the current down, what happens to the LED?",
                "fix": "Add a 220Ω resistor (R1) in series between Pin D13 and LED1.anode." if allow_direct_fix else "",
                "fixed": False,
            }
        return {
            "praise": "Your circuit loop, resistor protection, and Arduino code structure look well organized!",
            "error_type": "none",
            "hint": "Awesome build! Your circuit has a complete loop back to GND and safe current protection.",
            "fix": "",
            "fixed": True,
        }


def build_circuit_from_words(
    idea: str,
    student: Dict[str, Any],
) -> Dict[str, Any]:
    language = student.get("language", "English")
    system_prompt = f"""You are the Learnix Virtual Lab AI builder. The student describes an idea in words, and you return a working virtual circuit and Arduino subset code using our available components:
- Arduino Uno pins: 5V, GND, D2, D8, D9, D10, D13
- Components & terminals:
  * LED1: `LED1.anode`, `LED1.cathode`
  * R1 (220 ohm resistor): `R1.a`, `R1.b`
  * BTN1 (push button): `BTN1.a`, `BTN1.b`
  * BUZ1 (buzzer): `BUZ1.pos`, `BUZ1.neg`
  * US1 (HC-SR04 sensor): `US1.vcc`, `US1.trig`, `US1.echo`, `US1.gnd`
- Supported Arduino subset functions ONLY:
  `pinMode(pin, OUTPUT|INPUT|INPUT_PULLUP);`
  `digitalWrite(pin, HIGH|LOW);`
  `digitalRead(pin)`
  `delay(ms);`
  `tone(pin, freq);`
  `noTone(pin);`
  `long d = readDistance();`
  `if (...) {{ ... }} else {{ ... }}`
Choose the closest `experiment_id` (1 for LED Blink, 2 for Buzzer + Button, 3 for Distance Alarm).
Reply with explanation in `{language}`."""

    user_prompt = f"""Student idea: "{idea}"
Return JSON:
{{
  "experiment_id": 1,
  "title": "Short project title",
  "explanation": "1-2 sentence explanation in {language}",
  "components": ["arduino", "led", "resistor"],
  "circuit": [
    {{"from": "D13", "to": "R1.a"}},
    {{"from": "R1.b", "to": "LED1.anode"}},
    {{"from": "LED1.cathode", "to": "GND"}}
  ],
  "code": "void setup(){{ pinMode(13, OUTPUT); }}\\nvoid loop(){{ digitalWrite(13, HIGH); delay(500); digitalWrite(13, LOW); delay(500); }}"
}}"""
    try:
        return call_gemini_json(user_prompt, system_instruction=system_prompt)
    except Exception as e:
        print('Gemini failed in build_circuit_from_words -> using built-in sample:', e)
        low = (idea or "").lower()
        if any(k in low for k in ["alarm", "intruder", "closer", "distance", "ultrasonic", "burglar", "beep", "radar", "obstacle"]):
            return {
                "experiment_id": 3,
                "title": "Smart Ultrasonic Intruder Distance Alarm",
                "explanation": "Uses an HC-SR04 Ultrasonic Sensor (TRIG on D9, ECHO on D10) to measure intruder distance in cm. As the intruder walks closer (< 30 cm), the Piezo Buzzer on D8 and Red Alert LED on D13 beep and flash faster!",
                "components": ["Arduino Uno", "HC-SR04 Ultrasonic Sensor", "Piezo Buzzer (BUZ1)", "Red Alert LED (LED1)", "220Ω Resistor (R1)"],
                "circuit": [
                    {"from": "5V", "to": "US1.vcc"},
                    {"from": "D9", "to": "US1.trig"},
                    {"from": "D10", "to": "US1.echo"},
                    {"from": "US1.gnd", "to": "GND"},
                    {"from": "D8", "to": "BUZ1.pos"},
                    {"from": "BUZ1.neg", "to": "GND"},
                    {"from": "D13", "to": "R1.a"},
                    {"from": "R1.b", "to": "LED1.anode"},
                    {"from": "LED1.cathode", "to": "GND"},
                ],
                "code": (
                    "void setup() {\n"
                    "  pinMode(9, OUTPUT);   // HC-SR04 TRIG\n"
                    "  pinMode(10, INPUT);   // HC-SR04 ECHO\n"
                    "  pinMode(8, OUTPUT);   // Piezo Buzzer\n"
                    "  pinMode(13, OUTPUT);  // Red Warning LED\n"
                    "}\n\n"
                    "void loop() {\n"
                    "  long d = readDistance(); // Distance in cm\n"
                    "  if (d < 15) {\n"
                    "    // Intruder very close! Fast high-pitch alarm\n"
                    "    digitalWrite(13, HIGH);\n"
                    "    tone(8, 1400);\n"
                    "    delay(100);\n"
                    "    digitalWrite(13, LOW);\n"
                    "    noTone(8);\n"
                    "    delay(100);\n"
                    "  } else if (d < 35) {\n"
                    "    // Intruder approaching: medium warning beep\n"
                    "    digitalWrite(13, HIGH);\n"
                    "    tone(8, 950);\n"
                    "    delay(250);\n"
                    "    digitalWrite(13, LOW);\n"
                    "    noTone(8);\n"
                    "    delay(250);\n"
                    "  } else {\n"
                    "    // Safe zone: alarm off\n"
                    "    digitalWrite(13, LOW);\n"
                    "    noTone(8);\n"
                    "    delay(100);\n"
                    "  }\n"
                    "}"
                ),
            }
        if any(k in low for k in ["button", "doorbell", "switch", "chime", "morse", "piano"]):
            return {
                "experiment_id": 2,
                "title": "Smart Push-Button Doorbell & Status LED",
                "explanation": "Reads a tactile push button on D2 using INPUT_PULLUP. Pressing the button triggers a two-tone chime on the D8 Piezo Buzzer and lights the D13 indicator LED.",
                "components": ["Arduino Uno", "Push Button (BTN1)", "Piezo Buzzer (BUZ1)", "Green LED (LED1)", "220Ω Resistor (R1)"],
                "circuit": [
                    {"from": "D2", "to": "BTN1.a"},
                    {"from": "BTN1.b", "to": "GND"},
                    {"from": "D8", "to": "BUZ1.pos"},
                    {"from": "BUZ1.neg", "to": "GND"},
                    {"from": "D13", "to": "R1.a"},
                    {"from": "R1.b", "to": "LED1.anode"},
                    {"from": "LED1.cathode", "to": "GND"},
                ],
                "code": (
                    "void setup() {\n"
                    "  pinMode(2, INPUT_PULLUP);\n"
                    "  pinMode(8, OUTPUT);\n"
                    "  pinMode(13, OUTPUT);\n"
                    "}\n\n"
                    "void loop() {\n"
                    "  if (digitalRead(2) == LOW) {\n"
                    "    digitalWrite(13, HIGH);\n"
                    "    tone(8, 880);\n"
                    "    delay(200);\n"
                    "    tone(8, 660);\n"
                    "    delay(250);\n"
                    "    noTone(8);\n"
                    "  } else {\n"
                    "    digitalWrite(13, LOW);\n"
                    "    noTone(8);\n"
                    "  }\n"
                    "}"
                ),
            }
        return {
            "experiment_id": 1,
            "title": f"Automated Smart Beacon: {idea[:36]}",
            "explanation": "Controls a current-protected LED beacon on Pin D13 through a 220Ω series resistor with programmable timing pulses and a complete GND return loop.",
            "components": ["Arduino Uno", "220Ω Resistor (R1)", "Super-Bright LED (LED1)", "Breadboard & Jumper Wires"],
            "circuit": [
                {"from": "D13", "to": "R1.a"},
                {"from": "R1.b", "to": "LED1.anode"},
                {"from": "LED1.cathode", "to": "GND"},
            ],
            "code": (
                "void setup() {\n"
                "  pinMode(13, OUTPUT);\n"
                "}\n\n"
                "void loop() {\n"
                "  digitalWrite(13, HIGH);\n"
                "  delay(400);\n"
                "  digitalWrite(13, LOW);\n"
                "  delay(400);\n"
                "}"
            ),
        }


def generate_parent_report(
    student: Dict[str, Any],
    stats: Dict[str, Any],
    weak_concepts: List[Dict[str, Any]],
    language_override: Optional[str] = None,
) -> Dict[str, Any]:
    language = language_override or student.get("language", "English")
    first_name = student.get("first_name", "Student")
    age = student.get("age", 11)
    centre_name = student.get("centre_name", "Learnix")

    system_prompt = f"""You are Learnix AI writing a warm, encouraging weekly parent progress note for {first_name} (age {age}, centre: {centre_name}).
Rules:
1. Write entirely in `{language}` (keep technical terms like LED, Arduino, HC-SR04 in English if helpful).
2. Keep it concise (80-120 words), parent-friendly, celebrating wins first and then gently explaining what {first_name} will practise next at home in the Virtual Lab.
3. Never include any sensitive personal data beyond first name and centre name."""

    user_prompt = f"""Student stats this week:
- Quizzes taken: {stats.get('total_quizzes', 0)}, Average score: {stats.get('avg_quiz_pct', 0)}%
- Virtual Lab runs: {stats.get('total_lab_runs', 0)}, Successful builds: {stats.get('successful_lab_runs', 0)}
- Top concepts mastered: {', '.join(stats.get('strong_concepts', [])) or 'Getting started with basics'}
- Focus areas for next week: {', '.join(c['title'] for c in weak_concepts) or 'Advanced robotics challenges'}

Return JSON:
{{
  "greeting": "Warm greeting to parent in {language}",
  "note": "80-120 word weekly progress paragraph in {language}",
  "highlights": ["Win 1 in {language}", "Win 2 in {language}"],
  "next_week_goal": "One clear next step in {language}",
  "language": "{language}"
}}"""
    try:
        return call_gemini_json(user_prompt, system_instruction=system_prompt)
    except Exception:
        strong = ", ".join(stats.get("strong_concepts", [])[:2]) or "LED circuits and resistor safety"
        focus = ", ".join(c["title"] for c in weak_concepts[:2]) or "ultrasonic distance sensing and conditional loops"
        return {
            "greeting": f"Dear Parent of {first_name},",
            "note": (
                f"{first_name} had a productive week at {centre_name}, completing {stats.get('total_quizzes', 0)} concept quizzes "
                f"(averaging {stats.get('avg_quiz_pct', 0)}%) and running {stats.get('total_lab_runs', 0)} hands-on Virtual Lab experiments "
                f"with {stats.get('successful_lab_runs', 0)} successful circuit builds! {first_name} showed strong confidence in {strong}. "
                f"Next week, we will build on this foundation by practicing {focus} in the Virtual Lab."
            ),
            "highlights": [
                f"Completed {stats.get('successful_lab_runs', 0)} working robotics circuit builds in the Virtual Lab",
                f"Demonstrated solid understanding of {strong}",
            ],
            "next_week_goal": f"Build and test {focus} with zero wiring errors.",
            "language": language,
        }


def generate_revision_step(
    concept_title: str,
    student: Dict[str, Any],
    quiz_score: int,
    max_score: int = 3,
) -> Dict[str, Any]:
    age = int(student.get("age", 11))
    language = student.get("language", "English")
    first_name = student.get("first_name", "Student")
    system_prompt = (
        f"You are Learnix AI Coach helping student {first_name} (age {age}) "
        f"who scored {quiz_score}/{max_score} (< 50%) on '{concept_title}'. "
        f"Write an encouraging revision recap in {language} with a simple real-life analogy, "
        "highlighting the key idea they should remember before moving to the next day. "
        "Keep technical words (LED, resistor, Arduino, sensor, GND) in English."
    )
    prompt = (
        f"Concept: '{concept_title}'. Score: {quiz_score}/{max_score}.\n"
        'Return JSON: {"recap": "2-3 sentence revision recap in student language", "analogy": "one clear comparison from daily life", "coach_tip": "one memorable action tip"}'
    )
    try:
        return call_gemini_json(prompt, system_instruction=system_prompt)
    except Exception:
        return {
            "recap": f"Remember, in '{concept_title}', understanding how components work together makes your robotics circuits reliable every time!",
            "analogy": "Think of a circuit like water flowing through a closed loop: every part must be placed correctly for it to run smoothly.",
            "coach_tip": "Review the visual diagram and step notes before starting the next day!"
        }
