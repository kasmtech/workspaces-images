"""
Coeadapt Computer-Use Service — runs inside the Kasm VM.

Provides a lightweight HTTP API on 127.0.0.1:7701 for full computer
control: mouse movement, clicks, keyboard input, screenshots, and
window management. Designed to be called by the MCP server on the
host via `docker exec curl ...` or direct HTTP.

Requires: xdotool, xwd/import (imagemagick), xdpyinfo
"""

import base64
import json
import os
import subprocess
import tempfile
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

DISPLAY = os.environ.get("DISPLAY", ":1")


# ---------------------------------------------------------------------------
# Low-level X11 helpers (via xdotool / xprop / xwininfo)
# ---------------------------------------------------------------------------

def _run(cmd: list[str], timeout: int = 10) -> tuple[str, str, int]:
    """Run a subprocess and return (stdout, stderr, returncode)."""
    env = {**os.environ, "DISPLAY": DISPLAY}
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, env=env
        )
        return proc.stdout.strip(), proc.stderr.strip(), proc.returncode
    except subprocess.TimeoutExpired:
        return "", "timeout", 1
    except FileNotFoundError:
        return "", f"command not found: {cmd[0]}", 127


def screenshot_png() -> bytes | None:
    """Capture the entire screen as PNG bytes."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        path = f.name
    try:
        # Try import (ImageMagick) first
        stdout, stderr, rc = _run(["import", "-window", "root", path])
        if rc != 0:
            # Fallback: xwd -> convert
            xwd_path = path.replace(".png", ".xwd")
            _run(["xwd", "-root", "-out", xwd_path])
            _run(["convert", xwd_path, path])
            if os.path.exists(xwd_path):
                os.unlink(xwd_path)
        if os.path.exists(path) and os.path.getsize(path) > 0:
            with open(path, "rb") as f:
                return f.read()
        return None
    finally:
        if os.path.exists(path):
            os.unlink(path)


def screenshot_region_png(x: int, y: int, w: int, h: int) -> bytes | None:
    """Capture a specific region of the screen."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        path = f.name
    try:
        geometry = f"{w}x{h}+{x}+{y}"
        _run(["import", "-window", "root", "-crop", geometry, path])
        if os.path.exists(path) and os.path.getsize(path) > 0:
            with open(path, "rb") as f:
                return f.read()
        return None
    finally:
        if os.path.exists(path):
            os.unlink(path)


def get_screen_size() -> tuple[int, int]:
    """Return (width, height) of the primary display."""
    stdout, _, rc = _run(["xdpyinfo"])
    if rc == 0:
        for line in stdout.splitlines():
            if "dimensions:" in line:
                # e.g. "  dimensions:    1920x1080 pixels (508x285 millimeters)"
                dim = line.split("dimensions:")[1].strip().split()[0]
                w, h = dim.split("x")
                return int(w), int(h)
    return 1920, 1080  # Default fallback


def mouse_move(x: int, y: int) -> tuple[str, int]:
    stdout, stderr, rc = _run(["xdotool", "mousemove", str(x), str(y)])
    return stderr if rc else "ok", rc


def mouse_click(button: int = 1) -> tuple[str, int]:
    stdout, stderr, rc = _run(["xdotool", "click", str(button)])
    return stderr if rc else "ok", rc


def mouse_double_click(button: int = 1) -> tuple[str, int]:
    stdout, stderr, rc = _run(["xdotool", "click", "--repeat", "2", "--delay", "100", str(button)])
    return stderr if rc else "ok", rc


def mouse_down(button: int = 1) -> tuple[str, int]:
    stdout, stderr, rc = _run(["xdotool", "mousedown", str(button)])
    return stderr if rc else "ok", rc


def mouse_up(button: int = 1) -> tuple[str, int]:
    stdout, stderr, rc = _run(["xdotool", "mouseup", str(button)])
    return stderr if rc else "ok", rc


