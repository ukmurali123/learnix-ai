---
name: learnix-concept-studio
description: How Learnix Concept Studio turns a textbook page or a typed topic into visual learning (animated steps, labelled diagrams, slider simulations, mind maps, story comics, comparisons) plus a lesson and quiz. Use when building or editing Concept Studio, its APIs, its visual renderer or its Gemini prompts.
---

# Learnix Concept Studio

## Input
- topic typed or chosen by the student (e.g. "How does an ultrasonic sensor work?")
- student age, grade and language

## Steps
1. Search the concepts table with vector search for the closest concept. If the match is strong, use that concept's level and category; link the lesson to its concept_id.
2. Ask Gemini to write the lesson using the structure below.
3. Ask the image model (Nano Banana) for one clear, labelled diagram of the concept: white background, flat colours, labels in the student's language.
4. Save quiz results to quiz_attempts.

## Lesson structure (Gemini must return JSON)
```json
{
  "title": "...",
  "explanation": "max 120 words, simple words for the age",
  "analogy": "one comparison from daily life",
  "real_life_example": "...",
  "try_it": {"experiment_id": 3, "instruction": "..."},
  "diagram_prompt": "prompt for the image model",
  "quiz": [
    {"question": "...", "options": ["A","B","C","D"], "answer": 0, "why": "..."}
  ]
}
```
- Exactly 3 quiz questions, 4 options each, one correct answer.
- `try_it` links to a Virtual Lab experiment when one fits; otherwise null.

## Rules
- Age 8-11: no formulas, use stories and analogies. Age 12-16: one simple formula allowed.
- Write in the student's language. Keep technical words (LED, sensor, Arduino) in English.
- Facts must be correct; if unsure, keep it simpler rather than guess.
- No brand names other than Arduino and the components in the kit.

# Visual learning: textbook to visuals

Concept Studio is visual-first. A student can upload a textbook page (photo or PDF) instead of typing a topic.

## Flow
1. Gemini (multimodal) reads the page and lists 1-4 key concepts in it.
2. Match each concept to the concepts table with vector search.
3. For each concept pick ONE visual format from the table below.
4. Return a JSON visual spec. The frontend draws it with SVG / canvas. Do NOT return images of text or long paragraphs.
5. Every visual part can be tapped for a one-line explanation; a "Ask a doubt" box sends the question with the concept.
6. End with a visual quiz (label, order or predict); save to quiz_attempts.
7. Save the generated lesson to visual_lessons so it reopens without a new Gemini call.

## Choosing the format
| Concept type | type value | Example |
|---|---|---|
| Process or flow | animated_steps | current flowing in a circuit, water cycle |
| Parts of a thing | labelled_diagram | parts of an Arduino board |
| Cause and effect | simulation | bigger resistor -> dimmer LED |
| Whole chapter | mind_map | chapter "Electricity" in 6 ideas |
| Abstract idea | story_comic | what is AI, as a robot sorting fruit |
| Comparison | comparison | series vs parallel circuit |

For the Buildathon demo, animated_steps and simulation MUST work; the others are optional.

## Visual spec (Gemini must return JSON)
```json
{
  "source": "page" ,
  "concepts": [
    {
      "concept_id": 1,
      "title": "How an LED glows",
      "type": "animated_steps",
      "steps": [
        {"caption": "Battery pushes current out of +", "highlight": ["battery_plus"]},
        {"caption": "Current flows through the resistor", "highlight": ["resistor"]},
        {"caption": "LED glows when current goes anode to cathode", "highlight": ["led"]}
      ],
      "parts": [{"id": "led", "label": "LED", "explain": "A light that glows when current flows the right way"}],
      "sliders": [],
      "quiz": [{"kind": "order", "question": "Put the steps in order", "answer": [0,1,2]}],
      "try_it": {"experiment_id": 1}
    }
  ]
}
```
- simulation: fill `sliders` like `{"id":"resistor","label":"Resistor (ohm)","min":100,"max":1000,"effect":"led_brightness goes down as value goes up"}`.
- mind_map: `nodes` + `links`. story_comic: exactly 4 `panels` with caption + scene description. comparison: `left` and `right` with the same keys.
- Max 6 steps, max 8 parts, max 2 sliders per concept.

## Rules for page uploads
- Use the page only to build that student's lesson; do not store the page image.
- If the page is blurred or not a learning page, ask for a clearer photo.
- Keep facts from the textbook; simplify wording, never change the science.
