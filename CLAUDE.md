# Career-Box — Claude Code Project Guide

## What This Project Is

Career-Box is a containerized AI-powered career workspace — the local desktop component of the [Coeadapt](https://coeadapt.com) platform. It provides a full Linux desktop in Docker, managed by a Tauri v2 launcher, with an MCP server bridging AI assistants to the workspace.

## Architecture

```
Cora (coeadapt.com) ←→ Cloud Relay ←→ Launcher ←→ MCP Server ←→ Docker Container
```

| Layer | Tech | Location |
|-------|------|----------|
| Launcher frontend | React 19 + TypeScript + Tailwind v4 | `coeadapt-launcher/src/` |
| Launcher backend | Rust (Tauri v2) | `coeadapt-launcher/src-tauri/src/` |
| MCP server | Node.js + TypeScript | `coeadapt-launcher/mcp-server/src/` |
| Container images | Docker + KasmVNC | `src/ubuntu/install/`, `dockerfile-kasm-*` |
| Coeadapt platform | Cloud service at `https://api.coeadapt.com` | See `docs/COEADAPT_API.md` |

## Key Directories

```
coeadapt-launcher/
├── src/pages/           # React pages (Setup, Dashboard, Settings, ClaudeSetup)
├── src/hooks/           # React hooks (useContainer, useClaudeConnection, useDiskSpace, useDocker, useSettings)
├── src/components/      # Shared components
├── src-tauri/src/       # Rust backend (docker.rs, container.rs, claude.rs, health.rs, mcp.rs, disk.rs, commands.rs, state.rs)
└── mcp-server/src/      # MCP tools (workspace, filesystem, commands, screenshot, applications, progress)
```

## Conventions

- **Package manager:** Bun (not npm/yarn)
- **Styling:** Tailwind CSS v4 utility classes, no CSS modules
- **State management:** React hooks only (no Redux/Zustand)
- **Backend IPC:** `invoke()` from `@tauri-apps/api/core` for commands, `listen()` from `@tauri-apps/api/event` for streaming
- **Docker operations:** CLI wrappers via `std::process::Command` (no Docker SDK)
- **Types:** Rust structs (serde) match TypeScript interfaces in `types.ts`
- **MCP tools:** Each tool in its own file under `mcp-server/src/tools/`, registered via `register<Tool>(server, onToolCall)`
- **Error handling:** Try-catch with user-friendly messages, never crash silently
- **Security:** Never write secrets to disk, use OS keyring, bind services to localhost only

## Custom Skills (Slash Commands)

- `/build-careerbox` — Guided feature development for remaining Career-Box features
- `/connect-api` — Implement Coeadapt API client, auth, and data sync
- `/connect-cora` — Build the cloud relay bridge between Cora and local workspace

## API Reference

- **Public API contract:** `docs/COEADAPT_API.md` — the only source of truth for Career-Box API integration
- **Production endpoint:** `https://api.coeadapt.com/api`
- The Coeadapt platform is a separate, proprietary codebase. Do not reference or document its internals.

## Constants

| Name | Value |
|------|-------|
| Container name | `coeadapt-workspace` |
| Image name | `coeadapt/workspace:latest` |
| Volume name | `coeadapt-data` |
| Workspace port | 6901 (KasmVNC) |
| MCP server port | 3100 |
| CareerClaw port | 18789 |
| API | `https://api.coeadapt.com/api` |

## Build Commands

```bash
cd coeadapt-launcher
bun install                          # Install frontend deps
cd mcp-server && bun install && cd .. # Install MCP deps
bun run tauri dev                    # Dev mode (HMR + Tauri window)
bun run tauri build                  # Production build
```

MCP sidecar binary must be built before `tauri build`:
```bash
cd mcp-server && bun run build && cd ..
# Binary goes to src-tauri/binaries/ (gitignored)
```

## Git Workflow

- **Main branch:** `main`
- **Development branch:** `develop`
- Commit messages: conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`)
- Always commit to `develop`, PR to `main`
