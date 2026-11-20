import sys
import os
sys.path.insert(0, os.path.abspath("."))

from fastapi.testclient import TestClient
from app.main import app

def test_full_app():
    client = TestClient(app)

    print("--- 1. Testing Static HTML Pages ---")
    pages = [
        ("/", "Student Hub"),
        ("/index.html", "Student Hub"),
        ("/concept_studio.html", "Concept Studio"),
        ("/virtual_lab.html", "Virtual Lab"),
        ("/coach.html", "AI Coach"),
        ("/reports.html", "Reports &amp; Analytics"),
    ]
    for path, expected_text in pages:
        res = client.get(path)
        assert res.status_code == 200, f"Failed {path}: {res.status_code}"
        assert expected_text in res.text, f"Expected '{expected_text}' in {path}"
        print(f"  ✅ {path} returned 200 OK (contains '{expected_text}')")

    print("\n--- 2. Testing Student Coach API (/api/coach/1) ---")
    res = client.get("/api/coach/1")
    assert res.status_code == 200, f"Coach failed: {res.status_code}"
    coach = res.json()
    assert "coach_message" in coach
    assert "weak_concepts" in coach
    assert "next_concepts" in coach
    print(f"  ✅ Coach message: {coach['coach_message'][:70]}...")
    print(f"  ✅ Weak concepts count: {len(coach['weak_concepts'])}")
    print(f"  ✅ Next concepts count: {len(coach['next_concepts'])}")

    print("\n--- 3. Testing Parent Report API (/api/reports/parent/1) ---")
    res = client.get("/api/reports/parent/1")
    assert res.status_code == 200, f"Parent report failed: {res.status_code}"
    parent = res.json()
    assert "report" in parent
    assert "stats" in parent
    print(f"  ✅ Parent report student: {parent['student']['first_name']}")
    print(f"  ✅ Stats: {parent['stats']}")
    print(f"  ✅ Greeting: {parent['report'].get('greeting')}")

    print("\n--- 4. Testing Centre Dashboard API (/api/reports/centres) ---")
    res = client.get("/api/reports/centres")
    assert res.status_code == 200, f"Centres report failed: {res.status_code}"
    centres = res.json()
    assert "centres" in centres
    assert "feedback_sentiment_summary" in centres
    print(f"  ✅ Centres count: {len(centres['centres'])}")
    print(f"  ✅ Feedback sentiment: {centres['feedback_sentiment_summary']}")
    print(f"  ✅ First centre: {centres['centres'][0]['name']} (students: {centres['centres'][0]['student_count']}, avg quiz: {centres['centres'][0]['avg_quiz_score_pct']}%)")

    print("\n==============================================")
    print("🎉 ALL PAGES & APIs VERIFIED SUCCESSFULLY!")
    print("==============================================")

if __name__ == "__main__":
    test_full_app()
