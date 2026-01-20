#!/usr/bin/env python3
"""
Lightweight recording control API for the Chromium image.

Endpoints:
 - POST /record/start  -> start a new recording
 - POST /record/stop   -> stop the current recording
 - GET  /record/file   -> download a recording (defaults to last finished)
 - GET  /record/status -> current recorder status
"""
import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


def _safe_json(handler, status, payload):
    body = json.dumps(payload or {}).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _fail(handler, status, message):
    _safe_json(handler, status, {"error": message})


class Recorder:
    """Simple ffmpeg-based screen recorder."""

    def __init__(self, display, recording_dir, default_size, default_fps):
        self.display = display
        self.recording_dir = recording_dir
        self.default_size = default_size
        self.default_fps = default_fps
        self.process = None
        self.current_file = None
        self.last_file = None

    def is_running(self):
        return self.process is not None and self.process.poll() is None

    def start(self, video_size=None, framerate=None, filename=None):
        if self.is_running():
            raise RuntimeError("Recording already in progress")

        if not shutil.which("ffmpeg"):
            raise RuntimeError("ffmpeg is not available in PATH")

        os.makedirs(self.recording_dir, exist_ok=True)

        if not video_size:
            video_size = self._detect_resolution() or self.default_size

        if "x" not in video_size:
            raise RuntimeError("video_size must be formatted as WIDTHxHEIGHT")

        framerate = int(framerate or self.default_fps)
        ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        name = filename or f"recording-{ts}.mp4"
        target = os.path.join(self.recording_dir, name)

        cmd = [
            "ffmpeg",
            "-y",
            "-video_size",
            video_size,
            "-framerate",
            str(framerate),
            "-f",
            "x11grab",
            "-i",
            self.display,
            "-codec:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-pix_fmt",
            "yuv420p",
            target,
        ]

        # Start the ffmpeg process detached from stdin to avoid blocking.
        self.process = subprocess.Popen(
            cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        self.current_file = target
        return target, video_size, framerate

    def stop(self):
        if not self.is_running():
            raise RuntimeError("No active recording")

        self.process.send_signal(signal.SIGINT)
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)

        finished_file = self.current_file
        self.last_file = finished_file
        self.process = None
        self.current_file = None
        return finished_file

    def _detect_resolution(self):
        """Best-effort detection of the current X display resolution."""
        try:
            probe = subprocess.check_output(
                ["xdpyinfo"], env={"DISPLAY": self.display}, stderr=subprocess.DEVNULL
            ).decode()
            for line in probe.splitlines():
                if "dimensions:" in line:
                    parts = line.strip().split()
                    # dimensions:    1920x1080 pixels ...
                    if len(parts) >= 2:
                        return parts[1]
        except Exception:
            return None
        return None


def build_handler(recorder):
    class Handler(BaseHTTPRequestHandler):
        server_version = "RecordingAPI/1.0"
        protocol_version = "HTTP/1.1"

        def log_message(self, fmt, *args):
            # Keep stdout clean for other services.
            return

        def do_GET(self):
            parsed = urlparse(self.path)
            if parsed.path == "/record/status":
                self._handle_status()
            elif parsed.path == "/record/file":
                self._handle_file(parsed)
            else:
                _fail(self, HTTPStatus.NOT_FOUND, "Endpoint not found")

        def do_POST(self):
            parsed = urlparse(self.path)
            if parsed.path == "/record/start":
                self._handle_start()
            elif parsed.path == "/record/stop":
                self._handle_stop()
            else:
                _fail(self, HTTPStatus.NOT_FOUND, "Endpoint not found")

        def _read_json(self):
            length = int(self.headers.get("Content-Length", 0))
            if not length:
                return {}
            try:
                return json.loads(self.rfile.read(length))
            except Exception:
                return {}

        def _handle_start(self):
            payload = self._read_json()
            try:
                target, video_size, fps = recorder.start(
                    video_size=payload.get("video_size"),
                    framerate=payload.get("framerate"),
                    filename=payload.get("filename"),
                )
            except Exception as exc:
                _fail(self, HTTPStatus.CONFLICT, str(exc))
                return

            _safe_json(
                self,
                HTTPStatus.OK,
                {
                    "file": target,
                    "video_size": video_size,
                    "framerate": fps,
                    "display": recorder.display,
                    "recording_dir": recorder.recording_dir,
                },
            )

        def _handle_stop(self):
            try:
                finished = recorder.stop()
            except Exception as exc:
                _fail(self, HTTPStatus.CONFLICT, str(exc))
                return

            _safe_json(self, HTTPStatus.OK, {"file": finished})

        def _handle_status(self):
            _safe_json(
                self,
                HTTPStatus.OK,
                {
                    "recording": recorder.is_running(),
                    "current_file": recorder.current_file,
                    "last_file": recorder.last_file,
                    "display": recorder.display,
                    "recording_dir": recorder.recording_dir,
                },
            )

        def _handle_file(self, parsed):
            params = parse_qs(parsed.query)
            name = params.get("name", [None])[0]
            target = None

            if name:
                target = (
                    name
                    if os.path.isabs(name)
                    else os.path.join(recorder.recording_dir, name)
                )
            elif recorder.last_file:
                target = recorder.last_file

            if not target or not os.path.exists(target):
                _fail(self, HTTPStatus.NOT_FOUND, "Recording not found")
                return

            try:
                size = os.path.getsize(target)
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "video/mp4")
                self.send_header("Content-Length", str(size))
                self.end_headers()
                with open(target, "rb") as f:
                    shutil.copyfileobj(f, self.wfile)
            except Exception as exc:
                _fail(self, HTTPStatus.INTERNAL_SERVER_ERROR, str(exc))

    return Handler


def parse_args():
    parser = argparse.ArgumentParser(description="Simple recording control API server")
    parser.add_argument("--host", default="0.0.0.0", help="Listening interface")
    parser.add_argument("--port", type=int, default=18080, help="Listening port")
    parser.add_argument(
        "--recording-dir",
        default=os.environ.get("RECORDINGS_DIR", "/home/kasm-user/recordings"),
        help="Directory to store recordings",
    )
    parser.add_argument(
        "--display",
        default=os.environ.get("DISPLAY", ":1"),
        help="X11 display to record (e.g. :1)",
    )
    parser.add_argument(
        "--video-size",
        default=os.environ.get("RECORDING_SIZE", "1920x1080"),
        help="Default video size when none provided (WIDTHxHEIGHT)",
    )
    parser.add_argument(
        "--framerate",
        type=int,
        default=int(os.environ.get("RECORDING_FPS", 25)),
        help="Default framerate when none provided",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    recorder = Recorder(
        display=args.display,
        recording_dir=args.recording_dir,
        default_size=args.video_size,
        default_fps=args.framerate,
    )

    server = ThreadingHTTPServer((args.host, args.port), build_handler(recorder))
    print(
        f"[recording_api] listening on {args.host}:{args.port}, "
        f"display={recorder.display}, dir={recorder.recording_dir}",
        flush=True,
    )

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        if recorder.is_running():
            try:
                recorder.stop()
            except Exception:
                pass


if __name__ == "__main__":
    sys.exit(main())
