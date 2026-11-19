# Learnix AI — Antigravity Build Kit
**Web page only** — HTML/JS frontend + FastAPI backend, one Cloud Run URL.
Google Startup Buildathon 2026 · Thinkzon

**Pitch:** Every child gets a robotics lab, even without a kit.
**Loop:** Concept Studio (learn) → Virtual Lab + AI Lab Partner (try & fix) → AI Coach (improve) → Reports (parents & centres)

## What's in this kit
| Folder | What it is |
|---|---|
| `.agents/skills/learnix-db-rules/` | Database rules — Antigravity follows them for all SQL |
| `.agents/skills/learnix-lab-partner/` | How the AI checks circuits/code and gives hints |
| `.agents/skills/learnix-concept-studio/` | Textbook page → visuals (formats + JSON spec), lesson and quiz |
| `data/` | Sample CSVs: 6 centres (India, UAE, online), 30 students, 15 concepts, 3 experiments, 180 quiz attempts, 204 lab runs, 30 feedback rows |

> Ask the organisers whether bringing pre-written skills/data is allowed. If not, use this kit to practise tonight, and re-create it at the venue (Antigravity can regenerate the data — see Prompt 2).

---

## What you need to bring
- This kit folder (skills + data + prompts)
- 2-3 clear photos of real textbook pages (electricity / LED / sensors) to test Concept Studio
- Laptop with Antigravity + Data Agent Kit installed, Google account, Cloud project with billing/credits
- Phone for the photo-upload demo and testing the mobile view

## Step 0 — Setup (do this before the event)
1. Install **Antigravity IDE** and sign in with your Google account.
2. Extensions → search **"Google Cloud Data Agent Kit"** → Install.
3. In Google Cloud Console: create project `learnix-buildathon`, link billing/credits, enable **AlloyDB, Vertex AI, Cloud Run, Cloud Build** APIs.
4. Unzip this kit → in Antigravity: **File → Open Folder → `learnix-antigravity-kit`**.
5. Check skills are picked up: ask the agent *"Which skills do you have in this workspace?"* — it should list the three Learnix skills.

---

## Paste these prompts into the Antigravity agent, one at a time
Wait for each to finish, test it, then go to the next. Review the agent's plan before you approve it.

### Prompt 1 — Plan
```
We are building "Learnix AI", a web app that gives every child a robotics lab even without a kit.
Features: (1) Concept Studio - visual learning: student uploads a textbook page (or types a topic) and AI turns it into visuals (animated steps, labelled diagrams, slider simulations, mind maps, story comics) + a visual quiz,
(2) Virtual Lab - 3 browser experiments (LED Blink, Buzzer + Button, Distance Alarm) with an AI Lab Partner that checks the circuit and code,
also accepts a photo of a real kit, (3) AI Coach - finds each student's weak concepts and assigns next steps,
(4) Reports - parent progress note and a centre dashboard.
Stack: web page only (no mobile app). Plain HTML, CSS and JavaScript frontend (no React, no Flutter), served as static files by the same Python FastAPI backend, AlloyDB for PostgreSQL, Gemini on Vertex AI, deployed as ONE Cloud Run service with one URL.
Read the skills in .agents/skills and the CSVs in /data. Make a short implementation plan and folder structure. Do not write code yet.
```

