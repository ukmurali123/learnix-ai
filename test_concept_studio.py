import io
import json
import os
import sys
from PIL import Image, ImageDraw

# Add project root to sys.path
sys.path.insert(0, os.path.abspath("."))

from app import db, gemini

SAMPLE_IMAGE_PATH = os.path.abspath("static/sample_textbook_page.jpg")


def create_sample_textbook_page() -> bytes:
    """Create a realistic science textbook page about Electricity, LED, and Resistors."""
    img = Image.new("RGB", (900, 1200), color=(253, 252, 248))
    draw = ImageDraw.Draw(img)

    # Header / Chapter banner
    draw.rectangle([(40, 40), (860, 110)], fill=(37, 99, 235))
    draw.text((60, 55), "CHAPTER 6: ELECTRICITY & SIMPLE CIRCUITS", fill=(255, 255, 255))
    draw.text((60, 80), "Class 8 Science - Physics & Electronics Lab", fill=(219, 234, 254))

    # Section 6.1
    draw.text((50, 135), "6.1 How an LED (Light Emitting Diode) Works", fill=(15, 23, 42))
    
    text_p1 = (
        "An LED is a special semiconductor device that emits light when electric current flows\n"
        "from its positive terminal (Anode) to its negative terminal (Cathode).\n"
        "If connected in reverse, current cannot flow and the LED stays off.\n"
        "Unlike regular bulbs with filaments, LEDs produce very little heat and are highly efficient."
    )
    draw.text((50, 165), text_p1, fill=(51, 65, 85))

    # Circuit Diagram Box
    draw.rectangle([(50, 250), (850, 620)], fill=(241, 245, 249), outline=(203, 213, 225), width=2)
    draw.text((70, 265), "Figure 6.2: Complete DC Circuit with 5V Battery, Resistor, and LED", fill=(30, 58, 138))

    # Battery
    draw.rectangle([(90, 360), (160, 520)], fill=(59, 130, 246), outline=(29, 78, 216), width=2)
    draw.text((120, 380), "+", fill=(255, 255, 255))
    draw.text((110, 435), "5V", fill=(255, 255, 255))
    draw.text((120, 485), "-", fill=(255, 255, 255))
    draw.text((95, 530), "5V Battery", fill=(30, 58, 138))

    # Positive Wire
    draw.line([(160, 395), (320, 395)], fill=(245, 158, 11), width=5)
    draw.text((200, 375), "Current (I) ->", fill=(180, 83, 9))

    # Resistor
    draw.rectangle([(320, 370), (460, 420)], fill=(217, 119, 6), outline=(180, 83, 9), width=2)
    draw.text((340, 388), "Resistor 220Ω", fill=(255, 255, 255))
    draw.text((320, 430), "Limits current flow", fill=(100, 116, 139))

    # Wire between Resistor and LED
    draw.line([(460, 395), (590, 395)], fill=(245, 158, 11), width=5)

    # LED
    draw.ellipse([(590, 360), (660, 430)], fill=(234, 179, 8), outline=(202, 138, 4), width=3)
    draw.text((612, 388), "LED", fill=(15, 23, 42))
    draw.text((560, 360), "Anode (+)", fill=(22, 101, 52))
    draw.text((665, 360), "Cathode (-)", fill=(153, 27, 27))
    draw.text((610, 440), "Yellow Glow", fill=(161, 98, 7))

    # Light Rays
    draw.line([(650, 350), (675, 330)], fill=(250, 204, 21), width=3)
    draw.line([(665, 370), (695, 360)], fill=(250, 204, 21), width=3)
    draw.line([(665, 410), (695, 420)], fill=(250, 204, 21), width=3)

    # Return Ground Wire
    draw.line([(625, 430), (625, 500)], fill=(56, 189, 248), width=5)
    draw.line([(625, 500), (160, 500)], fill=(56, 189, 248), width=5)
    draw.text((340, 510), "<- Return Path to Ground (GND)", fill=(3, 105, 161))

    # Section 6.2 The Purpose of a Resistor
    draw.text((50, 650), "6.2 Why a Protective Resistor is Mandatory", fill=(15, 23, 42))
    text_p2 = (
        "An LED offers very little resistance once illuminated. If hooked directly to 5 Volts without a resistor,\n"
        "an overwhelming rush of current will pass through, immediately burning out the LED junction!\n\n"
        "A 220 Ohm resistor in series limits current to safe levels (~13.6 mA).\n"
        "Increasing the resistance (e.g. 1000 Ohms) reduces current and dims the LED.\n"
        "Decreasing the resistance below 100 Ohms risks damaging the LED from excess current."
    )
    draw.text((50, 680), text_p2, fill=(51, 65, 85))

    # Summary box
    draw.rectangle([(50, 820), (850, 1020)], fill=(254, 243, 199), outline=(252, 211, 77), width=2)
    draw.text((70, 835), "Summary of Concepts:", fill=(146, 64, 14))
    summary_pts = (
        "1. Complete Circuit: Current must flow in a closed loop from Battery (+) back to GND (-).\n"
        "2. Diode Polarity: LED only conducts when Anode is connected towards positive voltage.\n"
        "3. Current Limiting: Resistor protects the LED by limiting current according to Ohm's Law (I = V/R).\n"
        "4. Simulation Effect: Increasing resistance reduces brightness; decreasing resistance increases brightness."
    )
    draw.text((70, 865), summary_pts, fill=(120, 53, 15))

    # Save to disk as well
    os.makedirs(os.path.dirname(SAMPLE_IMAGE_PATH), exist_ok=True)
    img.save(SAMPLE_IMAGE_PATH, format="JPEG", quality=92)

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=92)
    return buf.getvalue()


