import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
from fastapi.testclient import TestClient
from app.main import app

def test_learning_path():
    client = TestClient(app)

    # 1. Reset progress for student 1 if any exists
    from app.db import execute
    execute("DELETE FROM student_day_progress WHERE student_id = 1")

    # 2. Test GET /api/path/1
    resp = client.get('/api/path/1')
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"
    data = resp.json()
    assert data["student"]["id"] == 1
    days = data["days"]
    assert len(days) == 10, f"Expected 10 days, got {len(days)}"
    print(f"\n[PASS] GET /api/path/1 returned {len(days)} days.")
    print(f"Day 1 initial status: {days[0]['status']}")
    assert days[0]["status"] == "current", "Day 1 should be current by default"
    for d in days[1:]:
        assert d["status"] == "locked", f"Day {d['day_number']} should be locked initially"

    # 3. Test GET /api/path/day/1/content
    c_resp = client.get('/api/path/day/1/content')
    assert c_resp.status_code == 200
    c_data = c_resp.json()
    assert "learn" in c_data and c_data["learn"] is not None
    assert c_data["visual_type"] == "animated_steps"
    assert "check" in c_data and len(c_data["check"]) == 3
    print(f"[PASS] GET /api/path/day/1/content returned 3-step mission content: visual_type={c_data['visual_type']}, quiz questions={len(c_data['check'])}")

    # 4. Test Day 4 content (which has experiment_id=1, Virtual Lab LED Blink)
    c4_resp = client.get('/api/path/day/4/content')
    assert c4_resp.status_code == 200
    c4_data = c4_resp.json()
    assert c4_data.get("try") is not None
    assert c4_data["try"]["experiment_id"] == 1
    print(f"[PASS] GET /api/path/day/4/content correctly includes Virtual Lab experiment: {c4_data['try']['title']}")

    # 5. Complete Day 1 with low score (1/3 -> 33% < 50%) -> should trigger AI Coach revision step
    comp1 = client.post('/api/path/1/day/1/complete', json={'quiz_score': 1})
    assert comp1.status_code == 200
    comp1_res = comp1.json()
    assert comp1_res["status"] == "completed"
    assert comp1_res["day_number"] == 1
    assert comp1_res["unlocked_day"] == 2
    assert comp1_res.get("revision") is not None
    assert comp1_res["revision"]["needed"] is True
    print(f"[PASS] Low score (<50%) triggered AI Coach revision:")
    print(f"       Tip: {comp1_res['revision'].get('coach_tip')}")
    print(f"       Analogy: {comp1_res['revision'].get('analogy')}")

    # 6. Verify Day 2 is now unlocked and Day 1 is done
    resp_after1 = client.get('/api/path/1')
    days_after1 = resp_after1.json()['days']
    assert days_after1[0]["status"] == "done"
    assert days_after1[0]["quiz_score"] == 1
    assert days_after1[1]["status"] == "current"
    print(f"[PASS] Day 1 is 'done' (score=1), Day 2 is unlocked as 'current'.")

    # 7. Complete Day 2 with high score (3/3 -> 100%) -> no revision step needed
    comp2 = client.post('/api/path/1/day/2/complete', json={'quiz_score': 3})
    assert comp2.status_code == 200
    comp2_res = comp2.json()
    assert comp2_res["status"] == "completed"
    assert comp2_res["unlocked_day"] == 3
    assert comp2_res.get("revision") is None or comp2_res["revision"].get("needed") is False
    print(f"[PASS] High score (100%) completed Day 2 with no revision required.")

    # 8. Verify Day 3 is now unlocked
    resp_after2 = client.get('/api/path/1')
    days_after2 = resp_after2.json()['days']
    assert days_after2[1]["status"] == "done"
    assert days_after2[1]["quiz_score"] == 3
    assert days_after2[2]["status"] == "current"
    print(f"[PASS] Day 2 is 'done' (score=3), Day 3 is unlocked as 'current'.")

if __name__ == '__main__':
    test_learning_path()
    print("\nALL LEARNING PATH TESTS PASSED SUCCESSFULLY!")
