# Coeadapt Launcher

Cross-platform desktop app that manages the Coeadapt career workspace. Built with Tauri v2 + React + TypeScript.

> This is a subproject of [Career-Box](../README.md). See the root README for the full project overview.

## What It Does

- Detects Docker/Podman and guides non-technical users through setup
- Pulls and manages a Kasm Workspaces container (`coeadapt/workspace:latest`)
- Runs an MCP server (port 3100) so Claude can interact with the workspace
- Auto-configures Claude Desktop for one-click AI connection
- Lives in the system tray with start/stop/open controls

## Architecture

```
Coeadapt Tauri App (system tray + window)
├── React UI (Vite + Tailwind v4)
│   ├── Setup wizard (onboarding)
│   ├── Dashboard (status + controls)
│   ├── Claude Setup (AI connection)
│   └── Settings (workspace, AI, account)
├── Rust Backend (Tauri commands)
│   ├── Docker/Podman detection
│   ├── Container lifecycle (pull/create/start/stop)
│   ├── Disk space monitoring
│   ├── Health checks (workspace + MCP)
│   └── Claude Desktop config injection
└── MCP Server (Node.js sidecar, port 3100)
    ├── workspace_status
    ├── run_command
    ├── read_file / write_file / list_files
    ├── take_screenshot
    ├── open_application
    └── get_user_progress
```

## Prerequisites

