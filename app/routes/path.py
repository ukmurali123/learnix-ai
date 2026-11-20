import datetime
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app import db, gemini

router = APIRouter(prefix="/api/path", tags=["learning_path"])


class DayCompleteRequest(BaseModel):
    quiz_score: int
    max_score: int = 3


# Pre-defined quizzes for all 10 curriculum days (3 questions each)
DAY_QUIZZES = {
    1: [
        {
            "question": "What kind of current is supplied by a standard chemical battery?",
            "options": ["Direct Current (DC)", "Alternating Current (AC)", "Static Magnetic Flux", "Pulsed Radio Signal"],
            "answer": 0,
            "why": "Batteries supply steady Direct Current (DC), where electrons flow in one continuous direction."
        },
        {
            "question": "What is the primary function of electrical voltage (V) in a circuit?",
            "options": ["Electrical potential pressure that pushes electrons", "Resistance that slows current", "Light emitted by photons", "Sound waves in air"],
            "answer": 0,
            "why": "Voltage is electric potential difference — the push or pressure that forces electrons through a circuit."
        },
        {
            "question": "What happens if you connect a battery's (+) terminal directly to its (−) terminal without any load?",
            "options": ["A dangerous short circuit with extreme heat", "The battery charges instantly", "The voltage doubles", "Nothing happens"],
            "answer": 0,
            "why": "Zero resistance creates a short circuit: huge current rushes through, rapidly heating the battery and wires."
        }
    ],
    2: [
        {
            "question": "Which leg of an LED is the positive Anode?",
            "options": ["The longer leg", "The shorter leg", "Either leg", "The bent leg"],
            "answer": 0,
            "why": "The longer leg of an LED is always the positive Anode (+) and must face positive voltage."
        },
        {
            "question": "What happens if you connect an LED backwards (reverse bias) in a DC circuit?",
            "options": ["It stays off and blocks current", "It glows brighter", "It catches fire", "It beeps"],
            "answer": 0,
            "why": "A diode only allows current to flow in forward bias (anode to cathode). In reverse bias, it blocks current."
        },
        {
            "question": "What does LED stand for?",
            "options": ["Light Emitting Diode", "Low Energy Device", "Linear Electric Driver", "Logic Electron Detector"],
            "answer": 0,
            "why": "LED stands for Light Emitting Diode."
        }
    ],
    3: [
        {
            "question": "Why is a resistor mandatory when connecting an LED to a 5V source?",
            "options": ["It limits current so the LED won't burn out", "It increases voltage", "It stores electric charge", "It converts AC to DC"],
            "answer": 0,
            "why": "An LED has very low internal resistance. Without a resistor, 85+ mA forces through and overheats the semiconductor."
        },
        {
            "question": "According to Ohm's Law (I = V ÷ R), if you increase resistance from 220 Ω to 1,000 Ω, current will:",
            "options": ["Decrease, making the circuit cooler and dimmer", "Increase rapidly", "Double in speed", "Drop to absolute zero instantly"],
            "answer": 0,
            "why": "Current is inversely proportional to resistance. Higher Ohms = lower mA flow."
        },
        {
            "question": "On a 4-band resistor with Brown (1), Black (0), Red (×100), Gold (±5%), what is its resistance?",
            "options": ["1,000 Ω (1.00 kΩ)", "102 Ω", "10,000 Ω", "100 Ω"],
            "answer": 0,
            "why": "Digits 1 and 0 combined give 10, multiplied by 10^2 (100) equals 1,000 Ω (1 kΩ) with ±5% tolerance."
        }
    ],
    4: [
        {
            "question": "Which Arduino command generates a musical alarm tone on a piezo buzzer?",
            "options": ["tone(pin, frequency);", "sound(pin, volume);", "buzz(pin, HIGH);", "digitalWrite(pin, 440);"],
            "answer": 0,
            "why": "tone(pin, frequency) oscillates the pin at the specified audio frequency in Hertz."
        },
        {
            "question": "How does a piezoelectric buzzer generate audible sound waves?",
            "options": ["A piezo ceramic disc rapidly flexes and vibrates air molecules", "A tiny speaker cone with paper tape", "Chemical combustion pulses", "Spinning mechanical wheels"],
            "answer": 0,
            "why": "A piezoelectric crystal flexes mechanically when voltage pulses are applied, vibrating air into acoustic sound waves."
        },
        {
            "question": "How do you silence an active buzzer in Arduino code?",
            "options": ["noTone(pin);", "digitalWrite(pin, LOW);", "tone(pin, 0);", "delay(0);"],
            "answer": 0,
            "why": "noTone(pin) completely stops square wave frequency oscillation on that buzzer pin."
        }
    ],
    5: [
        {
            "question": "In a 7-Segment Display (SSD), how many LED segments are turned ON to display digit '8'?",
            "options": ["All 7 segments (A, B, C, D, E, F, G)", "Only 5 segments", "Only 3 segments", "0 segments"],
            "answer": 0,
            "why": "Digit 8 uses every single segment (A through G) in the figure-8 array."
        },
        {
            "question": "Which two segments light up to display the number '1' on an SSD?",
            "options": ["B and C (the two rightmost vertical bars)", "A and D", "F and E", "G and DP"],
            "answer": 0,
            "why": "Segments B (top-right) and C (bottom-right) illuminate to render the vertical digit 1."
        },
        {
            "question": "What is the primary benefit of using an SSD in robotics projects?",
            "options": ["Provides clear numeric telemetry (scores, distances, timers)", "Speeds up motor rotation", "Filters electrical noise", "Provides high-power battery storage"],
            "answer": 0,
            "why": "7-Segment Displays provide instant human-readable numeric readout of sensor telemetry and counters."
        }
    ],
    6: [
        {
            "question": "Which Arduino command plays a musical tone on a buzzer?",
            "options": ["tone(pin, frequency);", "sound(pin, volume);", "buzz(pin, HIGH);", "digitalWrite(pin, 440);"],
            "answer": 0,
            "why": "tone(pin, frequency) generates a square wave of the specified frequency in Hertz."
        },
        {
            "question": "How do you stop a buzzer that is playing a tone?",
            "options": ["noTone(pin);", "digitalWrite(pin, LOW);", "tone(pin, 0);", "delay(0);"],
            "answer": 0,
            "why": "noTone(pin) stops the audio frequency generation on that pin."
        },
        {
            "question": "In an if-else decision, when does the else block execute?",
            "options": ["When the if condition evaluates to false", "When the if condition is true", "Always simultaneously", "Never"],
            "answer": 0,
            "why": "The else block executes only when the preceding if test is not met (evaluates to false)."
        }
    ],
    7: [
        {
            "question": "What is a variable in programming?",
            "options": ["A named container that holds a value", "A physical wire", "A button that changes shape", "A type of battery"],
            "answer": 0,
            "why": "A variable is a labeled storage box in memory that holds data like numbers or text."
        },
        {
            "question": "Which data type stores whole numbers like pin counts or distance?",
            "options": ["int (integer)", "bool (boolean)", "char (character)", "void"],
            "answer": 0,
            "why": "int stores whole numbers like -10, 0, 15, or 100."
        },
        {
            "question": "If int count = 5; and we run count = count + 1;, what is count?",
            "options": ["6", "5", "51", "1"],
            "answer": 0,
            "why": "Adding 1 to 5 increments the variable's stored value to 6."
        }
    ],
    8: [
        {
            "question": "How does the HC-SR04 ultrasonic sensor measure distance?",
            "options": ["It sends a high-frequency sound pulse and times the echo", "It takes infrared photos", "It weighs the air", "It shines a laser beam"],
            "answer": 0,
            "why": "It emits ultrasonic sound from TRIG and calculates distance from the round-trip travel time to ECHO."
        },
        {
            "question": "Which cylinder on the HC-SR04 ultrasonic sensor transmits sound waves?",
            "options": ["TRIG (Trigger)", "ECHO (Receiver)", "VCC", "GND"],
            "answer": 0,
            "why": "The TRIG pin triggers the transmission of 8 ultrasonic pulses at 40 kHz."
        },
        {
            "question": "Can humans hear the ultrasonic frequency emitted by the distance sensor?",
            "options": ["No, 40 kHz is above the human hearing limit (20 kHz)", "Yes, it sounds like a whistle", "Yes, like a drum", "Only at night"],
            "answer": 0,
            "why": "Human hearing ranges from 20 Hz to 20,000 Hz (20 kHz); ultrasound operates at 40,000 Hz."
        }
    ],
    9: [
        {
            "question": "What does Artificial Intelligence (AI) allow computers to do?",
            "options": ["Learn patterns from data to make decisions", "Only follow hard-coded math formulas", "Generate unlimited electricity", "Build physical circuits automatically"],
            "answer": 0,
            "why": "AI enables systems to learn representations and patterns from data rather than following static rules."
        },
        {
            "question": "In AI, what do we call the collection of examples used to teach a model?",
            "options": ["Training dataset", "Breadboard layout", "Output pin", "Serial monitor"],
            "answer": 0,
            "why": "A training dataset provides labelled examples that the model studies to identify patterns."
        },
        {
            "question": "How does a machine learning model improve its accuracy?",
            "options": ["By adjusting its parameters through training on many examples", "By adding more resistors", "By increasing battery voltage", "By running faster delays"],
            "answer": 0,
            "why": "Machine learning optimizes model weights/parameters by comparing its predictions against correct ground truth."
        }
    ],
    10: [
        {
            "question": "How does an AI computer vision model 'see' an image?",
            "options": ["As a grid of pixel numbers (Red, Green, Blue intensity)", "As sound vibrations", "As analog voltage waves", "As code text"],
            "answer": 0,
            "why": "Digital images are represented as 2D/3D matrices of numeric pixel values from 0 to 255."
        },
        {
            "question": "What feature helps an AI distinguish a cat from a dog?",
            "options": ["Learned visual patterns like ear shapes, whiskers, and textures", "The file name of the photo", "The speed of the camera", "The size of the battery"],
            "answer": 0,
            "why": "Deep learning models detect hierarchical visual features: edges, textures, shapes, and object parts."
        },
        {
            "question": "What is the difference between classification and object detection?",
            "options": ["Classification names the object; detection also finds its location in the image", "They are identical", "Detection only works on audio", "Classification requires wires"],
            "answer": 0,
            "why": "Classification answers 'what is in this picture?'; detection answers 'what is it and where is its bounding box?'."
        }
    ]
}