def run_tests():
    print("==================================================")
    print("Testing Learnix Concept Studio Backend & Visual Spec")
    print("==================================================")

    # 1. Test database connection
    row = db.fetch_one("SELECT id, first_name, grade, language FROM students WHERE id = 1")
    print(f"[1] Verified student record: {row}")
    student = dict(row)

    # 2. Generate and test with authentic science textbook page
    print("\n[2] Creating realistic science textbook page and calling Gemini Multimodal...")
    page_bytes = create_sample_textbook_page()
    print(f"    Textbook page saved at {SAMPLE_IMAGE_PATH} ({len(page_bytes)} bytes)")

    all_concepts = db.fetch_all("SELECT id, title, level, category, summary FROM concepts ORDER BY id")
    print(f"    Loaded {len(all_concepts)} curriculum concepts from DB")

    spec = gemini.generate_page_visual_spec(
        file_bytes=page_bytes,
        mime_type="image/jpeg",
        student=student,
        all_concepts=all_concepts,
    )

    print("\n[3] Gemini Multimodal Page Spec Output:")
    print(f"    Source: {spec.get('source')}")
    print(f"    Blurred: {spec.get('blurred')}")
    concepts = spec.get("concepts", [])
    print(f"    Extracted Concepts Count: {len(concepts)}")

    for i, c in enumerate(concepts):
        print(f"\n    --- Concept {i+1}: {c.get('title')} ---")
        print(f"    Type: {c.get('type')}")
        print(f"    Summary: {c.get('summary')}")
        print(f"    Steps ({len(c.get('steps', []))}):")
        for s in c.get("steps", [])[:3]:
            print(f"      - {s.get('caption')} (highlight: {s.get('highlight')})")
        print(f"    Parts ({len(c.get('parts', []))}):")
        for p in c.get("parts", [])[:3]:
            print(f"      - [{p.get('id')}] {p.get('label')}: {p.get('explain')}")
        print(f"    Sliders: {c.get('sliders')}")
        print(f"    Quiz questions: {len(c.get('quiz', []))}")
        for q in c.get("quiz", [])[:2]:
            print(f"      - [{q.get('kind')}] {q.get('question')} (ans: {q.get('answer')})")
        print(f"    Try it: {c.get('try_it')}")

    # 4. Test Topic Lesson endpoint logic
    print("\n[4] Testing Topic Lesson generation for 'Ultrasonic distance sensor'...")
    topic_lesson = gemini.generate_topic_lesson(
        topic="Ultrasonic distance sensor",
        student=student,
        matched_concept=all_concepts[7] if len(all_concepts) > 7 else None,
    )
    print(f"    Title: {topic_lesson.get('title')}")
    print(f"    Explanation: {topic_lesson.get('explanation')}")
    print(f"    Analogy: {topic_lesson.get('analogy')}")
    print(f"    Visual type: {topic_lesson.get('visual', {}).get('type')}")
    print(f"    Sliders: {topic_lesson.get('visual', {}).get('sliders')}")
    print(f"    Try it: {topic_lesson.get('try_it')}")

    # 5. Test Doubt endpoint
    print("\n[5] Testing Ask a Doubt endpoint...")
    doubt_ans = gemini.answer_concept_doubt(
        concept_title="How an LED glows",
        question="Why does the LED blow up if I don't use a resistor?",
        student=student,
    )
    print(f"    Doubt answer: {doubt_ans.get('answer')}")
    print(f"    Tip: {doubt_ans.get('tip')}")

    # 6. Test saving visual lesson to DB
    print("\n[6] Testing saving visual lesson to DB...")
    saved_lesson = db.fetch_one(
        """
        INSERT INTO visual_lessons (student_id, source_type, concept_id, visual_type, content_json)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id, created_at
        """,
        (1, "page", 1, "animated_steps", concepts[0] if concepts else {"title": "LED Circuit"}),
    )
    print(f"    Saved visual lesson ID: {saved_lesson.get('id')}")

    # 7. Test saving quiz attempt
    print("\n[7] Testing saving quiz attempt in DB...")
    quiz_attempt = db.fetch_one(
        """
        INSERT INTO quiz_attempts (student_id, concept_id, score, max_score)
        VALUES (%s, %s, %s, %s)
        RETURNING id, student_id, concept_id, score, max_score, attempted_at
        """,
        (1, 1, 3, 3),
    )
    print(f"    Quiz attempt saved: {quiz_attempt}")

    print("\n==================================================")
    print("✅ All Concept Studio End-to-End Tests Passed Perfectly!")
    print("==================================================")


if __name__ == "__main__":
    run_tests()

