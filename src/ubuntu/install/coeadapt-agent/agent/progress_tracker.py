"""
Coeadapt Progress Tracker — runs inside the Kasm VM.

Maintains a local JSON store of the user's career development activities,
assessments, goals, and skill evidence. Exposes a lightweight HTTP API
on 127.0.0.1:7700 that the MCP server (running on the host) reaches
via `docker exec` or port-forward.

Data is persisted to ~/.coeadapt/progress.json so it survives container
restarts (volume-mounted home directory).
"""

import json
import os
import time
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from datetime import datetime, timezone

DATA_DIR = Path.home() / ".coeadapt"
PROGRESS_FILE = DATA_DIR / "progress.json"
LOCK = threading.Lock()

# ---------------------------------------------------------------------------
# Data helpers
# ---------------------------------------------------------------------------

def _default_data() -> dict:
    return {
        "version": 1,
        "activities": [],
        "assessments": [],
        "goals": [],
        "skills": [],
        "milestones": [],
        "daily_log": [],
        "progress_percent": 0,
        "streak_days": 0,
        "last_activity_at": None,
        "created_at": _now(),
        "updated_at": _now(),
    }


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load() -> dict:
    if PROGRESS_FILE.exists():
        try:
            return json.loads(PROGRESS_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return _default_data()


def _save(data: dict) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    data["updated_at"] = _now()
    tmp = PROGRESS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2))
    tmp.replace(PROGRESS_FILE)


def _next_id(items: list) -> int:
    if not items:
        return 1
    return max(item.get("id", 0) for item in items) + 1


def _recalc_progress(data: dict) -> None:
    """Recalculate overall progress_percent from goals and milestones."""
    goals = data.get("goals", [])
    if not goals:
        data["progress_percent"] = 0
        return
    completed = sum(1 for g in goals if g.get("status") == "completed")
    data["progress_percent"] = round((completed / len(goals)) * 100)


def _update_streak(data: dict) -> None:
    """Update streak_days based on daily_log entries."""
    log = data.get("daily_log", [])
    if not log:
        data["streak_days"] = 0
        return
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    dates = sorted(set(entry.get("date", "") for entry in log), reverse=True)
    if not dates or dates[0] != today:
        # Check if yesterday is present (still counts)
        from datetime import timedelta
        yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%d")
        if not dates or dates[0] != yesterday:
            data["streak_days"] = 0
            return
    streak = 0
    from datetime import timedelta
    check_date = datetime.now(timezone.utc).date()
    date_set = set(dates)
    while check_date.strftime("%Y-%m-%d") in date_set:
        streak += 1
        check_date -= timedelta(days=1)
    data["streak_days"] = streak


# ---------------------------------------------------------------------------
# HTTP request handler
# ---------------------------------------------------------------------------