@router.get("/{student_id}")
def get_learning_path(student_id: int):
    # Verify student exists
    student = db.fetch_one("SELECT id, first_name, grade, language FROM students WHERE id = %s", (student_id,))
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    # Fetch all 10 course days
    course_days = db.fetch_all(
        """
        SELECT cd.id, cd.day_number, cd.title, cd.concept_id, cd.experiment_id, cd.visual_type,
               c.title AS concept_title, c.summary AS concept_summary, c.level AS concept_level, c.category AS concept_category,
               e.title AS experiment_title, e.goal AS experiment_goal, e.components AS experiment_components
        FROM course_days cd
        JOIN concepts c ON c.id = cd.concept_id
        LEFT JOIN experiments e ON e.id = cd.experiment_id
        ORDER BY cd.day_number ASC
        """
    )

    # Fetch student's progress records
    progress_rows = db.fetch_all(
        """
        SELECT day_number, status, quiz_score, completed_at
        FROM student_day_progress
        WHERE student_id = %s
        ORDER BY day_number ASC
        """,
        (student_id,),
    )
    progress_map = {int(p["day_number"]): p for p in progress_rows}

    # Determine status for each day
    days_result = []
    completed_count = 0
    current_day_number = 1

    # Find the latest completed day
    max_completed_day = 0
    for day_num, prog in progress_map.items():
        if prog["status"] == "done":
            completed_count += 1
            if day_num > max_completed_day:
                max_completed_day = day_num

    current_day_number = min(10, max_completed_day + 1)

    for cd in course_days:
        day_num = int(cd["day_number"])
        prog = progress_map.get(day_num)

        if prog and prog["status"] == "done":
            status = "done"
            score = prog.get("quiz_score")
            completed_at = prog.get("completed_at")
        elif day_num == current_day_number:
            status = "current"
            score = None
            completed_at = None
        elif day_num < current_day_number:
            status = "done"
            score = prog.get("quiz_score") if prog else 3
            completed_at = prog.get("completed_at") if prog else None
        else:
            status = "locked"
            score = None
            completed_at = None

        days_result.append({
            "day_number": day_num,
            "title": cd["title"],
            "status": status,
            "quiz_score": score,
            "max_score": 3,
            "visual_type": cd["visual_type"],
            "completed_at": completed_at,
            "concept": {
                "id": cd["concept_id"],
                "title": cd["concept_title"],
                "summary": cd["concept_summary"],
                "level": cd["concept_level"],
                "category": cd["concept_category"],
            },
            "experiment": {
                "id": cd["experiment_id"],
                "title": cd["experiment_title"],
                "goal": cd["experiment_goal"],
                "components": cd["experiment_components"],
            } if cd.get("experiment_id") else None
        })

    return {
        "student": student,
        "days": days_result,
        "completed_count": completed_count,
        "current_day": current_day_number,
        "total_days": 10,
        "progress_percentage": round((completed_count / 10) * 100, 1),
    }


