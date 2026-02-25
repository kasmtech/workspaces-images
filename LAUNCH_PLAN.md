# Career-Box Launch & CoeAdapt Integration — Master Plan

**Status:** Draft
**Last updated:** 2026-02-25
**Prepared for:** alexander-acker / CoeAdapt team

---

## Executive Summary

Career-Box is a containerized career workspace that pairs a Kasm-based Linux desktop with an AI agent gateway (CareerClaw). The Coeadapt Launcher is a Tauri v2 desktop app that makes the entire system accessible to non-technical users. This plan covers two interleaved tracks:

1. **Launch readiness** — everything needed to ship Career-Box v1.0 as a standalone, downloadable product.
2. **CoeAdapt platform integration** — connecting the launcher and workspace to the CoeAdapt web application for Cora, career tracking, and cloud sync.

The plan is organized into six phases, each with concrete deliverables, owners, and acceptance criteria. Phases 1–3 are sequential prerequisites. Phases 4–6 can run in parallel once Phase 3 is complete.

---

## Table of Contents

1. [Current State Assessment](#phase-0-current-state-assessment)
2. [Phase 1: Foundation & Infrastructure](#phase-1-foundation--infrastructure)
3. [Phase 2: CoeAdapt API Integration](#phase-2-coeadapt-api-integration)
4. [Phase 3: Workspace Image & CareerClaw](#phase-3-workspace-image--careerclaw)
5. [Phase 4: Distribution & Auto-Update](#phase-4-distribution--auto-update)
6. [Phase 5: Quality & Security](#phase-5-quality--security)
7. [Phase 6: Launch Operations](#phase-6-launch-operations)
8. [Risk Register](#risk-register)
9. [Success Metrics](#success-metrics)
10. [Open Questions](#open-questions)

---

## Phase 0: Current State Assessment

### What's built and working

| Component | Status | Notes |
|-----------|--------|-------|
| Tauri v2 launcher shell | Done | React 19, Tailwind v4, Rust backend |
| Docker/Podman detection | Done | Auto-detects runtime and daemon state |
| Container lifecycle | Done | Pull (with streaming progress), create, start, stop, reset |
| Multi-step setup wizard | Done | Auto-advancing, non-technical language |
| Dashboard | Done | Workspace status, controls, disk usage |
| System tray | Done | Start/stop/open/show/quit, AI status polling |
| Hide-to-tray on close | Done | Prevents accidental exit |
| Disk monitoring | Done | 15 GB minimum, 5 GB low-space banner |
| Claude Desktop integration | Done | Auto-detect, config injection, backup |
| MCP server (sidecar) | Done | 8 tools: shell, filesystem, screenshot, apps, progress |
| SSL certificate management | Done | Trust/untrust workspace CA from launcher |
| Settings page | Done | AI Connection + Workspace + General tabs |
| Clerk auth scaffolding | Done | ClerkProvider, mode detection, auth guard |
| CoeAdapt API client | Done | Typed client with JWT + device token auth |
| Cora chat page | Done | Basic send/receive UI with streaming support |
| Account settings tab | Done | Profile display, device token, sign out |
| Standalone mode detection | Done | Auto-detects from VITE_CLERK_PUBLISHABLE_KEY |
| CareerClaw install script | Done | Dependencies, build, CLI, gateway, systemd |
| Security hardening | Done | 10+ patches documented in SECURITY.md |
| 80+ workspace Dockerfiles | Done | Inherited from Kasm upstream |

### What's missing or incomplete

| Gap | Priority | Blocking? |
|-----|----------|-----------|
| No `.env` / `.env.example` committed | High | Yes — new devs can't configure CoeAdapt mode |
| Updater pubkey is placeholder | Critical | Yes — auto-update will fail in production |
| No CI/CD for launcher builds | High | Yes — no reproducible release pipeline |
| No E2E or integration tests | High | No — but risky to ship without |
| CoeAdapt API endpoints are stubbed in client but untested | High | Yes — integration will break silently |
| Cora chat uses non-streaming `sendMessage` despite streaming UI | Medium | No — but UX is degraded |
| No error boundaries in React | Medium | No — but crashes blank the app |
| No telemetry or crash reporting | Medium | No — but debugging production issues will be blind |
| No license compliance check on 80+ upstream images | Medium | Yes for distribution |
| Docker image `coeadapt/workspace:latest` not built or published | Critical | Yes — the app downloads an image that doesn't exist yet |
| No GitHub Actions workflow | High | Yes — no CI for PRs or releases |
| MCP sidecar binary not cross-compiled | High | Yes — only works on build platform |

---

## Phase 1: Foundation & Infrastructure

**Goal:** Establish the build, test, and release infrastructure needed for everything else.

**Duration:** 1–2 weeks

### 1.1 Environment configuration

- [ ] Create `coeadapt-launcher/.env.example` with documented variables:
  ```env
  VITE_CLERK_PUBLISHABLE_KEY=pk_test_REPLACE_ME
  VITE_COEADAPT_API_URL=http://localhost:5000
  ```
- [ ] Add `.env` to `.gitignore` (already present — verify)
- [ ] Document env setup in `coeadapt-launcher/README.md` dev section

### 1.2 GitHub Actions CI

- [ ] Create `.github/workflows/ci.yml`:
  - Lint (TypeScript + Rust)
  - Type-check (`tsc --noEmit`)
  - Build frontend (`bun run build`)
  - Build MCP sidecar (`cd mcp-server && bun run build`)
  - `cargo check` and `cargo clippy` for Rust backend
  - Run on push to `develop` and `main`, and on all PRs
- [ ] Create `.github/workflows/release.yml`:
  - Triggered by git tag `v*`
  - Matrix build: Windows (x64), macOS (x64 + arm64), Linux (x64)
  - Cross-compile MCP sidecar for each target
  - Build Tauri app, upload artifacts to GitHub Releases
  - Generate update manifest for Tauri updater
- [ ] Migrate from GitLab CI (existing `.gitlab-ci.yml`) or keep both if Kasm upstream images still build on GitLab

### 1.3 Tauri updater configuration

- [ ] Generate real signing keypair for Tauri updater
- [ ] Replace `REPLACE_WITH_REAL_PUBKEY_BEFORE_RELEASE` in `tauri.conf.json`
- [ ] Set up update manifest hosting (GitHub Releases or `releases.coeadapt.com`)
- [ ] Store private key in CI secrets, never in repo

### 1.4 MCP sidecar cross-compilation

- [ ] Update `mcp-server/build.ts` to produce platform-specific binaries:
  - `coeadapt-mcp-x86_64-pc-windows-msvc.exe`
  - `coeadapt-mcp-x86_64-apple-darwin`
  - `coeadapt-mcp-aarch64-apple-darwin`
  - `coeadapt-mcp-x86_64-unknown-linux-gnu`
- [ ] Update `tauri.conf.json` `externalBin` to use platform-specific paths
- [ ] Verify sidecar launches correctly on all three platforms

### 1.5 Error boundaries and resilience

- [ ] Add React error boundary wrapping `<App />` with a user-friendly fallback
- [ ] Add `window.onerror` / `window.onunhandledrejection` logging
- [ ] Add graceful degradation when MCP sidecar fails to start

---

## Phase 2: CoeAdapt API Integration

**Goal:** Wire the launcher to the live CoeAdapt web application so that authenticated users get Cora, career tracking, and cloud sync.

**Duration:** 2–3 weeks

### 2.1 Authentication flow

- [ ] Obtain production Clerk publishable key from CoeAdapt dashboard
- [ ] Test Clerk sign-in/sign-up flow end-to-end in the Tauri webview
- [ ] Verify CSP in `tauri.conf.json` allows all required Clerk domains
- [ ] Handle Clerk token expiry and refresh gracefully
- [ ] Test device token generation (`/api/career-box/generate-token`)
- [ ] Verify device token is persisted via `tauri-plugin-store` and survives app restart
- [ ] Implement token refresh logic (detect expiry, auto-regenerate)

### 2.2 CoeAdapt API contract validation

Validate each API endpoint in `lib/api.ts` against the live CoeAdapt backend:

| Endpoint | Method | Verified? |
|----------|--------|-----------|
| `/api/career-box/health` | GET | [ ] |
| `/api/career-box/verify-token` | POST | [ ] |
| `/api/career-box/generate-token` | POST | [ ] |
| `/api/auth/user` | GET | [ ] |
| `/api/plans/me` | GET | [ ] |
| `/api/plans/:id` | GET | [ ] |
| `/api/plans/:planId/tasks` | GET | [ ] |
| `/api/tasks/me` | GET | [ ] |
| `/api/tasks/:id` | GET | [ ] |
| `/api/tasks/:id` | PUT | [ ] |
| `/api/tasks/:taskId/evidence` | POST | [ ] |
| `/api/goals/me` | GET | [ ] |
| `/api/goals` | POST | [ ] |
| `/api/goals/:id` | PATCH | [ ] |
| `/api/habits` | GET | [ ] |
| `/api/habits/today` | GET | [ ] |
| `/api/habits` | POST | [ ] |
| `/api/habits/:id/complete` | POST | [ ] |
| `/api/habits/stats/overview` | GET | [ ] |
| `/api/jobs` | GET | [ ] |
| `/api/jobs/discover` | GET | [ ] |
| `/api/jobs/:id/bookmark` | POST | [ ] |
| `/api/jobs/bookmarks/me` | GET | [ ] |
| `/api/portfolio/items` | GET | [ ] |
| `/api/skills/verified` | GET | [ ] |
| `/api/radar/market-fit` | GET | [ ] |
| `/api/radar/skill-deltas` | GET | [ ] |
| `/api/subscription/status` | GET | [ ] |
| `/api/notifications/me` | GET | [ ] |
| `/api/chatbot/agent` | POST | [ ] |

- [ ] Replace `any` return types with concrete TypeScript interfaces
- [ ] Add error handling for 401 (redirect to login), 429 (rate limit backoff), 5xx (retry with exponential backoff)
- [ ] Add offline detection and queue mutations for retry

### 2.3 Cora chat — streaming upgrade

- [ ] Implement SSE or WebSocket streaming for `/api/chatbot/agent`
- [ ] Update `useCoraChat` hook to consume streaming tokens
- [ ] Display tokens as they arrive (already have streaming UI scaffolding)
- [ ] Add conversation persistence (thread ID stored in `tauri-plugin-store`)
- [ ] Add conversation history loading on Chat page mount

### 2.4 Career data display in Dashboard

- [ ] Add a "Career Overview" card to Dashboard (CoeAdapt mode only):
  - Active plan name + progress %
  - Today's tasks (count completed / total)
  - Current streak (habits)
  - Next job application deadline
- [ ] Wire to `api.getPlans()`, `api.getHabitsToday()`, `api.getTasks()`, `api.getJobs()`
- [ ] Add loading skeletons for async data
- [ ] Handle empty states ("No plan yet — chat with Cora to get started")

### 2.5 Device token handoff to MCP sidecar

- [ ] Pass device token to MCP sidecar as environment variable on launch
- [ ] MCP sidecar attaches token to requests forwarded to CoeAdapt API
- [ ] This enables CareerClaw (inside workspace) to make authenticated API calls through the MCP bridge
- [ ] Verify token rotation propagates to running sidecar

### 2.6 Subscription gating

- [ ] Fetch subscription status on login (`api.getSubscription()`)
- [ ] Gate premium features based on `features` map from subscription response
- [ ] Show upgrade prompt for gated features
- [ ] Handle free tier gracefully (no degraded UX for free users on core features)

---

## Phase 3: Workspace Image & CareerClaw

**Goal:** Build and publish the `coeadapt/workspace:latest` Docker image with CareerClaw baked in, and verify the full AI agent loop works.

**Duration:** 2–3 weeks

### 3.1 Workspace image build pipeline

- [ ] Create `dockerfile-kasm-coeadapt-workspace` (the "career workspace" image):
  - Based on `dockerfile-kasm-ubuntu-noble-desktop` or `dockerfile-kasm-zorin-deluxe`
  - Includes CareerClaw install (`src/ubuntu/install/careerclaw/`)
  - Includes key career tools: VS Code, Firefox/Chrome, LibreOffice, terminal
  - Applies all security hardening from SECURITY.md
- [ ] Add GitHub Actions workflow to build and push to Docker Hub / GHCR:
  - `coeadapt/workspace:latest` — stable
  - `coeadapt/workspace:dev` — from develop branch
  - `coeadapt/workspace:v1.0.0` — tagged releases
- [ ] Optimize image size (target < 5 GB compressed)
- [ ] Test image pull, create, start, open cycle end-to-end

### 3.2 CareerClaw gateway

- [ ] Verify CareerClaw gateway starts on port 18789 inside the container
- [ ] Verify MCP sidecar (port 3100 on host) can reach gateway (port 18789 in container)
- [ ] Test full tool loop: Claude Desktop → MCP sidecar → docker exec → CareerClaw → workspace
- [ ] Document the network topology for contributors

### 3.3 CareerClaw + CoeAdapt API bridge

- [ ] CareerClaw receives device token from MCP sidecar environment
- [ ] CareerClaw can call CoeAdapt API endpoints:
  - Update task status
  - Submit evidence
  - Log skill practice
  - Report habit completion
- [ ] Cora (in web app) can trigger CareerClaw actions in workspace:
  - Open a URL
  - Run a command
  - Take a screenshot
  - Open an application
- [ ] Verify bidirectional communication: web app ↔ API ↔ MCP sidecar ↔ CareerClaw

### 3.4 Workspace branding

- [ ] Apply CoeAdapt branding to workspace desktop:
  - Custom wallpaper
  - Branded panel/dock
  - Welcome window on first launch
- [ ] Add career-specific desktop shortcuts (Resume Builder, Portfolio, Job Tracker)
- [ ] These shortcuts open browser to CoeAdapt web app at the relevant page

---

## Phase 4: Distribution & Auto-Update

**Goal:** Users can download, install, and receive updates seamlessly on Windows, macOS, and Linux.

**Duration:** 1–2 weeks (parallel with Phases 5–6)

### 4.1 Platform installers

- [ ] **Windows:** `.msi` installer
  - Test on Windows 10 and 11
  - Verify Docker Desktop detection works
  - Code signing certificate (optional for v1, recommended)
- [ ] **macOS:** `.dmg`
  - Test on Intel and Apple Silicon
  - Handle Gatekeeper / notarization (required for unsigned apps)
  - Verify Podman detection works alongside Docker
- [ ] **Linux:** `.AppImage` + `.deb`
  - Test on Ubuntu 22.04, 24.04, Fedora 40+
  - Verify `xdg-open` for workspace browser launch

### 4.2 Auto-update flow

- [ ] Tauri updater checks `releases.coeadapt.com` (or GitHub Releases) on launch
- [ ] User sees "Update available" notification
- [ ] One-click update, download, restart
- [ ] Test update from v0.1.0 → v1.0.0
- [ ] Rollback plan if update breaks (user can re-download from releases page)

### 4.3 First-run experience

- [ ] Installer opens the app after install
- [ ] Setup wizard detects missing Docker and offers one-click install link
- [ ] First image pull shows time estimate and progress
- [ ] After setup, dashboard opens — user sees "Open Workspace" button
- [ ] Entire flow from download to open workspace: < 10 minutes (excluding Docker install)

### 4.4 Release page

- [ ] GitHub Releases page with:
  - Platform-specific download links
  - Release notes (auto-generated from conventional commits)
  - SHA256 checksums
- [ ] Optional: landing page at `coeadapt.com/download` with download buttons

---

## Phase 5: Quality & Security

**Goal:** Ship with confidence. No known security vulnerabilities, no data loss, no crashes.

**Duration:** 2 weeks (parallel with Phases 4, 6)

### 5.1 Testing

- [ ] **Unit tests (frontend):**
  - Mode detection (`lib/mode.ts`)
  - API client error handling (`lib/api.ts`)
  - Hook behavior (`useContainer`, `useClaudeConnection`)
- [ ] **Unit tests (backend):**
  - Docker info parsing (`docker.rs`)
  - Container status parsing (`container.rs`)
  - Disk space calculation (`disk.rs`)
  - Claude config detection and injection (`claude.rs`)
- [ ] **Integration tests:**
  - Full setup wizard flow (mock Docker)
  - Container lifecycle: pull → create → start → stop → reset
  - MCP sidecar start/stop/health
  - Claude Desktop config injection + backup
- [ ] **E2E tests (optional for v1, required for v1.1):**
  - Playwright or similar for Tauri webview
  - Full flow: launch → setup → dashboard → open workspace

### 5.2 Security review

- [ ] Verify all SECURITY.md fixes are applied in the published workspace image
- [ ] Audit CSP policy in `tauri.conf.json` — no unnecessary `unsafe-*` directives
- [ ] Verify MCP sidecar only listens on `127.0.0.1` (not `0.0.0.0`)
- [ ] Verify device tokens are stored encrypted at rest (via `tauri-plugin-store`)
- [ ] Verify no secrets in git history (Clerk keys, API keys, signing keys)
- [ ] Review Tauri capabilities (`capabilities/default.json`) — principle of least privilege
- [ ] Verify Docker socket access is properly scoped
- [ ] Run `cargo audit` and `bun audit` for dependency vulnerabilities

### 5.3 Error handling audit

- [ ] Every Tauri command returns `Result<T, String>` — verify all error paths are handled
- [ ] Every API call in the frontend has error handling
- [ ] MCP sidecar handles `docker exec` timeouts (currently 30s — verify)
- [ ] Launcher handles Docker daemon not running (user-friendly message)
- [ ] Launcher handles workspace image pull failure (retry button)
- [ ] Launcher handles disk full during pull (clear message + prune suggestion)

### 5.4 Performance

- [ ] Launcher startup time < 2 seconds to window visible
- [ ] Container status polling interval tuned (currently what? — verify)
- [ ] MCP health polling at 15s in tray — verify no resource leak
- [ ] Disk monitoring at 30 min — verify sysinfo doesn't spike CPU
- [ ] Workspace browser loads within 5 seconds of container start

---

## Phase 6: Launch Operations

**Goal:** Everything needed for the actual launch day and the weeks that follow.

**Duration:** 1 week (parallel with Phases 4, 5)

### 6.1 Documentation

- [ ] Verify README.md is accurate for v1.0
- [ ] Verify CONTRIBUTING.md has correct setup instructions
- [ ] Write `docs/QUICKSTART.md` — 5-step guide for end users
- [ ] Write `docs/TROUBLESHOOTING.md`:
  - Docker not detected
  - Image pull fails
  - Workspace won't start
  - AI copilot disconnected
  - Certificate trust issues
  - Port conflicts (6901, 3100)
- [ ] Write `docs/COEADAPT_INTEGRATION.md` — detailed guide for CoeAdapt features
- [ ] Update `coeadapt-launcher/README.md` with final architecture

### 6.2 Telemetry & monitoring (optional for v1)

- [ ] Anonymous usage telemetry (opt-in):
  - Launcher opens / workspace starts / AI connections
  - No PII, no workspace content, no commands
- [ ] Crash reporting (Sentry or similar):
  - Frontend errors
  - Rust panics
  - MCP sidecar crashes
- [ ] CoeAdapt API monitoring:
  - Track Career-Box API call volume
  - Monitor error rates
  - Alert on device token failures

### 6.3 Support infrastructure

- [ ] GitHub Issues templates:
  - Bug report (with system info: OS, Docker version, app version)
  - Feature request
  - Security vulnerability (private advisory)
- [ ] GitHub Discussions enabled for community Q&A
- [ ] CoeAdapt support email for authenticated users
- [ ] FAQ section on coeadapt.com/career-box

### 6.4 Launch checklist

Pre-launch (T-7 days):
- [ ] All Phase 1–3 deliverables complete
- [ ] Workspace image published to Docker Hub / GHCR
- [ ] Platform installers tested on Windows, macOS, Linux
- [ ] Auto-update tested from v0.9.0 → v1.0.0
- [ ] All SECURITY.md fixes verified in published image
- [ ] Release notes drafted
- [ ] Landing page / download page live

Launch day (T-0):
- [ ] Tag `v1.0.0` on `main`
- [ ] CI builds and publishes installers to GitHub Releases
- [ ] CI builds and pushes `coeadapt/workspace:v1.0.0` and `:latest`
- [ ] Update manifest published for auto-updater
- [ ] Announce on CoeAdapt channels
- [ ] Monitor error rates and support channels for first 24 hours

Post-launch (T+7 days):
- [ ] Review crash reports and error logs
- [ ] Triage and fix any critical bugs → v1.0.1 patch
- [ ] Gather user feedback
- [ ] Plan v1.1 based on feedback and remaining roadmap items

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Docker Desktop license concerns for enterprise users | Medium | Medium | Support Podman as alternative (already implemented) |
| Kasm upstream breaks our customizations | High | Low | Pin upstream version, document all patches in SECURITY.md |
| Clerk auth doesn't work reliably in Tauri webview | High | Medium | Test early (Phase 2.1), have fallback to external browser auth |
| Workspace image too large for first download | Medium | High | Optimize layers, show accurate progress, support resume |
| CareerClaw gateway authentication vulnerabilities | Critical | Low | Security audit in Phase 5, removed `--allow-unconfigured` |
| Auto-update breaks installations | High | Medium | Signed updates, rollback via re-download, staged rollouts |
| CoeAdapt API availability affects standalone users | Medium | Low | Standalone mode never calls CoeAdapt API — fully offline |
| macOS Gatekeeper blocks unsigned app | High | High | Plan for notarization or guide users through "Open Anyway" |
| Port conflicts (6901, 3100) with other software | Medium | Medium | Add port conflict detection in setup wizard |
| Large Docker images consume user disk space over time | Medium | High | "Clean Up Old Images" already implemented, add auto-prune |

---

## Success Metrics

### Launch (first 30 days)

| Metric | Target |
|--------|--------|
| Downloads | 500+ |
| Successful setups (workspace running) | 70% of downloads |
| CoeAdapt account connections | 30% of successful setups |
| Cora conversations started | 50% of connected users |
| Critical bugs reported | < 5 |
| Average setup time (download → workspace open) | < 10 min |

### Growth (first 90 days)

| Metric | Target |
|--------|--------|
| Monthly active workspaces | 200+ |
| Career plans created via Cora | 100+ |
| Tasks completed in workspace | 500+ |
| Community contributions (PRs) | 10+ |
| GitHub stars | 100+ |

---

## Open Questions

1. **Workspace image hosting:** Docker Hub (free tier limits) vs. GHCR (unlimited for public repos) vs. self-hosted registry?

2. **macOS notarization:** Do we pay for Apple Developer Program ($99/year) for v1.0, or ship unsigned with "Open Anyway" instructions?

3. **Cora streaming protocol:** Does the CoeAdapt API support SSE for `/api/chatbot/agent`? Or do we need WebSockets? Or is polling acceptable for v1?

4. **Subscription model:** What features are free vs. premium? This affects subscription gating implementation in Phase 2.6.

5. **CareerClaw version:** Which OpenClaw release does CareerClaw track? Is the fork up-to-date?

6. **Telemetry framework:** Posthog, Mixpanel, custom, or skip for v1?

7. **Windows code signing:** Required for v1.0? SmartScreen will warn users without it.

8. **CoeAdapt API staging environment:** Is there a staging API for development/testing, or do we test against production?

---

## Dependency Graph

```
Phase 1 (Foundation)
  ├── 1.1 Environment config
  ├── 1.2 GitHub Actions CI ──────────────────────┐
  ├── 1.3 Tauri updater config                     │
  ├── 1.4 MCP sidecar cross-compile                │
  └── 1.5 Error boundaries                         │
                                                    │
Phase 2 (CoeAdapt Integration)  ◄── requires 1.1  │
  ├── 2.1 Auth flow                                 │
  ├── 2.2 API contract validation                   │
  ├── 2.3 Cora streaming                            │
  ├── 2.4 Career data in Dashboard                  │
  ├── 2.5 Device token → MCP                        │
  └── 2.6 Subscription gating                       │
                                                    │
Phase 3 (Workspace & CareerClaw)  ◄── requires 1.2│
  ├── 3.1 Image build pipeline ◄────────────────────┘
  ├── 3.2 Gateway verification
  ├── 3.3 CareerClaw ↔ CoeAdapt bridge ◄── requires 2.5
  └── 3.4 Workspace branding

Phase 4 (Distribution) ◄── requires 1.2, 1.3, 1.4
Phase 5 (Quality) ◄── requires 2.*, 3.*
Phase 6 (Launch) ◄── requires 4.*, 5.*
```

---

## Version History

| Date | Version | Change |
|------|---------|--------|
| 2026-02-25 | 0.1 | Initial draft — full assessment, six-phase plan |