### Prompt 2 — Database (AlloyDB)
```
Using the Data Agent Kit, create an AlloyDB Express instance and a database called learnix.
Create the tables from the learnix-db-rules skill and load all CSVs from /data.
Report row counts for every table.
```
*(If the CSVs aren't allowed at the venue: "Generate realistic sample data matching the learnix-db-rules tables: 6 centres in India, UAE and online, 30 students aged 8-16, 15 robotics/coding/AI concepts, 3 experiments, quiz attempts, lab runs and 30 parent/student/teacher feedback texts.")*

### Prompt 3 — AI inside SQL
```
1) Generate embeddings for concepts (title + summary) inside AlloyDB and add a ScaNN index.
   Show a test query: the 3 concepts most similar to "how does a robot measure distance".
2) Use AI.EXTRACT() to fill feedback.sentiment, topic and issue from feedback.text.
   Show the result for 5 rows.
```

### Prompt 4 — Backend API
```
Create the FastAPI backend with these endpoints:
GET  /api/students, GET /api/students/{id}/progress
POST /api/concept-studio  (topic, student_id) -> lesson JSON per learnix-concept-studio skill
POST /api/concept-studio/from-page  (image or PDF page, student_id) -> visual spec JSON per learnix-concept-studio skill; save to visual_lessons
POST /api/quiz-result
GET  /api/experiments, GET /api/experiments/{id}
POST /api/lab/check  (experiment_id, student_id, circuit JSON, code, optional image) -> JSON per learnix-lab-partner skill; save to lab_runs
GET  /api/coach/{student_id}  -> weak concepts + next 2 concepts + 1 experiment
GET  /api/reports/parent/{student_id} -> short progress note in the student's language
GET  /api/reports/centres -> per-centre stats
Use Gemini on Vertex AI. Use parameterised SQL only. Add a /health endpoint. Run it locally and test each endpoint.
```

### Prompt 5 — Virtual Lab (the main demo)
```
Build the Virtual Lab page.
Left: component tray (Arduino Uno, LED, 220 ohm resistor, push button, buzzer, HC-SR04 sensor, wires).
Centre: breadboard canvas where students drag components and click two pins to connect a wire.
Right: code editor with the experiment's starter code.
"Run" button: a small JavaScript simulator that interprets this Arduino subset:
pinMode, digitalWrite, digitalRead, delay, tone, noTone, if/else, readDistance(), and loop().
Show the LED glowing, buzzer sound (Web Audio) and a slider to move an object for the distance sensor.
If the circuit or code is wrong, call /api/lab/check and show the AI Lab Partner's praise + hint in a friendly chat bubble.
Also add "Check my real kit" - upload a photo, sent to the same endpoint.
Add a "Build from words" box: student types an idea and AI returns the circuit + code, loaded onto the canvas.
Start with LED Blink working end to end before the other two experiments.
```

### Prompt 6 — Concept Studio (visual learning: textbook to visuals)
```
Build the Concept Studio page, following the learnix-concept-studio skill.
Top: two options - "Upload textbook page" (use <input type=file accept="image/*,application/pdf" capture="environment"> so a phone browser opens the camera) or "Type a topic", plus a language dropdown
(English, Tamil, Hindi, Marathi, Arabic).
Send the page to /api/concept-studio/from-page and draw each concept from the returned visual spec:
- animated_steps: SVG diagram with Play / Next buttons, each step highlights parts and shows its caption
- simulation: SVG with sliders; moving a slider changes the drawing live (e.g. LED brightness vs resistor)
- labelled_diagram: tap a part to show its explain text
- mind_map, story_comic, comparison: simple card layouts
Write one reusable JavaScript renderer per type. Start with animated_steps and simulation working end to end.
Add an "Ask a doubt" box under each visual, then the visual quiz (order / label / predict) with instant feedback.
Show "Try it in the Virtual Lab" when try_it is set. Save quiz scores.
Test it with a photo of a real science textbook page about electricity or an LED.
```

### Prompt 7 — Coach + Reports
```
Build: (1) Student home page: progress ring, weak concepts and "Your next step" cards from /api/coach.
(2) Parent report page: AI-written weekly note in the student's language.
(3) Centre dashboard: table + bar chart of average quiz score, lab success rate and students needing help per centre,
plus the feedback sentiment summary from AI.EXTRACT.
Design for a laptop screen first (the demo is on a web page), and make it still work in a phone browser for the photo upload. One clean design: white, blue and orange, rounded cards, large buttons for kids. Add a top navigation bar: Home, Concept Studio, Virtual Lab, Coach, Reports.
```

### Prompt 8 — Deploy
```
Containerise the app (FastAPI serving the API and the static web pages together) and deploy it as ONE Cloud Run service in asia-south1,
with IAM-secured access to AlloyDB and Vertex AI. Give me the public URL and test every page on it in the browser,
including opening Concept Studio on a phone browser and uploading a photo.
```

### Prompt 9 — Deck support
```
Create an architecture diagram of Learnix AI (Gemini, Vertex AI, AlloyDB with embeddings + AI.EXTRACT,
Antigravity Agent Skills, Cloud Run). Also write 6 one-line talking points for the demo.
```

---

## Event-day timeline
| Time | Do |
|---|---|
| 8:00 | Report, set up laptops, open workspace |
| 9:00–10:00 | Prompts 1–3 (plan + database) |
| 10:00–12:00 | Prompt 4 (API) |
| 12:00–16:00 | Prompt 5 (Virtual Lab) — **the most important part** |
| 16:00–18:00 | Prompt 6 (Concept Studio: textbook to visuals) |
| 18:00–20:00 | Prompt 7 (Coach + Reports) |
| 20:00–21:00 | Prompt 8 — **deploy early**, then keep improving |
| Night | Deck + 2-min backup demo video |
| **Before 9:00 AM Day 2** | **Submit deck. No extensions.** Aim for 7–8 AM. |

## If something breaks
- Agent stuck → *"Stop. Explain the error in one line and propose the smallest fix."*
- Out of time → keep LED Blink + Concept Studio perfect; show other features as screens.
- Live demo risk → always have the backup video ready.

## 3-minute demo script
1. Problem: most schools have no robotics lab; kits are costly; practice stops at the centre.
2. Concept Studio: photograph a textbook page on electricity → animated circuit + resistor slider + visual quiz, then switch to Hindi.
3. Virtual Lab: wire the LED to the wrong pin → Run → AI Lab Partner gives a hint → fix → LED blinks.
4. Open the same web page on a phone → photo of a real kit → AI checks it.
5. Coach: "You're weak in loops — next: Loops in code + Buzzer project."
6. Centre dashboard across India, UAE and online + auto parent report.
7. Close: SaaS for any school, academy or franchise, anywhere.