@router.post("/{student_id}/day/{day_number}/complete")
def complete_day(student_id: int, day_number: int, req: DayCompleteRequest):
    if day_number < 1 or day_number > 10:
        raise HTTPException(status_code=400, detail="Invalid day number (must be 1 to 10)")

    student = db.fetch_one("SELECT id, first_name, grade, language FROM students WHERE id = %s", (student_id,))
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    course_day = db.fetch_one(
        """
        SELECT cd.id, cd.day_number, cd.title, cd.concept_id, cd.experiment_id, cd.visual_type, c.title AS concept_title
        FROM course_days cd
        JOIN concepts c ON c.id = cd.concept_id
        WHERE cd.day_number = %s
        """,
        (day_number,),
    )
    if not course_day:
        raise HTTPException(status_code=404, detail="Course day not found")

    concept_id = int(course_day["concept_id"])
    concept_title = course_day.get("concept_title") or course_day["title"]

    # 1. Check if score < 50% -> ask AI Coach for a friendly revision step
    revision_step = None
    is_low_score = (req.quiz_score / max(1, req.max_score)) < 0.5

    if is_low_score:
        revision_step = gemini.generate_revision_step(
            concept_title=concept_title,
            student=student,
            quiz_score=req.quiz_score,
            max_score=req.max_score,
        )
        revision_step["needed"] = True
        revision_step["concept_title"] = concept_title
        revision_step["score"] = req.quiz_score
        revision_step["max_score"] = req.max_score

    # 2. Mark this day as 'done' in student_day_progress
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    db.execute(
        """
        INSERT INTO student_day_progress (student_id, day_number, status, quiz_score, completed_at)
        VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT(student_id, day_number) DO UPDATE SET
            status = 'done',
            quiz_score = EXCLUDED.quiz_score,
            completed_at = EXCLUDED.completed_at
        """,
        (student_id, day_number, "done", req.quiz_score, now_iso),
    )

    # Record in quiz_attempts table so the score contributes to student mastery profile
    db.execute(
        """
        INSERT INTO quiz_attempts (student_id, concept_id, score, max_score)
        VALUES (%s, %s, %s, %s)
        """,
        (student_id, concept_id, req.quiz_score, req.max_score),
    )

    # 3. Unlock the next day if day_number < 10
    unlocked_day = None
    if day_number < 10:
        unlocked_day = day_number + 1
        db.execute(
            """
            INSERT INTO student_day_progress (student_id, day_number, status, quiz_score)
            VALUES (%s, %s, 'current', NULL)
            ON CONFLICT(student_id, day_number) DO UPDATE SET
                status = CASE WHEN student_day_progress.status = 'done' THEN 'done' ELSE 'current' END
            """,
            (student_id, unlocked_day),
        )

    return {
        "status": "completed",
        "day_number": day_number,
        "quiz_score": req.quiz_score,
        "max_score": req.max_score,
        "score_pct": round((req.quiz_score / max(1, req.max_score)) * 100, 1),
        "unlocked_day": unlocked_day,
        "revision": revision_step,
    }


