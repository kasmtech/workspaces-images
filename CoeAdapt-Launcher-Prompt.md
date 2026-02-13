# CoeAdapt Launcher — Tauri v2 Application Build Prompt

## Project Overview

Build a cross-platform desktop launcher app called **CoeAdapt** using **Tauri v2** (stable). This app is the local component of the CoeAdapt career copilot platform. It manages the full lifecycle of a local Docker container running a custom Kasm Workspaces desktop image, runs an MCP (Model Context Protocol) server for AI integration, and provides a clean system tray experience. The user should never need to touch a terminal, know what Docker is, or understand containers.

**Target users:** Mid-career professionals who are NOT developers. Every interaction must be simple, guided, and error-tolerant.

### How This Fits the Bigger Product

The CoeAdapt platform has two main surfaces:

1. **This Tauri launcher** — manages the local workspace ("career box") and MCP server on the user's machine
2. **Cora at coeadapt.com/cora** — the web-based AI career companion (a ChatGPT/Claude-like chat experience with generative UI, built with Next.js + CopilotKit)

**Cora** is the primary interface users interact with. She is the AI career coach — guiding assessments, suggesting learning paths, reviewing resumes, building portfolios. The local workspace is the hands-on sandbox where users practice what Cora teaches.

The Tauri app needs to support this relationship:
- Cora (web) can see and control the local workspace via MCP
- The user's coeadapt.com dashboard shows their career box status (running/stopped/needs update)
- Auth is shared — logging into the Tauri app uses the same account as coeadapt.com
- The MCP server bridges Cora's cloud intelligence to the local workspace

```
┌──────────────────────────────────────────────────────────┐
│  coeadapt.com/cora (Web App)                             │
│  Next.js + CopilotKit + Generative UI                    │
│  "Chat with Cora" — AI career companion                  │
│  Dashboard: manage career box, view progress, billing    │
└────────────────────┬─────────────────────────────────────┘
                     │  Cloud API (api.coeadapt.com)
                     │  Auth, subscriptions, progress sync
                     │
        ┌────────────▼────────────────────────────────┐
        │  User's Machine                             │
        │                                             │
        │  ┌─────────────────────────────────────┐    │
        │  │  CoeAdapt Tauri App (system tray)   │    │
        │  │  Manages container + MCP server     │    │
        │  └──────┬──────────────┬───────────────┘    │
        │         │              │                    │
        │    ┌────▼────┐  ┌─────▼──────────┐         │
        │    │ Docker  │  │  MCP Server    │         │
        │    │Container│  │  :3100         │         │
        │    │ :6901   │  │  Cora talks    │         │
        │    │ Kasm    │  │  to this via   │         │
        │    │ Desktop │  │  cloud relay   │         │
        │    └─────────┘  └────────────────┘         │
        └─────────────────────────────────────────────┘
```

**Critical architecture note:** Cora runs in the cloud (coeadapt.com), but the MCP server runs locally (localhost:3100). For Cora to reach the local MCP server, one of these bridges is needed:
- **Option A (recommended for MVP):** User adds `localhost:3100/mcp` as a Custom Connector in their Claude settings. Cora's intelligence comes through Claude's MCP connection.
- **Option B (future):** CoeAdapt cloud API acts as a relay — the Tauri app maintains a WebSocket connection to `api.coeadapt.com`, and Cora's tool calls are proxied down to the local MCP server. No user configuration needed.
- **Option C (future):** Cloudflare Tunnel or similar exposes the local MCP server with a unique URL per user.

For this build, implement **Option A** and design the MCP server to be ready for Option B (accept connections, validate auth tokens).

---

## Tech Stack

- **Framework:** Tauri v2 (latest stable)
- **Frontend:** Vite + React + TypeScript + Tailwind CSS (do NOT use Next.js — no SSR needed, Vite is the standard Tauri pairing)
- **Backend:** Rust (Tauri commands)
- **Container runtime:** Docker Desktop (primary) or Podman Desktop (fallback)
- **Container image:** `coeadapt/workspace:latest` (custom Kasm-based image, assume it exists on Docker Hub)
- **MCP Server:** Node.js-based, bundled as a sidecar process
- **Auto-updater:** Tauri's built-in updater plugin

### Minimum System Requirements (enforce in app)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **Disk space** | 15 GB free | 25 GB+ free |
| **RAM** | 8 GB total | 16 GB+ total |
| **OS** | Windows 10 21H2+, macOS 12+, Ubuntu 22.04+ | Latest stable |
| **CPU** | 64-bit with virtualization support | 4+ cores |

