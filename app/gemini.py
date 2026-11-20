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
    result = call_gemini_json(user_prompt, system_instruction=system_prompt)
    quiz = result.get("quiz", [])
    if len(quiz) > 3:
        result["quiz"] = quiz[:3]
    return result


def generate_page_visual_spec(
    file_bytes: bytes,
    mime_type: str,
    student: Dict[str, Any],
    all_concepts: List[Dict[str, Any]],
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

    user_prompt = f"""Extract 1-4 concepts from this textbook page and return JSON in this exact format:
{{
  "source": "page",
  "blurred": false,
  "message": "",
  "concepts": [
    {{
      "concept_id": 1,
      "title": "Concept title in {language}",
      "summary": "Short 1-2 sentence summary in {language}",
      "type": "animated_steps",
      "steps": [
        {{"caption": "Step 1 in {language}", "highlight": ["battery_plus"]}},
        {{"caption": "Step 2 in {language}", "highlight": ["resistor"]}},
        {{"caption": "Step 3 in {language}", "highlight": ["led"]}}
      ],
      "parts": [
        {{"id": "battery_plus", "label": "Battery +", "explain": "Pushes current out of the positive terminal"}},
        {{"id": "resistor", "label": "Resistor", "explain": "Slows down current so the LED stays safe"}},
        {{"id": "led", "label": "LED", "explain": "A light that glows when current flows anode to cathode"}}
      ],
      "sliders": [
        {{"id": "resistor", "label": "Resistor (ohm)", "min": 100, "max": 1000, "value": 220, "effect": "led_brightness goes down as value goes up"}}
      ],
      "nodes": [],
      "links": [],
      "panels": [],
      "left": null,
      "right": null,
      "quiz": [
        {{
          "kind": "order",
          "question": "Question in {language}",
          "options": ["Option A", "Option B", "Option C", "Option D"],
          "answer": 0,
          "order_answer": [0, 1, 2],
          "why": "One-line explanation in {language}"
        }}
      ],
      "try_it": {{"experiment_id": 1, "instruction": "Try wiring this in the Virtual Lab!"}}
    }}
  ]
}}"""

    return call_gemini_json(
        user_prompt,
        system_instruction=system_prompt,
        media_bytes=file_bytes,
        media_mime_type=mime_type,
    )


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
    return call_gemini_json(prompt, system_instruction=system_prompt)


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
    return call_gemini_json(user_prompt, system_instruction=system_prompt)


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
    return call_gemini_json(user_prompt, system_instruction=system_prompt)


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