@router.get("/day/{day_number}/content")
def get_day_content(day_number: int):
    if day_number < 1 or day_number > 10:
        raise HTTPException(status_code=400, detail="Invalid day number (must be 1 to 10)")

    course_day = db.fetch_one(
        """
        SELECT cd.id, cd.day_number, cd.title, cd.concept_id, cd.experiment_id, cd.visual_type,
               c.title AS concept_title, c.summary AS concept_summary, c.level AS concept_level, c.category AS concept_category,
               e.id AS exp_id, e.title AS exp_title, e.goal AS exp_goal, e.components AS exp_components, e.starter_code AS exp_code
        FROM course_days cd
        JOIN concepts c ON c.id = cd.concept_id
        LEFT JOIN experiments e ON e.id = cd.experiment_id
        WHERE cd.day_number = %s
        """,
        (day_number,),
    )
    if not course_day:
        raise HTTPException(status_code=404, detail="Course day not found")

    quizzes = DAY_QUIZZES.get(day_number, DAY_QUIZZES[1])

    # Build visual lesson spec tailored to the day's concept and visual_type
    concept_title = course_day["concept_title"]
    v_type = course_day["visual_type"]

    visual_spec = {
        "concept_id": course_day["concept_id"],
        "title": concept_title,
        "summary": course_day["concept_summary"],
        "type": v_type,
        "steps": [
            {"caption": f"Step 1: Electricity enters the circuit for {concept_title}", "highlight": ["battery_plus"]},
            {"caption": f"Step 2: Component safely operates in the circuit", "highlight": ["resistor", "led"]},
            {"caption": f"Step 3: Current returns to ground (GND) to complete the loop", "highlight": ["gnd", "led"]},
        ],
        "parts": [
            {"id": "power", "label": "5V Power", "explain": "Provides the electrical potential push to drive electrons."},
            {"id": "component", "label": concept_title, "explain": course_day["concept_summary"]},
            {"id": "gnd", "label": "GND (Ground)", "explain": "0V reference completing the circuit loop."},
        ],
        "sliders": [
            {"id": "intensity", "label": "Control Variable", "min": 100, "max": 1000, "value": 220, "unit": "Ω", "effect": "Visual response changes live as you drag the slider."}
        ] if v_type == "simulation" else [],
        "quiz": quizzes,
        "try_it": {"experiment_id": course_day["exp_id"], "instruction": f"Build {course_day['exp_title']} in the Virtual Lab!"} if course_day.get("exp_id") else None
    }

    return {
        "day_number": day_number,
        "title": course_day["title"],
        "visual_type": v_type,
        "learn": visual_spec,
        "try": {
            "experiment_id": course_day["exp_id"],
            "title": course_day["exp_title"],
            "goal": course_day["exp_goal"],
            "components": course_day["exp_components"],
            "starter_code": course_day["exp_code"],
        } if course_day.get("exp_id") else None,
        "check": quizzes,
    }