- [Bun](https://bun.sh/) (package manager + bundler)
- [Rust](https://rustup.rs/) (for Tauri backend)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) or [Podman Desktop](https://podman-desktop.io/)

## Development

```bash
# Install frontend dependencies
bun install

# Install MCP server dependencies
cd mcp-server && bun install && cd ..

# Run in dev mode (Vite HMR + Tauri window)
bun run tauri dev
```

## Building

```bash
# 1. Build MCP sidecar binary
cd mcp-server && bun run build && cd ..

# 2. Build the Tauri app (produces platform installers)
bun run tauri build
```

### Build Outputs

| Platform | Artifacts |
|----------|-----------|
| Windows  | `.msi` installer, `.exe` (NSIS) |
| macOS    | `.dmg` |
| Linux    | `.AppImage`, `.deb` |

## Project Structure

```
coeadapt-launcher/
├── src/                          # React frontend
│   ├── pages/
│   │   ├── Setup.tsx             # Multi-step onboarding wizard
│   │   ├── Dashboard.tsx         # Workspace status + controls
│   │   ├── ClaudeSetup.tsx       # Claude Desktop connection flow
│   │   └── Settings.tsx          # Tabbed settings (Account, AI, Workspace, General)
│   ├── components/
│   │   ├── DiskWarningBanner.tsx  # Persistent low-space warning (<5GB)
│   │   ├── DiskUsage.tsx          # Disk space progress bar
│   │   ├── ProgressBar.tsx        # Image pull progress (indeterminate support)
│   │   ├── Spinner.tsx            # Loading spinner (sm/md/lg)
│   │   ├── StatusIndicator.tsx    # Colored dot + label
│   │   └── WorkspaceControls.tsx  # Context-aware Start/Stop/Open buttons
│   ├── hooks/
│   │   ├── useDocker.ts           # Docker/Podman runtime detection
│   │   ├── useContainer.ts        # Container lifecycle + status polling
│   │   ├── useClaudeConnection.ts # Claude Desktop detection + MCP health
│   │   └── useDiskSpace.ts        # Disk monitoring + warning events
│   └── lib/
│       ├── tauri.ts               # 17 Tauri command wrappers
│       ├── types.ts               # TypeScript interfaces (mirrors Rust structs)
│       └── constants.ts           # User-facing strings (no jargon)
├── src-tauri/                     # Rust backend
│   ├── src/
│   │   ├── main.rs                # Entry point
│   │   ├── lib.rs                 # App setup, tray, plugins, event loops
│   │   ├── state.rs               # Serializable structs + constants
│   │   ├── commands.rs            # 17 Tauri command handlers
│   │   ├── docker.rs              # Docker CLI wrapper + streaming pull
│   │   ├── container.rs           # Container create/start/stop/remove
│   │   ├── disk.rs                # Disk space checks (sysinfo crate)
│   │   ├── health.rs              # Workspace + MCP health polling
│   │   └── claude.rs              # Claude Desktop config detection + injection
│   ├── Cargo.toml                 # Rust dependencies
│   ├── tauri.conf.json            # App config, window, CSP, updater
│   └── capabilities/default.json  # Tauri security permissions
└── mcp-server/                    # Node.js MCP server (sidecar)
    ├── src/
    │   ├── index.ts               # HTTP server + MCP transport setup
    │   ├── docker-exec.ts         # docker exec wrapper (30s timeout)
    │   └── tools/                 # MCP tool implementations
    │       ├── workspace.ts       # workspace_status
    │       ├── commands.ts        # run_command
    │       ├── filesystem.ts      # read_file, write_file, list_files
    │       ├── screenshot.ts      # take_screenshot
    │       ├── applications.ts    # open_application
    │       └── progress.ts        # get_user_progress
    ├── build.ts                   # Bun compile to sidecar binary
    ├── package.json
    └── tsconfig.json
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Tauri v2 (stable) |
| Frontend | React 19, TypeScript 5.8, Vite 7 |
| Styling | Tailwind CSS v4 (navy + coral theme) |
| Backend | Rust (2021 edition) |
| MCP Server | `@modelcontextprotocol/sdk` v1.12, Zod |
| HTTP Client | reqwest 0.12 (rustls-tls) |
| System Info | sysinfo 0.34 |

### Tauri Plugins

- `tauri-plugin-opener` - Open URLs in default browser
- `tauri-plugin-shell` - Execute shell commands
- `tauri-plugin-store` - Persistent key-value storage
- `tauri-plugin-updater` - Auto-update support
- `tauri-plugin-autostart` - Launch on system boot

## Container Configuration

| Setting | Value |
|---------|-------|
| Container name | `coeadapt-workspace` |
| Image | `coeadapt/workspace:latest` |
| Data volume | `coeadapt-data` (mounted at `/home/kasm-user`) |
| Workspace port | `6901` (KasmVNC) |
| MCP server port | `3100` |
| Shared memory | `512MB` |
| Restart policy | `unless-stopped` |

## Disk Space Requirements

| Threshold | Value | Behavior |
|-----------|-------|----------|
| Minimum | 15 GB free | Blocks setup |
| Recommended | 25 GB free | Warning shown |
| Low space | < 5 GB free | Persistent banner |

## MCP Server

The MCP server bridges Claude to the workspace container via `docker exec`. It exposes 8 tools:

| Tool | Description |
|------|-------------|
| `workspace_status` | Check if workspace is running |
| `run_command` | Execute shell commands in the workspace |
| `read_file` | Read file contents from workspace |
| `write_file` | Write content to a file in workspace |
| `list_files` | List directory contents |
| `take_screenshot` | Capture desktop screenshot |
| `open_application` | Launch apps (firefox, terminal, vscode, etc.) |
| `get_user_progress` | Read career progress data |

### Endpoints

- `http://127.0.0.1:3100/mcp` - MCP Streamable HTTP transport
- `http://127.0.0.1:3100/health` - Health check (status, lastToolCall, uptime)

## Claude Desktop Integration

The app auto-detects Claude Desktop and injects MCP config into `claude_desktop_config.json`:

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

Config file locations:
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux:** `~/.config/Claude/claude_desktop_config.json`

A backup (`.json.bak`) is created before the first modification.

## Current Status

### Complete
- Docker/Podman detection and daemon monitoring
- Full container lifecycle (pull with streaming progress, create, start, stop, reset)
- Disk space monitoring with thresholds and warning banner
- Multi-step setup wizard with auto-advance
- Dashboard with workspace status, controls, and disk usage
- Claude Desktop auto-detection and config injection
- MCP server with all 8 tools
- System tray (start/stop/open/show/quit)
- Hide-to-tray on window close
- Settings page (AI Connection + Workspace tabs functional)

### Roadmap

See [GitHub Issues](https://github.com/coeadapt/Career-Box/issues) for planned work and known issues.