class ProgressHandler(BaseHTTPRequestHandler):
    """Minimal JSON API for progress tracking."""

    def log_message(self, format, *args):
        # Quiet logging
        pass

    def _json_response(self, status: int, body: dict) -> None:
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw)

    # --- Routing ---

    def do_GET(self):
        path = self.path.rstrip("/")

        if path == "/health":
            self._json_response(200, {"status": "ok", "uptime": time.monotonic()})
            return

        if path == "/progress":
            with LOCK:
                data = _load()
            self._json_response(200, data)
            return

        if path == "/progress/summary":
            with LOCK:
                data = _load()
            summary = {
                "progress_percent": data.get("progress_percent", 0),
                "streak_days": data.get("streak_days", 0),
                "total_activities": len(data.get("activities", [])),
                "total_goals": len(data.get("goals", [])),
                "completed_goals": sum(
                    1 for g in data.get("goals", []) if g.get("status") == "completed"
                ),
                "total_skills": len(data.get("skills", [])),
                "total_milestones": len(data.get("milestones", [])),
                "last_activity_at": data.get("last_activity_at"),
            }
            self._json_response(200, summary)
            return

        if path == "/progress/activities":
            with LOCK:
                data = _load()
            self._json_response(200, {"activities": data.get("activities", [])})
            return

        if path == "/progress/goals":
            with LOCK:
                data = _load()
            self._json_response(200, {"goals": data.get("goals", [])})
            return

        if path == "/progress/skills":
            with LOCK:
                data = _load()
            self._json_response(200, {"skills": data.get("skills", [])})
            return

        if path == "/progress/milestones":
            with LOCK:
                data = _load()
            self._json_response(200, {"milestones": data.get("milestones", [])})
            return

        self._json_response(404, {"error": "not found"})

    def do_POST(self):
        path = self.path.rstrip("/")

        if path == "/progress/activities":
            body = self._read_body()
            with LOCK:
                data = _load()
                activity = {
                    "id": _next_id(data["activities"]),
                    "type": body.get("type", "general"),
                    "title": body.get("title", "Untitled"),
                    "description": body.get("description", ""),
                    "duration_minutes": body.get("duration_minutes", 0),
                    "tags": body.get("tags", []),
                    "metadata": body.get("metadata", {}),
                    "created_at": _now(),
                }
                data["activities"].append(activity)
                data["last_activity_at"] = activity["created_at"]
                # Log daily entry
                today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
                data.setdefault("daily_log", [])
                data["daily_log"].append({"date": today, "activity_id": activity["id"]})
                _update_streak(data)
                _save(data)
            self._json_response(201, activity)
            return

        if path == "/progress/goals":
            body = self._read_body()
            with LOCK:
                data = _load()
                goal = {
                    "id": _next_id(data["goals"]),
                    "title": body.get("title", "Untitled Goal"),
                    "description": body.get("description", ""),
                    "category": body.get("category", "general"),
                    "status": "active",
                    "target_date": body.get("target_date"),
                    "sub_goals": body.get("sub_goals", []),
                    "created_at": _now(),
                    "updated_at": _now(),
                }
                data["goals"].append(goal)
                _recalc_progress(data)
                _save(data)
            self._json_response(201, goal)
            return

        if path == "/progress/skills":
            body = self._read_body()
            with LOCK:
                data = _load()
                skill = {
                    "id": _next_id(data["skills"]),
                    "name": body.get("name", "Unknown Skill"),
                    "category": body.get("category", "general"),
                    "level": body.get("level", "beginner"),
                    "evidence": body.get("evidence", []),
                    "verified": False,
                    "created_at": _now(),
                    "updated_at": _now(),
                }
                data["skills"].append(skill)
                _save(data)
            self._json_response(201, skill)
            return

        if path == "/progress/milestones":
            body = self._read_body()
            with LOCK:
                data = _load()
                milestone = {
                    "id": _next_id(data["milestones"]),
                    "title": body.get("title", "Untitled Milestone"),
                    "description": body.get("description", ""),
                    "achieved": body.get("achieved", False),
                    "achieved_at": _now() if body.get("achieved") else None,
                    "created_at": _now(),
                }
                data["milestones"].append(milestone)
                _save(data)
            self._json_response(201, milestone)
            return

        if path == "/progress/assessments":
            body = self._read_body()
            with LOCK:
                data = _load()
                assessment = {
                    "id": _next_id(data.get("assessments", [])),
                    "type": body.get("type", "self"),
                    "skill": body.get("skill", ""),
                    "score": body.get("score", 0),
                    "max_score": body.get("max_score", 100),
                    "notes": body.get("notes", ""),
                    "created_at": _now(),
                }
                data.setdefault("assessments", []).append(assessment)
                _save(data)
            self._json_response(201, assessment)
            return

        self._json_response(404, {"error": "not found"})

    def do_PUT(self):
        path = self.path.rstrip("/")

        # PUT /progress/goals/<id>
        if path.startswith("/progress/goals/"):
            try:
                goal_id = int(path.split("/")[-1])
            except ValueError:
                self._json_response(400, {"error": "invalid goal id"})
                return
            body = self._read_body()
            with LOCK:
                data = _load()
                for goal in data.get("goals", []):
                    if goal.get("id") == goal_id:
                        for key in ("title", "description", "category", "status", "target_date"):
                            if key in body:
                                goal[key] = body[key]
                        goal["updated_at"] = _now()
                        if goal.get("status") == "completed" and not goal.get("completed_at"):
                            goal["completed_at"] = _now()
                        _recalc_progress(data)
                        _save(data)
                        self._json_response(200, goal)
                        return
            self._json_response(404, {"error": "goal not found"})
            return

        # PUT /progress/skills/<id>
        if path.startswith("/progress/skills/"):
            try:
                skill_id = int(path.split("/")[-1])
            except ValueError:
                self._json_response(400, {"error": "invalid skill id"})
                return
            body = self._read_body()
            with LOCK:
                data = _load()
                for skill in data.get("skills", []):
                    if skill.get("id") == skill_id:
                        for key in ("name", "category", "level", "evidence", "verified"):
                            if key in body:
                                skill[key] = body[key]
                        skill["updated_at"] = _now()
                        _save(data)
                        self._json_response(200, skill)
                        return
            self._json_response(404, {"error": "skill not found"})
            return

        self._json_response(404, {"error": "not found"})


# ---------------------------------------------------------------------------
# Auto-sync thread (optional platform sync)
# ---------------------------------------------------------------------------

class PlatformSyncer(threading.Thread):
    """Periodically syncs local progress to the Coeadapt platform API."""

    daemon = True

    def __init__(self, api_url: str | None = None, token: str | None = None):
        super().__init__()
        self.api_url = api_url or os.environ.get("COEADAPT_API_URL")
        self.token = token or os.environ.get("COEADAPT_TOKEN")

    def run(self):
        if not self.api_url or not self.token:
            return  # No platform configured — local-only mode
        import urllib.request
        while True:
            time.sleep(300)  # Sync every 5 minutes
            try:
                with LOCK:
                    data = _load()
                payload = json.dumps({"progress": data}).encode()
                req = urllib.request.Request(
                    f"{self.api_url}/api/career-box/sync-progress",
                    data=payload,
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {self.token}",
                    },
                    method="POST",
                )
                urllib.request.urlopen(req, timeout=10)
            except Exception:
                pass  # Best-effort sync


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Ensure progress file exists
    if not PROGRESS_FILE.exists():
        _save(_default_data())

    # Start platform syncer
    syncer = PlatformSyncer()
    syncer.start()

    host = "127.0.0.1"
    port = 7700
    server = HTTPServer((host, port), ProgressHandler)
    print(f"Progress tracker listening on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()
