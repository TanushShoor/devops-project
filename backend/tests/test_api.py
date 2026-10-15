from datetime import date, timedelta


def test_health(client):
    assert client.get("/health").json() == {"status": "UP"}


def test_root_identifies_study_planner(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "Study Planner API"


def test_create_and_list_assignment(client):
    response = client.post(
        "/api/assignments",
        json={
            "title": "Read chapter 4",
            "course": "Biology",
            "due_date": str(date.today() + timedelta(days=2)),
        },
    )
    assert response.status_code == 201
    assert response.json()["course"] == "Biology"
    assert client.get("/api/assignments").json()[0]["title"] == "Read chapter 4"


def test_update_assignment_and_stats(client):
    assignment_id = client.post(
        "/api/assignments", json={"title": "Essay", "course": "History"}
    ).json()["id"]
    updated = client.put(
        f"/api/assignments/{assignment_id}", json={"status": "DONE"}
    )
    assert updated.status_code == 200
    assert updated.json()["status"] == "DONE"
    stats = client.get("/api/assignments/stats").json()
    assert stats["total"] == 1
    assert stats["done"] == 1


def test_delete_assignment(client):
    assignment_id = client.post(
        "/api/assignments", json={"title": "Quiz prep", "course": "Chemistry"}
    ).json()["id"]
    assert client.delete(f"/api/assignments/{assignment_id}").status_code == 204
    assert client.get(f"/api/assignments/{assignment_id}").status_code == 404


def test_reject_invalid_priority(client):
    response = client.post(
        "/api/assignments",
        json={"title": "Lab report", "course": "Physics", "priority": "URGENT"},
    )
    assert response.status_code == 422
