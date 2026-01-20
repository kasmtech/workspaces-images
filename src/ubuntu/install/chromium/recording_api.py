#!/usr/bin/env python3
"""
Lightweight recording control API for the Chromium image.

Endpoints:
 - POST /record/start  -> start a new recording (returns UUID)
 - POST /record/stop   -> stop a recording (requires UUID in body)
 - GET  /record/file   -> download a recording (use ?uuid=... or ?name=...)
 - GET  /record/status -> current recorder status

Each recording session is identified by a unique UUID.
"""
import argparse
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import time
import uuid
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

# Detect operating system
IS_MACOS = platform.system() == "Darwin"
IS_LINUX = platform.system() == "Linux"


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
    """Simple ffmpeg-based screen recorder. Supports Linux (x11grab) and macOS (avfoundation)."""

    def __init__(self, display, recording_dir, default_size, default_fps, capture_input=None):
        self.display = display  # X11 display for Linux
        self.capture_input = capture_input  # avfoundation input for macOS (e.g., "1:none")
        self.recording_dir = recording_dir
        self.default_size = default_size
        self.default_fps = default_fps
        self.process = None
        self.current_file = None
        self.last_file = None
        # UUID-based recording management
        # Format: {uuid: {"process": process, "file": file_path, "video_size": size, "framerate": fps}}
        self.recordings = {}
        self.current_uuid = None
        # Platform info
        self.platform = "macos" if IS_MACOS else "linux"

    def is_running(self, recording_uuid=None):
        if recording_uuid:
            if recording_uuid not in self.recordings:
                return False
            rec = self.recordings[recording_uuid]
            process = rec.get("process")
            return process is not None and process.poll() is None
        # Backward compatibility: check current recording
        return self.process is not None and self.process.poll() is None

    def start(self, video_size=None, framerate=None, filename=None):
        if self.is_running():
            raise RuntimeError("Recording already in progress")

        if not shutil.which("ffmpeg"):
            raise RuntimeError("ffmpeg is not available in PATH")

        os.makedirs(self.recording_dir, exist_ok=True)
        
        # Clean up old recording files to avoid disk bloat
        self._cleanup_old_recordings()

        if not video_size:
            video_size = self._detect_resolution() or self.default_size

        if "x" not in video_size:
            raise RuntimeError("video_size must be formatted as WIDTHxHEIGHT")

        framerate = int(framerate or self.default_fps)
        
        # Generate unique UUID for this recording
        recording_uuid = str(uuid.uuid4())
        
        ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        # Include UUID in filename if not provided
        if filename:
            name = filename
        else:
            name = f"recording-{recording_uuid[:8]}-{ts}.mp4"
        target = os.path.join(self.recording_dir, name)

        # Build ffmpeg command based on platform
        cmd = self._build_ffmpeg_cmd(video_size, framerate, target)

        # Start the ffmpeg process detached from stdin to avoid blocking.
        process = subprocess.Popen(
            cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        
        # Store recording info with UUID
        self.recordings[recording_uuid] = {
            "process": process,
            "file": target,
            "video_size": video_size,
            "framerate": framerate,
        }
        
        # Update current recording (for backward compatibility)
        self.process = process
        self.current_file = target
        self.current_uuid = recording_uuid
        
        return recording_uuid, target, video_size, framerate

    def _build_ffmpeg_cmd(self, video_size, framerate, target):
        """Build ffmpeg command based on platform."""
        if IS_MACOS:
            # macOS: use avfoundation
            # capture_input format: "video_device:audio_device" e.g., "1:none" or "0:none"
            capture_input = self.capture_input or "1:none"
            return [
                "ffmpeg",
                "-y",
                "-f", "avfoundation",
                "-framerate", str(framerate),
                "-capture_cursor", "1",  # Capture mouse cursor
                "-i", capture_input,
                "-vf", f"scale={video_size.replace('x', ':')}",  # Scale to desired size
                "-codec:v", "libx264",
                "-preset", "ultrafast",
                "-pix_fmt", "yuv420p",
                target,
            ]
        else:
            # Linux: use x11grab
            return [
                "ffmpeg",
                "-y",
                "-video_size", video_size,
                "-framerate", str(framerate),
                "-f", "x11grab",
                "-i", self.display,
                "-codec:v", "libx264",
                "-preset", "ultrafast",
                "-pix_fmt", "yuv420p",
                target,
            ]

    def stop(self, recording_uuid=None):
        # If UUID provided, use it; otherwise use current recording
        if recording_uuid:
            if recording_uuid not in self.recordings:
                raise RuntimeError(f"Recording with UUID {recording_uuid} not found")
            rec = self.recordings[recording_uuid]
            process = rec["process"]
            finished_file = rec["file"]
            
            if process is None or process.poll() is not None:
                raise RuntimeError(f"Recording with UUID {recording_uuid} is not running")
        else:
            # Backward compatibility: use current recording
            if not self.is_running():
                raise RuntimeError("No active recording")
            process = self.process
            finished_file = self.current_file
            recording_uuid = self.current_uuid
        
        # Send SIGINT to gracefully stop ffmpeg
        process.send_signal(signal.SIGINT)
        try:
            process.wait(timeout=10)  # Increased timeout for file finalization
        except subprocess.TimeoutExpired:
            # If graceful shutdown fails, force kill
            process.kill()
            process.wait(timeout=5)

        # Wait for file to be finalized and verify it exists
        max_wait = 3  # Maximum seconds to wait for file
        wait_interval = 0.1  # Check every 100ms
        waited = 0
        
        while waited < max_wait:
            if finished_file and os.path.exists(finished_file):
                # Check if file is readable and has content
                try:
                    size = os.path.getsize(finished_file)
                    if size > 0:
                        # File exists and has content
                        break
                except OSError:
                    pass
            time.sleep(wait_interval)
            waited += wait_interval
        
        # Verify the file exists and is readable
        if not finished_file or not os.path.exists(finished_file):
            raise RuntimeError(f"Recording file not found: {finished_file}")
        
        try:
            file_size = os.path.getsize(finished_file)
            if file_size == 0:
                raise RuntimeError(f"Recording file is empty: {finished_file}")
        except OSError as e:
            raise RuntimeError(f"Cannot access recording file: {e}")

        # Update recording info
        if recording_uuid and recording_uuid in self.recordings:
            self.recordings[recording_uuid]["process"] = None
            self.last_file = finished_file
        
        # Update current recording state (for backward compatibility)
        if recording_uuid == self.current_uuid:
            self.last_file = finished_file
            self.process = None
            self.current_file = None
            self.current_uuid = None
        
        # Ensure we always return a UUID (even if None for backward compatibility)
        return recording_uuid, finished_file

    def get_file_by_uuid(self, recording_uuid):
        """Get recording file path by UUID."""
        if recording_uuid not in self.recordings:
            return None
        rec = self.recordings[recording_uuid]
        file_path = rec.get("file")
        if file_path and os.path.exists(file_path):
            return file_path
        return None

    def _cleanup_old_recordings(self):
        """Clean up old recording files to avoid disk bloat.
        
        Removes files from completed recordings (where process is None or exited).
        Keeps the last_file for potential download.
        """
        uuids_to_remove = []
        
        for rec_uuid, rec_info in self.recordings.items():
            process = rec_info.get("process")
            file_path = rec_info.get("file")
            
            # Skip if recording is still running
            if process is not None and process.poll() is None:
                continue
            
            # Skip the last finished file (user might want to download it)
            if file_path == self.last_file:
                continue
            
            # Delete the file if it exists
            if file_path and os.path.exists(file_path):
                try:
                    os.remove(file_path)
                except OSError:
                    pass  # Ignore errors during cleanup
            
            uuids_to_remove.append(rec_uuid)
        
        # Remove cleaned up recordings from the dictionary
        for rec_uuid in uuids_to_remove:
            del self.recordings[rec_uuid]

    def _detect_resolution(self):
        """Best-effort detection of the current display resolution."""
        if IS_MACOS:
            return self._detect_resolution_macos()
        else:
            return self._detect_resolution_linux()

    def _detect_resolution_macos(self):
        """Detect screen resolution on macOS using system_profiler."""
        try:
            # Use system_profiler to get display info
            probe = subprocess.check_output(
                ["system_profiler", "SPDisplaysDataType"],
                stderr=subprocess.DEVNULL
            ).decode()
            for line in probe.splitlines():
                # Look for resolution line like "Resolution: 2560 x 1440"
                if "Resolution:" in line and "x" in line.lower():
                    parts = line.split(":")
                    if len(parts) >= 2:
                        res_part = parts[1].strip()
                        # Parse "2560 x 1440 (QHD/WQHD...)" or "2560 x 1440"
                        res_match = res_part.split()
                        if len(res_match) >= 3 and res_match[1].lower() == "x":
                            width = res_match[0].strip()
                            height = res_match[2].strip().split()[0]  # Remove any trailing text
                            # Remove non-digit characters
                            width = ''.join(filter(str.isdigit, width))
                            height = ''.join(filter(str.isdigit, height))
                            if width and height:
                                return f"{width}x{height}"
        except Exception:
            pass
        
        # Fallback: try using screenresolution if available
        try:
            if shutil.which("screenresolution"):
                probe = subprocess.check_output(
                    ["screenresolution", "get"],
                    stderr=subprocess.DEVNULL
                ).decode()
                # Output format: "Display 0: 2560x1440x32@60Hz"
                for line in probe.splitlines():
                    if "x" in line:
                        parts = line.split()
                        for part in parts:
                            if "x" in part and part[0].isdigit():
                                # Extract WIDTHxHEIGHT from "2560x1440x32@60Hz"
                                dims = part.split("x")
                                if len(dims) >= 2:
                                    return f"{dims[0]}x{dims[1]}"
        except Exception:
            pass
        
        return None

    def _detect_resolution_linux(self):
        """Detect screen resolution on Linux using xdpyinfo."""
        try:
            # Preserve existing environment and set/override DISPLAY
            env = os.environ.copy()
            env["DISPLAY"] = self.display
            
            probe = subprocess.check_output(
                ["xdpyinfo"], env=env, stderr=subprocess.DEVNULL
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
                recording_uuid, target, video_size, fps = recorder.start(
                    video_size=payload.get("video_size"),
                    framerate=payload.get("framerate"),
                    filename=payload.get("filename"),
                )
            except Exception as exc:
                _fail(self, HTTPStatus.CONFLICT, str(exc))
                return

            response = {
                "uuid": recording_uuid,
                "file": target,
                "video_size": video_size,
                "framerate": fps,
                "recording_dir": recorder.recording_dir,
                "platform": recorder.platform,
            }
            # Add platform-specific capture info
            if IS_MACOS:
                response["capture_input"] = recorder.capture_input
            else:
                response["display"] = recorder.display
            
            _safe_json(self, HTTPStatus.OK, response)

        def _handle_stop(self):
            payload = self._read_json()
            recording_uuid = payload.get("uuid") if payload else None
            
            try:
                uuid_result, finished = recorder.stop(recording_uuid=recording_uuid)
            except Exception as exc:
                _fail(self, HTTPStatus.CONFLICT, str(exc))
                return

            # Get file information
            file_info = {
                "uuid": uuid_result,
                "file": finished
            }
            try:
                if os.path.exists(finished):
                    file_info["size"] = os.path.getsize(finished)
                    file_info["exists"] = True
                else:
                    file_info["exists"] = False
            except Exception:
                file_info["exists"] = False

            _safe_json(self, HTTPStatus.OK, file_info)

        def _handle_status(self):
            status = {
                "recording": recorder.is_running(),
                "current_uuid": recorder.current_uuid,
                "current_file": recorder.current_file,
                "last_file": recorder.last_file,
                "recording_dir": recorder.recording_dir,
                "platform": recorder.platform,
            }
            # Add platform-specific capture info
            if IS_MACOS:
                status["capture_input"] = recorder.capture_input
            else:
                status["display"] = recorder.display
            
            _safe_json(self, HTTPStatus.OK, status)

        def _handle_file(self, parsed):
            params = parse_qs(parsed.query)
            recording_uuid = params.get("uuid", [None])[0]
            name = params.get("name", [None])[0]
            target = None

            # Priority: uuid > name > last_file
            if recording_uuid:
                target = recorder.get_file_by_uuid(recording_uuid)
            elif name:
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
    
    # Determine default recording directory based on platform
    default_recording_dir = (
        os.path.expanduser("~/recordings") if IS_MACOS
        else os.environ.get("RECORDINGS_DIR", "/home/kasm-user/recordings")
    )
    parser.add_argument(
        "--recording-dir",
        default=os.environ.get("RECORDINGS_DIR", default_recording_dir),
        help="Directory to store recordings",
    )
    parser.add_argument(
        "--display",
        default=os.environ.get("DISPLAY", ":1"),
        help="X11 display to record (Linux only, e.g. :1)",
    )
    parser.add_argument(
        "--capture-input",
        default=os.environ.get("CAPTURE_INPUT", "2:none"),
        help="macOS avfoundation capture input (e.g. '2:none' for screen without audio). Use 'ffmpeg -f avfoundation -list_devices true -i \"\"' to list devices.",
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
        capture_input=args.capture_input,
    )

    server = ThreadingHTTPServer((args.host, args.port), build_handler(recorder))
    
    # Platform-specific info in startup message
    if IS_MACOS:
        capture_info = f"capture_input={recorder.capture_input}"
    else:
        capture_info = f"display={recorder.display}"
    
    print(
        f"[recording_api] listening on {args.host}:{args.port}, "
        f"platform={recorder.platform}, {capture_info}, dir={recorder.recording_dir}",
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