The app should check these on first launch and show clear guidance if any are not met. Disk space should be monitored continuously (see Phase 2).

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│  CoeAdapt Tauri App (system tray + window)  │
│                                             │
│  ┌─────────────┐  ┌──────────────────────┐  │
│  │  React UI   │  │  Rust Backend        │  │
│  │  (Vite)     │  │  - Docker mgmt       │  │
│  │  - Status   │  │  - Container lifecycle│ │
│  │  - Settings │  │  - Health checks     │  │
│  └─────────────┘  │  - MCP sidecar mgmt  │  │
│                   └──────────────────────┘  │
└─────────────────┬───────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
   ┌────▼────┐     ┌───────▼────────┐
   │ Docker  │     │  MCP Server    │
   │Container│     │  (sidecar)     │
   │ :6901   │     │  :3100         │
   │ Kasm    │     │  Claude talks  │
   │ Desktop │     │  to this       │
   └─────────┘     └────────────────┘
```

---

## Core Features — Build in This Order

### Phase 1: Container Runtime Detection & Installation

On first launch, detect if Docker Desktop or Podman Desktop is installed.

**Detection logic (Rust):**
1. Check if `docker` CLI is available in PATH and responsive (`docker info`)
2. If not, check if `podman` CLI is available (`podman info`)
3. If neither found, enter **Setup Mode**

**Setup Mode UI (React):**
- Clean welcome screen: "Welcome to CoeAdapt. Let's get you set up."
- Show a single button: "Install Docker Desktop" (link to download page for their OS)
- Alternatively, detect OS and download the installer directly:
  - **Windows:** Download `Docker Desktop Installer.exe`, run with `install --quiet --accept-license --backend=wsl-2`
  - **macOS:** Download `.dmg`, mount and copy to Applications
  - **Linux:** Prompt to install `docker.io` via package manager
- Show progress: "Installing Docker Desktop..." with a spinner
- After install, prompt: "Docker Desktop installed. Please restart your computer if prompted, then reopen CoeAdapt."
- On next launch, re-check for Docker. If found, proceed to Phase 2.

**Disk space check (before anything else):**
1. Check available disk space on the drive where Docker stores data
   - **Windows:** `C:\` or wherever WSL2/Docker is configured
   - **macOS:** `/` (main volume)
   - **Linux:** `/var/lib/docker` partition
2. **Minimum required:** 15GB free (Docker Desktop ~3GB + workspace image ~5GB + workspace data headroom ~7GB)
3. **Recommended:** 25GB+ free
4. If below minimum, show: "CoeAdapt needs at least 15GB of free space. You currently have [X]GB available. Free up some space and try again."
5. If between minimum and recommended, show a warning but allow proceeding: "You have [X]GB free. We recommend 25GB+ for the best experience."

**Important edge cases:**
- Docker Desktop may be installed but the daemon not running → detect and show "Starting Docker..." with auto-retry
- WSL2 may not be enabled on Windows → detect and guide the user through enabling it
- Docker Desktop has a licensing requirement for companies >250 employees → show a note that Podman Desktop is a free alternative
- On Windows, WSL2 virtual disk can grow unbounded → document how to compact it in troubleshooting

**Tauri permissions needed:** `shell:allow-execute`, `shell:allow-spawn`

---

### Phase 2: Image Pull & Container Launch

Once Docker is confirmed running:

**First run:**
1. Show UI: "Downloading CoeAdapt Workspace... (this may take a few minutes on first launch)"
2. Run `docker pull coeadapt/workspace:latest` — stream progress to UI
3. Once pulled, launch container:

```bash
docker run -d \
  --name coeadapt-workspace \
  --shm-size=512m \
  -p 6901:6901 \
  -p 3100:3100 \
  -v coeadapt-data:/home/kasm-user \
  -e VNC_PW=coeadapt \
  --restart unless-stopped \
  coeadapt/workspace:latest
```

4. Health check: poll `https://localhost:6901` until it responds (KasmVNC ready)
5. Once healthy, show: "Your workspace is ready!" with a big "Open Workspace" button
6. "Open Workspace" opens the user's default browser to `https://localhost:6901`

**Subsequent runs:**
1. Check if container `coeadapt-workspace` exists (`docker ps -a --filter name=coeadapt-workspace`)
2. If exists and running → go straight to "Open Workspace"
3. If exists but stopped → `docker start coeadapt-workspace`, wait for health check
4. If doesn't exist → pull latest if needed, run new container (preserves data via volume)