def mouse_scroll(direction: str = "down", clicks: int = 3) -> tuple[str, int]:
    btn = "5" if direction == "down" else "4"
    stdout, stderr, rc = _run(["xdotool", "click", "--repeat", str(clicks), btn])
    return stderr if rc else "ok", rc


def get_mouse_position() -> tuple[int, int]:
    stdout, _, rc = _run(["xdotool", "getmouselocation"])
    if rc == 0:
        # "x:123 y:456 screen:0 window:12345678"
        parts = dict(p.split(":") for p in stdout.split() if ":" in p)
        return int(parts.get("x", 0)), int(parts.get("y", 0))
    return 0, 0


def key_type(text: str) -> tuple[str, int]:
    """Type text using xdotool, handling special characters."""
    stdout, stderr, rc = _run(["xdotool", "type", "--clearmodifiers", "--delay", "12", text])
    return stderr if rc else "ok", rc


def key_press(keys: str) -> tuple[str, int]:
    """Press a key combination like 'ctrl+c', 'Return', 'alt+F4'."""
    stdout, stderr, rc = _run(["xdotool", "key", "--clearmodifiers", keys])
    return stderr if rc else "ok", rc


def key_down(key: str) -> tuple[str, int]:
    stdout, stderr, rc = _run(["xdotool", "keydown", key])
    return stderr if rc else "ok", rc


def key_up(key: str) -> tuple[str, int]:
    stdout, stderr, rc = _run(["xdotool", "keyup", key])
    return stderr if rc else "ok", rc


def get_active_window() -> dict:
    """Get info about the currently active window."""
    stdout, _, rc = _run(["xdotool", "getactivewindow"])
    if rc != 0:
        return {"error": "no active window"}
    window_id = stdout.strip()

    name_out, _, _ = _run(["xdotool", "getactivewindow", "getwindowname"])
    geo_out, _, _ = _run(["xdotool", "getactivewindow", "getwindowgeometry"])

    result = {"id": window_id, "name": name_out}
    if geo_out:
        for line in geo_out.splitlines():
            if "Position:" in line:
                pos = line.split("Position:")[1].strip().split("(")[0].strip()
                x, y = pos.split(",")
                result["x"] = int(x)
                result["y"] = int(y)
            if "Geometry:" in line:
                geo = line.split("Geometry:")[1].strip()
                w, h = geo.split("x")
                result["width"] = int(w)
                result["height"] = int(h)
    return result


def list_windows() -> list[dict]:
    """List all visible windows."""
    stdout, _, rc = _run(["xdotool", "search", "--onlyvisible", "--name", ""])
    if rc != 0:
        return []
    windows = []
    for wid in stdout.splitlines():
        wid = wid.strip()
        if not wid:
            continue
        name_out, _, _ = _run(["xdotool", "getwindowname", wid])
        if name_out:
            windows.append({"id": wid, "name": name_out})
    return windows[:50]  # Cap to avoid huge responses


def focus_window(window_id: str) -> tuple[str, int]:
    stdout, stderr, rc = _run(["xdotool", "windowactivate", window_id])
    return stderr if rc else "ok", rc


def drag(x1: int, y1: int, x2: int, y2: int) -> tuple[str, int]:
    """Click-drag from (x1,y1) to (x2,y2)."""
    _run(["xdotool", "mousemove", str(x1), str(y1)])
    _run(["xdotool", "mousedown", "1"])
    _run(["xdotool", "mousemove", "--delay", "10", str(x2), str(y2)])
    stdout, stderr, rc = _run(["xdotool", "mouseup", "1"])
    return stderr if rc else "ok", rc


# ---------------------------------------------------------------------------
# HTTP handler
# ---------------------------------------------------------------------------

class ComputerUseHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        pass

    def _json(self, status: int, body: dict):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _image(self, data: bytes):
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length))

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/")

        if path == "/health":
            self._json(200, {"status": "ok", "service": "computer-use"})
            return

        if path == "/screen/size":
            w, h = get_screen_size()
            self._json(200, {"width": w, "height": h})
            return

        if path == "/screen/screenshot":
            data = screenshot_png()
            if data:
                b64 = base64.b64encode(data).decode()
                self._json(200, {"image": b64, "format": "png"})
            else:
                self._json(500, {"error": "screenshot failed"})
            return

        if path == "/mouse/position":
            x, y = get_mouse_position()
            self._json(200, {"x": x, "y": y})
            return

        if path == "/window/active":
            self._json(200, get_active_window())
            return

        if path == "/window/list":
            self._json(200, {"windows": list_windows()})
            return

        self._json(404, {"error": "not found"})

    def do_POST(self):
        path = self.path.rstrip("/")
        body = self._body()

        if path == "/screen/screenshot":
            if "x" in body and "y" in body and "width" in body and "height" in body:
                data = screenshot_region_png(
                    body["x"], body["y"], body["width"], body["height"]
                )
            else:
                data = screenshot_png()
            if data:
                b64 = base64.b64encode(data).decode()
                self._json(200, {"image": b64, "format": "png"})
            else:
                self._json(500, {"error": "screenshot failed"})
            return

        if path == "/mouse/move":
            x, y = body.get("x", 0), body.get("y", 0)
            msg, rc = mouse_move(x, y)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/mouse/click":
            button = body.get("button", 1)
            msg, rc = mouse_click(button)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/mouse/double_click":
            button = body.get("button", 1)
            msg, rc = mouse_double_click(button)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/mouse/down":
            button = body.get("button", 1)
            msg, rc = mouse_down(button)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/mouse/up":
            button = body.get("button", 1)
            msg, rc = mouse_up(button)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/mouse/scroll":
            direction = body.get("direction", "down")
            clicks = body.get("clicks", 3)
            msg, rc = mouse_scroll(direction, clicks)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/mouse/drag":
            msg, rc = drag(
                body.get("x1", 0), body.get("y1", 0),
                body.get("x2", 0), body.get("y2", 0),
            )
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/keyboard/type":
            text = body.get("text", "")
            msg, rc = key_type(text)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/keyboard/press":
            keys = body.get("keys", "Return")
            msg, rc = key_press(keys)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/keyboard/down":
            key = body.get("key", "")
            msg, rc = key_down(key)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/keyboard/up":
            key = body.get("key", "")
            msg, rc = key_up(key)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        if path == "/window/focus":
            wid = body.get("window_id", "")
            msg, rc = focus_window(wid)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        # Composite action: move + click in one call
        if path == "/action/click_at":
            x, y = body.get("x", 0), body.get("y", 0)
            button = body.get("button", 1)
            mouse_move(x, y)
            time.sleep(0.05)
            msg, rc = mouse_click(button)
            self._json(200 if rc == 0 else 500, {"result": msg, "x": x, "y": y})
            return

        # Composite action: move + double-click
        if path == "/action/double_click_at":
            x, y = body.get("x", 0), body.get("y", 0)
            mouse_move(x, y)
            time.sleep(0.05)
            msg, rc = mouse_double_click()
            self._json(200 if rc == 0 else 500, {"result": msg, "x": x, "y": y})
            return

        # Composite action: move + type text (click at location, then type)
        if path == "/action/type_at":
            x, y = body.get("x", 0), body.get("y", 0)
            text = body.get("text", "")
            mouse_move(x, y)
            time.sleep(0.05)
            mouse_click(1)
            time.sleep(0.1)
            msg, rc = key_type(text)
            self._json(200 if rc == 0 else 500, {"result": msg})
            return

        self._json(404, {"error": "not found"})


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    host = "127.0.0.1"
    port = 7701
    server = HTTPServer((host, port), ComputerUseHandler)
    print(f"Computer-use service listening on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()