**Update flow:**
- On app launch, check for image updates: `docker pull coeadapt/workspace:latest`
- If new image pulled, show: "Update available. Apply now?"
- If yes: stop container, remove it, run new container (volume `coeadapt-data` persists user files)
- After update: auto-run `docker image prune -f` to remove the old image layers (reclaims 3-5GB)
- If no: continue with current container

**Ongoing disk monitoring:**
- Check available disk space on every app launch and every 30 minutes while running
- If free space drops below 5GB, show a persistent warning banner in the dashboard
- Track workspace volume size via `docker system df -v` and surface it in Settings
- Disk usage helper commands (Rust backend):
  ```bash
  # Total Docker disk usage
  docker system df
  # Workspace volume size specifically
  docker system df -v --format '{{json .Volumes}}' | grep coeadapt-data
  # Clean up unused images/layers after updates
  docker image prune -f
  # Nuclear option (user-initiated from Settings "Reset")
  docker volume rm coeadapt-data
  ```

---

### Phase 3: MCP Server Sidecar

The MCP server is what connects Claude (via Cowork, Claude Desktop, or claude.ai) to the user's workspace. It runs as a **Tauri sidecar process** on the host machine (NOT inside the container).

**MCP Server responsibilities:**
- Listens on `http://localhost:3100/mcp` (Streamable HTTP transport, MCP spec 2025-06-18)
- Proxies tool calls into the Docker container via `docker exec`
- Validates subscription status on each tool call (calls CoeAdapt cloud API)
- Exposes tools for Claude to interact with the workspace

**MCP Server tool schema (implement these):**

```typescript
// Tools the MCP server exposes to Claude
const tools = [
  {
    name: "workspace_status",
    description: "Check if the CoeAdapt workspace is running and healthy",
    // Returns: { running: boolean, uptime: string, url: string }
  },
  {
    name: "run_command",
    description: "Execute a shell command inside the workspace",
    parameters: { command: "string" }
    // Executes via: docker exec coeadapt-workspace bash -c "<command>"
  },
  {
    name: "read_file",
    description: "Read a file from the workspace filesystem",
    parameters: { path: "string" }
    // Executes via: docker exec coeadapt-workspace cat <path>
  },
  {
    name: "write_file",
    description: "Write content to a file in the workspace",
    parameters: { path: "string", content: "string" }
    // Executes via: docker exec coeadapt-workspace sh -c 'cat > <path> << EOF\n<content>\nEOF'
  },
  {
    name: "list_files",
    description: "List files and directories at a given path",
    parameters: { path: "string" }
    // Executes via: docker exec coeadapt-workspace ls -la <path>
  },
  {
    name: "take_screenshot",
    description: "Capture a screenshot of the current workspace desktop",
    // Executes via: docker exec to run a screenshot utility, returns base64 image
  },
  {
    name: "open_application",
    description: "Launch an application in the workspace",
    parameters: { app_name: "string" }
    // Executes via: docker exec coeadapt-workspace <app_command> &
  },
  {
    name: "get_user_progress",
    description: "Get the user's career development progress and completed activities",
    // Reads from a local JSON file in the workspace volume
  }
]
```

**Subscription validation:**
- Each tool call (except `workspace_status`) first calls `https://api.coeadapt.com/v1/validate` with the user's auth token
- If subscription invalid → return error: "Active CoeAdapt subscription required. Visit coeadapt.com to subscribe."
- Auth token stored locally in Tauri's secure storage (keychain on Mac, credential manager on Windows)

**MCP Server tech:**
- Built with `@modelcontextprotocol/sdk` (TypeScript)
- Bundled as a Tauri sidecar using `externalBin` configuration
- Compiled to a single executable with `pkg` or `bun build --compile`
- Started/stopped by the Tauri Rust backend alongside the container

---

### Phase 4: Claude Connection Setup

After the MCP server is running, guide the user to connect it to their Claude environment. This should feel like the final step of onboarding — "Your workspace is ready, now let's connect your AI copilot."

**Auto-detection flow (Rust backend — `claude.rs`):**

```rust
use std::path::PathBuf;
use dirs;

pub fn claude_config_path() -> Option<PathBuf> {
    let config_dir = if cfg!(target_os = "macos") {
        dirs::home_dir().map(|h| h.join("Library/Application Support/Claude"))
    } else if cfg!(target_os = "windows") {
        dirs::config_dir().map(|c| c.join("Claude"))
    } else {
        dirs::config_dir().map(|c| c.join("Claude"))
    };
    config_dir.map(|d| d.join("claude_desktop_config.json"))
}

pub fn is_claude_installed() -> bool {
    claude_config_path()
        .map(|p| p.parent().map(|d| d.exists()).unwrap_or(false))
        .unwrap_or(false)
}
```

**Config merge logic (critical — don't clobber existing MCP servers):**

```rust
pub fn inject_coeadapt_config(config_path: &Path) -> Result<(), String> {
    let mut config: serde_json::Value = if config_path.exists() {
        let contents = std::fs::read_to_string(config_path).map_err(|e| e.to_string())?;
        serde_json::from_str(&contents).unwrap_or(serde_json::json!({}))
    } else {
        serde_json::json!({})
    };

    // Ensure mcpServers object exists
    if config.get("mcpServers").is_none() {
        config["mcpServers"] = serde_json::json!({});
    }

    // Add CoeAdapt entry (preserves all other servers)
    config["mcpServers"]["coeadapt"] = serde_json::json!({
        "command": "npx",
        "args": ["mcp-remote", "http://localhost:3100/mcp"],
        "env": {}
    });

    // Write back with pretty formatting
    let formatted = serde_json::to_string_pretty(&config).map_err(|e| e.to_string())?;
    std::fs::write(config_path, formatted).map_err(|e| e.to_string())?;
    Ok(())
}
```

**Onboarding UI (React — `ClaudeConnector.tsx`):**

After workspace is running, show this as the final setup step:

```
┌─────────────────────────────────────────────────┐
│  🎉 Your workspace is running!                   │
│                                                   │
│  Last step: connect your AI copilot.              │
│                                                   │
│  We detected Claude Desktop on your system.       │
│                                                   │
│  [Connect to Claude]  ← primary button            │
│                                                   │
│  Or set up manually ▾                             │
│  Copy this URL into Claude → Settings →           │
│  Connectors → Add custom connector:               │
│  ┌─────────────────────────────────────┐         │
│  │ http://localhost:3100/mcp      [Copy]│         │
│  └─────────────────────────────────────┘         │
└───────────────────────────────────────────────────┘
```

If Claude Desktop is NOT detected:
```
┌─────────────────────────────────────────────────┐
│  🎉 Your workspace is running!                   │
│                                                   │
│  Connect your AI copilot:                         │
│                                                   │
│  1. Open Claude (claude.ai, Claude Desktop,       │
│     or Cowork)                                    │
│  2. Go to Settings → Connectors                   │
│  3. Click "Add custom connector"                  │
│  4. Paste this URL:                               │
│     ┌─────────────────────────────────────┐      │
│     │ http://localhost:3100/mcp      [Copy]│      │
│     └─────────────────────────────────────┘      │
│                                                   │
│  [I don't have Claude yet]  ← links to           │
│  claude.ai/download                               │
└───────────────────────────────────────────────────┘
```

**After connection is established:**
- Dashboard shows: "AI Copilot: 🟢 Connected"
- System tray tooltip: "CoeAdapt — Workspace running, AI connected"
- If connection drops: "AI Copilot: 🔴 Disconnected — [Reconnect]"

---

### Phase 5: System Tray

The app should live primarily in the system tray. Closing the window hides it to tray, doesn't quit.

**Tray icon states:**
- 🟢 Green dot: Workspace running, MCP server active, Claude connected
- 🟡 Yellow dot: Starting up, updating, or waiting for Claude connection
- 🔴 Red dot: Error state (Docker not running, container crashed)
- ⚪ Grey dot: Workspace stopped

**Tray menu:**
```
CoeAdapt
─────────────
Open Workspace          → opens browser to localhost:6901
AI Copilot: Connected   → shows connection details / troubleshooting
─────────────
Start Workspace         → starts container + MCP server
Stop Workspace          → stops container + MCP server
─────────────
Reconnect to Claude     → re-injects config, restarts Claude Desktop
Check for Updates       → pulls latest image
Settings                → opens settings window
─────────────
Quit CoeAdapt           → stops everything and exits
```

**"MCP Connection Info" submenu/dialog:**
- Shows: `http://localhost:3100/mcp`
- "Copy URL" button
- Brief instructions: "Add this URL as a Custom Connector in Claude Settings → Connectors → Add custom connector"

**Auto-configure Claude Desktop / Cowork (critical feature):**

Claude Desktop and Cowork read MCP server config from a JSON file on disk. The Tauri app should detect and auto-configure this so the user never has to manually copy URLs or edit config files.

Config file locations:
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux:** `~/.config/Claude/claude_desktop_config.json`

On first launch (after workspace is running), check if the config file exists:

1. **File exists:** Read it, check if `coeadapt` MCP server is already configured
   - If yes → do nothing
   - If no → merge CoeAdapt config into existing config (preserve other MCP servers)
2. **File doesn't exist:** Create it with CoeAdapt config
3. **Claude not installed:** Show manual instructions with the URL to copy

Config to inject/merge:
```json
{
  "mcpServers": {
    "coeadapt": {
      "command": "npx",
      "args": ["mcp-remote", "http://localhost:3100/mcp"],
      "env": {}
    }
  }
}
```

**Alternative: Direct HTTP server (preferred if Claude supports it):**

If the user's Claude plan supports remote MCP connectors (Pro/Max/Team/Enterprise), the Tauri app can also register as a Streamable HTTP server directly. In this case, no config file editing is needed — the user just adds `http://localhost:3100/mcp` as a Custom Connector in Claude's web UI. The app should offer both paths:

```
┌─────────────────────────────────────────────────┐
│  Connect to Claude                               │
│                                                   │
│  ● Auto-configure (recommended)                  │
│    Works with Claude Desktop and Cowork.          │
│    [Configure Now]                                │
│                                                   │
│  ● Manual setup                                   │
│    For claude.ai or other Claude interfaces.      │
│    Copy this URL into Claude → Settings →         │
│    Connectors → Add custom connector:             │
│    ┌─────────────────────────────────────┐       │
│    │ http://localhost:3100/mcp      [Copy]│       │
│    └─────────────────────────────────────┘       │
│                                                   │
│  ● Connection status: 🟢 Connected               │
│    Last tool call: 2 minutes ago                  │
└───────────────────────────────────────────────────┘
```

**Post-configuration flow:**
1. After writing config, prompt: "Claude Desktop needs to restart to pick up the new connection. Restart now?"
   - If yes: kill and relaunch Claude Desktop process
   - If no: show reminder "Restart Claude Desktop when you're ready"
2. After restart, verify connection by checking MCP server logs for incoming handshake
3. Show connection status: 🟢 Connected / 🔴 Not connected / 🟡 Waiting for Claude...

**Connection health monitoring:**
- The MCP server tracks the last incoming tool call timestamp
- If no tool calls received in 5+ minutes after configuration, show a troubleshooting hint
- Surface connection status in the system tray tooltip: "CoeAdapt — Workspace running, AI connected"

**Handling Claude Desktop updates:**
- Claude Desktop updates may reset the config file
- On every Tauri app launch, re-verify the config file contains the CoeAdapt entry
- If missing, silently re-inject it and notify: "Re-connected to Claude"

---

### Phase 6: Settings Window

Accessible from tray menu. Tabs:

**Account:**
- Login/logout to CoeAdapt account
- Subscription status display
- Auth via OAuth flow to `auth.coeadapt.com`

**AI Connection:**
- Connection status: 🟢 Connected / 🔴 Disconnected
- Last tool call timestamp
- Claude Desktop detected: Yes/No
- [Reconnect to Claude] button — re-injects config, offers to restart Claude
- [Copy MCP URL] button — for manual setup
- MCP server port (advanced, default 3100)
- Logs viewer — last 20 MCP tool calls (tool name, timestamp, success/fail)

**Workspace:**
- Container resource limits (memory slider: 2GB / 4GB / 8GB)
- VNC password (default: "coeadapt", user can change)
- Port configuration (advanced, hidden by default)
- **Disk usage display:**
  - Workspace image size (e.g., "Workspace image: 4.8 GB")
  - User data volume size (e.g., "Your files: 1.2 GB")
  - Total CoeAdapt disk usage (e.g., "Total: 6.0 GB")
  - Available disk space remaining (e.g., "Free space: 42 GB")
  - Visual bar showing used vs available
- "Reset Workspace" button (warning: deletes volume, fresh start — show how much space this reclaims)
- "Export My Data" button (copies volume contents to a user-chosen folder)
- "Clean Up Old Images" button (runs `docker image prune` to remove unused image layers after updates)

**General:**
- Launch on system startup (toggle)
- Auto-update workspace image (toggle, default: on)
- Auto-start workspace on launch (toggle, default: on)

---

### Phase 7: Auto-Updater (App Updates)

Use Tauri's built-in updater plugin (`@tauri-apps/plugin-updater`).

- Check for app updates on launch and every 24 hours
- Update endpoint: `https://releases.coeadapt.com/tauri/{{target}}/{{arch}}/{{current_version}}`
- Show non-intrusive notification: "CoeAdapt update available. Restart to apply."
- Separate from container image updates (Phase 2 handles those)

---

## Project Structure

```
coeadapt-launcher/
├── src/                          # React frontend
│   ├── App.tsx                   # Main app with router
│   ├── pages/
│   │   ├── Setup.tsx             # First-run setup wizard
│   │   ├── Dashboard.tsx         # Main status dashboard
│   │   ├── ClaudeSetup.tsx       # Claude connection onboarding step
│   │   └── Settings.tsx          # Settings tabs
│   ├── components/
│   │   ├── StatusIndicator.tsx   # Green/yellow/red status
│   │   ├── ProgressBar.tsx       # For image pulls
│   │   ├── MCPInfo.tsx           # Connection info display
│   │   ├── ClaudeConnector.tsx   # Auto-configure / manual setup UI
│   │   ├── DiskUsage.tsx         # Disk space bar + breakdown
│   │   ├── DiskWarningBanner.tsx # Low space persistent warning
│   │   └── WorkspaceControls.tsx # Start/stop/open buttons
│   ├── hooks/
│   │   ├── useDocker.ts          # Docker state management
│   │   ├── useContainer.ts       # Container lifecycle
│   │   ├── useClaudeConnection.ts # Claude Desktop config detection + MCP status
│   │   ├── useDiskSpace.ts       # Disk monitoring (polls every 30min)
│   │   └── useMCP.ts             # MCP server status
│   └── lib/
│       └── tauri.ts              # Tauri command wrappers
├── src-tauri/                    # Rust backend
│   ├── src/
│   │   ├── main.rs               # App entry, tray setup
│   │   ├── docker.rs             # Docker CLI wrapper
│   │   ├── container.rs          # Container lifecycle management
│   │   ├── disk.rs               # Disk space checks, Docker disk usage, cleanup
│   │   ├── claude.rs             # Claude Desktop/Cowork config detection + auto-configuration
│   │   ├── mcp.rs                # MCP sidecar process management
│   │   ├── health.rs             # Health check polling
│   │   └── commands.rs           # Tauri command handlers
│   ├── Cargo.toml
│   └── tauri.conf.json
├── mcp-server/                   # MCP server (Node.js sidecar)
│   ├── src/
│   │   ├── index.ts              # Server entry point
│   │   ├── tools/                # Tool implementations
│   │   │   ├── workspace.ts
│   │   │   ├── filesystem.ts
│   │   │   ├── screenshot.ts
│   │   │   └── progress.ts
│   │   └── auth.ts               # Subscription validation + connection tracking
│   ├── package.json
│   └── tsconfig.json
├── package.json
└── README.md
```

---

## Key Implementation Details

### Docker CLI Wrapper (Rust)

Do NOT use a Docker SDK/API library. Shell out to the `docker` CLI directly. This is simpler, avoids dependency issues, and works identically with Podman (which aliases `docker` → `podman`).

```rust
// Example pattern for docker commands
use std::process::Command;

pub fn docker_run(image: &str, name: &str) -> Result<String, String> {
    let output = Command::new("docker")
        .args(["run", "-d",
            "--name", name,
            "--shm-size=512m",
            "-p", "6901:6901",
            "-p", "3100:3100",
            "-v", "coeadapt-data:/home/kasm-user",
            "-e", "VNC_PW=coeadapt",
            "--restart", "unless-stopped",
            image])
        .output()
        .map_err(|e| format!("Failed to execute docker: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).trim().to_string())
    }
}
```

### Container Runtime Detection

```rust
pub enum ContainerRuntime {
    Docker,
    Podman,
    None,
}

pub fn detect_runtime() -> ContainerRuntime {
    if Command::new("docker").arg("info").output().map(|o| o.status.success()).unwrap_or(false) {
        ContainerRuntime::Docker
    } else if Command::new("podman").arg("info").output().map(|o| o.status.success()).unwrap_or(false) {
        ContainerRuntime::Podman
    } else {
        ContainerRuntime::None
    }
}
```

### MCP Server Sidecar Configuration

In `tauri.conf.json`:
```json
{
  "bundle": {
    "externalBin": ["mcp-server/coeadapt-mcp"]
  }
}
```

The MCP server should be compiled to a standalone binary before the Tauri build. Use `bun build --compile` or `pkg` to create platform-specific binaries:
- `coeadapt-mcp-x86_64-pc-windows-msvc.exe`
- `coeadapt-mcp-aarch64-apple-darwin`
- `coeadapt-mcp-x86_64-unknown-linux-gnu`

### Health Check Pattern

```rust
use std::time::Duration;
use reqwest;

pub async fn wait_for_workspace(timeout: Duration) -> Result<(), String> {
    let client = reqwest::Client::builder()
        .danger_accept_invalid_certs(true) // KasmVNC uses self-signed
        .build()
        .map_err(|e| e.to_string())?;

    let start = std::time::Instant::now();
    while start.elapsed() < timeout {
        if let Ok(resp) = client.get("https://localhost:6901").send().await {
            if resp.status().is_success() || resp.status().is_redirection() {
                return Ok(());
            }
        }
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
    Err("Workspace failed to start within timeout".to_string())
}
```

### Event Flow: Tauri ↔ React

Use Tauri's event system for real-time updates:

```rust
// Rust: emit progress events
app.emit("docker-pull-progress", PullProgress {
    layer: "abc123",
    status: "Downloading",
    progress: 45.2
}).unwrap();

// Rust: emit state changes
app.emit("workspace-state", WorkspaceState::Running).unwrap();
```

```typescript
// React: listen for events
import { listen } from '@tauri-apps/api/event';

useEffect(() => {
  const unlisten = listen<PullProgress>('docker-pull-progress', (event) => {
    setProgress(event.payload.progress);
  });
  return () => { unlisten.then(fn => fn()); };
}, []);
```

---

## UI Design Guidelines

- **Clean, minimal, calming.** This is a career development tool, not a dev tool.
- **Color palette:** Deep navy (#1a1f36) primary, warm coral (#ff6b6b) accent, soft whites and grays.
- **Typography:** Inter or system fonts. Nothing fancy.
- **No jargon.** Never say "container," "Docker," "image," "volume," or "port" in user-facing copy.
  - "container" → "workspace"
  - "pulling image" → "downloading workspace"
  - "Docker not found" → "CoeAdapt needs to install a small helper app to run your workspace"
  - "port 6901" → never mentioned
  - "MCP server" → "AI Connection"
  - "docker image prune" → "Clean up unused files"
  - "volume" → "your saved files" or "your workspace data"
- **States to design for:**
  1. First launch — setup wizard
  2. Insufficient disk space — friendly warning with cleanup options
  3. Downloading workspace (progress bar with estimated size: "Downloading ~5GB...")
  4. Workspace starting (spinner)
  5. Workspace ready (big green "Open" button)
  6. Workspace stopped (greyed, "Start" button)
  7. Low disk space warning (persistent amber banner across top of dashboard)
  8. Error state (friendly message, retry button, link to support)
  9. Update available (subtle banner with size info: "Update available — 800MB download")

---

## Error Handling

Every error the user could encounter needs a friendly message and a clear action:

| Error | User Message | Action |
|-------|-------------|--------|
| Docker not installed | "CoeAdapt needs a small helper app. Click below to install it." | Install button |
| Docker daemon not running | "Starting up your workspace engine..." | Auto-retry every 5s, show spinner |
| Image pull failed | "Download interrupted. Check your internet connection and try again." | Retry button |
| Container won't start | "Something went wrong starting your workspace. Try resetting it." | Reset button |
| Port 6901 in use | "Another app is using the workspace port. Close it and try again." | Show which process, offer to kill it |
| Port 3100 in use | "Another app is using the AI connection port." | Same as above |
| Insufficient disk (pre-install) | "CoeAdapt needs at least 15GB of free space. You have [X]GB." | Show tips to free space, link to OS disk cleanup |
| Insufficient disk (during pull) | "Download stopped — your disk is almost full. Free up space and try again." | Open OS storage settings, show CoeAdapt cleanup options |
| Disk space low warning | "You're running low on disk space ([X]GB remaining). This may affect your workspace." | Persistent banner with "Clean up" and "Dismiss" options |
| Out of disk space | "Your computer needs more free space to run the workspace. Free up at least 5GB." | Show disk usage breakdown, offer to clean old images |
| MCP server crash | "AI connection lost. Reconnecting..." | Auto-restart sidecar |
| Claude not detected | "We couldn't find Claude on your system." | Link to claude.ai/download + manual URL copy |
| Claude config write failed | "Couldn't auto-configure Claude. Use the manual setup instead." | Show manual URL copy fallback |
| Claude config overwritten | "Claude updated and reset its settings. Reconnecting..." | Auto re-inject config, notify user |
| Claude connection inactive | "Claude hasn't connected yet. Make sure Claude is running." | Troubleshooting steps + retry |
| Subscription expired | "Your CoeAdapt subscription has ended. AI features are paused." | Link to billing page |

---

## Security Considerations

- **Never store passwords in plaintext.** Use Tauri's `plugin-store` with OS keychain integration for auth tokens.
- **VNC password** is local-only (localhost), but still use a non-default password.
- **MCP server** should only bind to `127.0.0.1`, never `0.0.0.0`.
- **Docker socket** is accessed via CLI only, no direct socket mounting.
- **Subscription validation** happens server-side. The MCP server sends the auth token to `api.coeadapt.com` on each tool call. Never validate locally (can be bypassed).
- **Content Security Policy** in Tauri: lock down to only allow localhost connections.
- **Claude config file safety:** Always read → parse → merge → write. Never overwrite the entire file. Create a backup before first edit (`claude_desktop_config.json.bak`). If JSON parsing fails, don't touch the file — fall back to manual setup instructions. Log every config modification for debugging.

---

## Build & Distribution

### Scaffolding:
```bash
# Initialize with Tauri's official scaffolder
bun create tauri-app coeadapt-launcher --template react-ts
# Add Tailwind
cd coeadapt-launcher && bunx @tailwindcss/cli init -p
```

### Build commands:
```bash
# Development (Vite dev server + Tauri window)
cd mcp-server && bun install && bun run build  # Build MCP sidecar first
cd .. && bun install && bun run tauri dev       # Vite HMR + Tauri in dev mode

# Production (Vite builds static assets, Tauri bundles everything)
bun run tauri build                             # Produces platform installers
```

### Outputs:
- **Windows:** `.msi` installer + `.exe` portable (via NSIS)
- **macOS:** `.dmg` with drag-to-Applications
- **Linux:** `.AppImage` + `.deb`

### CI/CD (GitHub Actions):
- Build on push to `main`
- Matrix build: Windows, macOS (Intel + ARM), Linux
- Upload artifacts to GitHub Releases
- Update manifest at `releases.coeadapt.com` for auto-updater

---

## What NOT to Build Yet

- User authentication / OAuth flow (stub it — return a hardcoded valid token for now)
- The actual CoeAdapt cloud API (`api.coeadapt.com` — mock the endpoints)
- The custom Kasm Docker image (use `kasmweb/desktop:1.18.0` as a stand-in)
- Payment/billing integration
- Analytics or telemetry
- The OpenClaw agent integration (comes later, inside the container image)

Focus on getting the Tauri app → Docker management → MCP server pipeline working end-to-end. A user should be able to install the app, have it bootstrap Docker, pull the Kasm image, open a desktop in their browser, and connect Claude via MCP — all without touching a terminal.

---

## Success Criteria

The build is complete when:

1. ✅ `bun run tauri dev` launches the app with Vite HMR on your OS
2. ✅ App checks disk space and system requirements on first launch
3. ✅ App detects Docker/Podman or shows setup instructions
4. ✅ App pulls `kasmweb/desktop:1.18.0` with visible progress and estimated size
5. ✅ App launches the container and health-checks it
6. ✅ "Open Workspace" opens browser to `https://localhost:6901` showing the Kasm desktop
7. ✅ MCP server starts and is reachable at `http://localhost:3100/mcp`
8. ✅ MCP tools (`workspace_status`, `run_command`, `read_file`, `write_file`, `list_files`) work when invoked
9. ✅ App detects Claude Desktop/Cowork and offers auto-configuration
10. ✅ Auto-configure writes correct config to `claude_desktop_config.json` without clobbering existing MCP servers
11. ✅ Manual setup shows copyable URL and clear instructions
12. ✅ Dashboard shows Claude connection status (connected/disconnected)
13. ✅ System tray shows correct state icons and menu works (including AI connection status)
14. ✅ Stopping workspace from tray stops container + MCP server
15. ✅ App survives: Docker restart, container crash, MCP server crash, Claude Desktop restart (auto-recovery)
16. ✅ Claude config is re-verified and re-injected on every app launch
17. ✅ `bun run tauri build` produces installable artifacts for the current platform
