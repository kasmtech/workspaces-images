# Career-Box

**A containerized career workspace powered by AI.**

Career-Box gives you a full Linux desktop pre-loaded with career development tools — browsers, IDEs, office suites, security tools, and more — all running in a Docker container on your machine. A desktop launcher manages everything so you never touch a terminal. CareerClaw, an AI agent running inside the workspace, connects to your career coach so it can see your screen, run commands, open applications, and help you do real work.

No Docker knowledge. No Linux experience. No account required. Just launch and go.

<p align="center">
  <img src="docs/screenshots/setup-welcome.png" alt="Setup wizard" width="380" />
  <img src="docs/screenshots/dashboard.png" alt="Dashboard" width="380" />
</p>

---

## What is Career-Box?

Career-Box is an open-source, containerized career development workspace. It gives you a full Linux desktop pre-loaded with 80+ career tools, managed by a desktop launcher, with an AI agent gateway that lets assistants interact with your workspace directly.

It brings together two powerful open-source projects:

- **[Kasm Workspaces](https://github.com/kasmtech/workspaces-images)** — a container streaming platform that delivers full Linux desktops and applications through your browser. Kasm provides the isolated, reproducible environment where career work happens.
- **[OpenClaw](https://github.com/openclaw/openclaw)** — an AI agent framework with built-in tools for shell execution, web search, browser automation, file management, and persistent memory. OpenClaw provides the intelligence layer that turns the workspace into an AI-powered career assistant.

**Why combine them?** Career development requires both *doing* and *thinking*. Kasm gives you a safe, disposable desktop where you can practice coding, build portfolios, and run tools without messing up your main machine. OpenClaw gives an AI assistant the ability to see your workspace, run commands, open applications, and interact with the tools inside it. Together, they create a career workspace where AI doesn't just advise — it *works alongside you*.

### Optional: CoeAdapt platform integration

> Career-Box works great on its own with any MCP-compatible AI assistant. For users who want more, it also integrates with the [CoeAdapt platform](https://coeadapt.com) for:
>
> - **Navi** — an AI career companion with career coaching, assessments, and personalized guidance
> - **Career tracking** — plans, tasks, goals, habits, job applications, portfolio, and skill verification
> - **Cloud sync** — your career data accessible from anywhere
>
> See [Connecting to CoeAdapt](#connecting-to-coeadapt) below.

### How it works

**Standalone mode** (default — no account needed):

```
┌────────────────────────────────────────────────────┐
│  Your Machine                                      │
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │  Career-Box Launcher (system tray)           │  │
│  │  Manages container lifecycle                 │  │
│  └──────┬───────────────────────────────────────┘  │
│         │                                          │
│    ┌────▼──────────────────────────┐               │
│    │ Docker Container               │               │
│    │ :6901 — Kasm Desktop           │               │
│    │ :18789 — CareerClaw Gateway    │               │
│    │          (OpenClaw MCP bridge)  │               │
│    └────────────────▲───────────────┘               │
│                     │                               │
│          ┌──────────┴──────────┐                    │
│          │ Claude Desktop /    │                    │
│          │ Any MCP-compatible  │                    │
│          │ AI assistant        │                    │
│          └─────────────────────┘                    │
└────────────────────────────────────────────────────┘
```

**With CoeAdapt** (optional — adds Navi, career tracking, cloud sync):

```
┌────────────────────────────────────────────────────────────┐
│  Navi (coeadapt.com/navi)                                  │
│  AI career companion — powered by OpenClaw agent framework │
└────────────────────┬───────────────────────────────────────┘
                     │  Cloud API
                     │
        ┌────────────▼───────────────────────────────┐
        │  Your Machine                              │
        │                                            │
        │  ┌──────────────────────────────────────┐  │
        │  │  Coeadapt Launcher (system tray)     │  │
        │  │  Manages container lifecycle         │  │
        │  └──────┬──────────────────────────────┘  │
        │         │                                  │
        │    ┌────▼──────────────────────────┐       │
        │    │ Docker Container               │       │
        │    │ :6901 — Kasm Desktop           │       │
        │    │ :18789 — CareerClaw Gateway    │       │
        │    │          (OpenClaw MCP bridge)  │       │
        │    └────────────────────────────────┘       │
        └────────────────────────────────────────────┘
```

The **Coeadapt Launcher** is a cross-platform desktop app (built with Tauri v2) that:
- Detects Docker/Podman and guides you through setup
- Pulls and manages the Kasm workspace container
- Lives in your system tray with start/stop/open controls

Once the workspace is running, **CareerClaw** (the OpenClaw-based AI agent inside the container) provides the MCP gateway on port 18789 — giving AI assistants full access to the workspace tools.

---

## What's inside the box

Career-Box includes **80+ containerized application images** inherited from [Kasm Workspaces](https://kasmweb.com), each built to stream a desktop or application through your browser:

| Category | Applications |
|----------|-------------|
| **Browsers** | Firefox, Chrome, Chromium, Brave, Edge, Vivaldi, Tor Browser |
| **Development** | VS Code, Atom, Sublime Text, Java Dev, Unity Hub |
| **Office & Productivity** | LibreOffice, OnlyOffice, Obsidian, Thunderbird |
| **Communication** | Slack, Discord, Teams, Telegram, Signal, Zoom |
| **Creative** | GIMP, Inkscape, Pinta, Blender, Audacity |
| **Security & OSINT** | Kali Linux, ParrotOS, SpiderFoot, Nessus, Hunchly, Maltego, Forensic-OSINT |
| **Desktops** | Ubuntu (Jammy/Noble), Debian, Fedora, AlmaLinux, Rocky, Alpine, openSUSE, Oracle |
| **Utilities** | Remmina, FileZilla, VLC, Deluge, qBittorrent |

Each image is a self-contained Docker container with KasmVNC for browser-based access. The career workspace image bundles the most useful tools into a single desktop environment.

---

## Career capabilities

When connected to AI (Claude, Navi, or any MCP-compatible assistant), Career-Box becomes an intelligent workspace for:

- **Resume building** — AI reads your drafts, tailors them to job postings, and writes cover letters
- **Interview prep** — Practice answers out loud, get feedback, run mock interviews
- **Job tracking** — Maintain application pipelines with company research auto-populated
- **Skill development** — Follow structured learning paths with hands-on practice in the workspace
- **Career journaling** — Structured reflection with AI-powered theme analysis
- **Portfolio building** — Build projects, generate documentation, publish to GitHub
- **Networking** — Draft outreach emails, track contacts, manage follow-ups
- **Market research** — Analyze job markets, salary benchmarks, and emerging opportunities

All powered by CareerClaw's OpenClaw gateway — providing shell execution, browser automation, file management, web search, and persistent memory inside the workspace.

---

## Quick start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) or [Podman Desktop](https://podman-desktop.io/)
- 15 GB free disk space (25 GB recommended)

### Install

Download the latest release for your platform from the [Releases](https://github.com/coeadapt/Career-Box/releases) page:

| Platform | Download |
|----------|----------|
| Windows  | `.msi` installer |
| macOS    | `.dmg` |
| Linux    | `.AppImage` or `.deb` |

### Run (standalone)

1. Launch **Career-Box** from your applications
2. The setup wizard walks you through everything (Docker check, image download, workspace start)
3. Click **Open Workspace** to access your career desktop in the browser
4. CareerClaw AI gateway starts automatically inside the workspace

No account required. No sign-up. Just launch and go.

### Run (with CoeAdapt)

1. Create an account at [coeadapt.com](https://coeadapt.com)
2. Configure your Clerk key (see [Connecting to CoeAdapt](#connecting-to-coeadapt))
3. Launch the app and sign in
4. Get access to Navi, career tracking, and cloud sync

---

## Connecting to CoeAdapt

> **This section is optional.** Career-Box works fully without CoeAdapt.

To connect Career-Box to the CoeAdapt platform for Navi, career tracking, and cloud sync:

1. Create an account at [coeadapt.com](https://coeadapt.com)
2. Copy your Clerk publishable key from your CoeAdapt dashboard
3. Edit `coeadapt-launcher/.env`:
   ```env
   VITE_CLERK_PUBLISHABLE_KEY=pk_live_YOUR_KEY_HERE
   VITE_COEADAPT_API_URL=https://api.coeadapt.com
   ```
4. Restart the launcher

This enables:
- Sign-in with your CoeAdapt account
- Navi AI career companion in the Dashboard
- Career tracking and progress sync
- Device token management for API access

When no valid Clerk key is configured (the default), standalone mode activates automatically. See [Environment configuration](#environment-configuration) for details.

---

## Project structure

```
Career-Box/
├── coeadapt-launcher/          # Tauri v2 desktop launcher app
│   ├── src/                    #   React frontend (TypeScript + Tailwind)
│   └── src-tauri/              #   Rust backend (container mgmt, health checks)
├── src/
│   ├── ubuntu/install/         #   Ubuntu application install scripts
│   ├── alpine/install/         #   Alpine install scripts
│   ├── opensuse/install/       #   openSUSE install scripts
│   └── common/                 #   Shared resources
├── docs/                       #   Per-application documentation (80+ READMEs)
├── ci-scripts/                 #   CI/CD pipeline scripts
├── dockerfile-kasm-*           #   Dockerfiles for each application image
├── CONTRIBUTING.md             #   Contributor guide
├── SECURITY.md                 #   Security hardening documentation
└── LICENSE.md                  #   MIT License
```

For detailed launcher documentation, see [coeadapt-launcher/README.md](coeadapt-launcher/README.md).

---

## For developers

Welcome. This project has two distinct halves, and you can contribute to either without understanding the other.

### The launcher (`coeadapt-launcher/`)

A Tauri v2 desktop app — React frontend, Rust backend. This is where most active development happens. If you've worked with React, TypeScript, or Rust, you'll feel at home here.

**Setup:**

```bash
cd coeadapt-launcher

# Install dependencies
bun install

# Run in dev mode (Vite HMR + Tauri window)
bun run tauri dev
```

**Requirements:** [Bun](https://bun.sh/), [Rust](https://rustup.rs/), [Docker Desktop](https://www.docker.com/products/docker-desktop/)

**Build for production:**

```bash
# Build the Tauri app (produces platform installers in src-tauri/target/release/bundle/)
bun run tauri build
```

For the full launcher architecture, see [coeadapt-launcher/README.md](coeadapt-launcher/README.md).

### The workspace images (`src/`, `dockerfile-kasm-*`)

80+ Dockerfiles and install scripts inherited from [Kasm Workspaces](https://github.com/kasmtech/workspaces-images). Each image defines a containerized application or desktop environment.

**To build an image:**

```bash
sudo docker build -t kasmweb/firefox:dev -f dockerfile-kasm-firefox .
```

**To run it standalone (browser access at `https://localhost:6901`):**

```bash
sudo docker run --rm -it --shm-size=512m -p 6901:6901 -e VNC_PW=password kasmweb/firefox:dev
```

Each image has an install script in `src/ubuntu/install/<name>/` and documentation in `docs/<name>/README.md`. Follow the existing patterns when adding or modifying images. For the full image building guide, see Kasm's [How To Guide](https://kasmweb.com/docs/latest/how_to/building_images.html).

### Environment configuration

Career-Box has two modes, auto-detected from `.env`:

| Mode | When | What you get |
|------|------|-------------|
| **Standalone** (default) | No Clerk key, or `pk_test_REPLACE_ME` | Workspace + CareerClaw AI gateway + any MCP-compatible AI |
| **CoeAdapt** | Valid Clerk publishable key | + Navi chat, career tracking, account management, cloud sync |

The default `.env` ships with `pk_test_REPLACE_ME`, which activates standalone mode. You can develop and test all workspace, container, and AI features without a CoeAdapt account.

To develop CoeAdapt-specific features (Navi chat, career tracking, account management), you'll need a valid Clerk key. Contact the maintainers or sign up at [coeadapt.com](https://coeadapt.com).

The mode detection lives in `coeadapt-launcher/src/lib/mode.ts`.

### Where to start

| Interest | Start here |
|----------|-----------|
| Frontend / UI | `coeadapt-launcher/src/pages/` and `src/components/` — React + Tailwind |
| Backend / Systems | `coeadapt-launcher/src-tauri/src/` — Rust, Docker management, health checks |
| AI / CareerClaw | `src/ubuntu/install/careerclaw/` — OpenClaw integration and gateway config |
| Container images | `src/ubuntu/install/` — add new apps or fix existing install scripts |
| Security | [SECURITY.md](SECURITY.md) — review the audit, fix remaining issues |
| Documentation | `docs/` — 80+ app READMEs, or improve this README |

---

## Built on open source

Career-Box stands on the shoulders of two major open-source projects:

### Kasm Workspaces

This repository is a fork of [kasmtech/workspaces-images](https://github.com/kasmtech/workspaces-images) by [Kasm Technologies](https://kasmweb.com). Kasm Workspaces is a container streaming platform that delivers browser-based access to desktops and applications using [KasmVNC](https://github.com/kasmtech/KasmVNC). The 80+ Dockerfiles and install scripts in this repo come from Kasm's upstream project.

- **Upstream repo:** [github.com/kasmtech/workspaces-images](https://github.com/kasmtech/workspaces-images)
- **Core images:** [github.com/kasmtech/workspaces-core-images](https://github.com/kasmtech/workspaces-core-images)
- **KasmVNC:** [github.com/kasmtech/KasmVNC](https://github.com/kasmtech/KasmVNC)
- **Docs:** [kasmweb.com/docs](https://kasmweb.com/docs/latest/how_to/building_images.html)

### OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) is an open-source AI agent framework that gives assistants real tools — shell execution, web search, browser automation, file system access, persistent memory, and proactive scheduling. Career-Box uses OpenClaw's architecture to power CareerClaw, the career-specific agent layer that turns the Kasm workspace into an intelligent career development environment.

- **Upstream repo:** [github.com/openclaw/openclaw](https://github.com/openclaw/openclaw)
- **CareerClaw fork:** [github.com/alexander-acker/careerclaw](https://github.com/alexander-acker/careerclaw)
- **Skills hub:** [github.com/openclaw/clawhub](https://github.com/openclaw/clawhub)

### What Career-Box adds

- The **Career-Box Launcher** — a Tauri v2 desktop app for managing workspace containers without touching Docker
- **CareerClaw** — career-specific OpenClaw agent with gateway, skills for coaching, assessments, resume building, interview prep, and job tracking
- **Security hardening** — patches to upstream Kasm scripts (see [SECURITY.md](SECURITY.md) for the full audit)
- **Optional CoeAdapt integration** — connect to [coeadapt.com](https://coeadapt.com) for Navi AI coaching, career tracking, and cloud sync

The Kasm workspace images and install scripts in this repository are used as-is or with security patches documented in SECURITY.md.

---

## Tech stack

| Component | Technology |
|-----------|-----------|
| Desktop launcher | Tauri v2, React 19, TypeScript, Tailwind CSS v4 |
| Launcher backend | Rust (tokio, reqwest, sysinfo) |
| AI agent | CareerClaw (OpenClaw fork), Node.js |
| Container runtime | Docker / Podman |
| Desktop streaming | KasmVNC (via Kasm Workspaces) |
| Package manager | Bun |

---

## Why we're building this

The world is adapting. AI is reshaping industries, automating tasks, and redefining what it means to have a career. Roles that existed for decades are changing overnight. New ones are appearing faster than anyone can track.

This is not something to fear. But it is something we have a responsibility to face honestly.

Not everyone has a software engineering background. Not everyone has a mentor, a network, or the time to figure out what's next on their own. But everyone deserves to be equipped for what's coming. No one should be left behind because they didn't have the right tools or the right guidance at the right moment.

Tasks will be automated. Roles will change. But the deeply personal endeavour of contributing to something meaningful — of finding work that matters to you and building a life around it — that will never change. That's the part worth protecting.

Career-Box exists because we believe AI should be the great equalizer, not the great divider. We're building a tool that puts an AI career coach and a fully equipped workspace in the hands of anyone who needs it — not just the people who already know how to code or already have access to the best opportunities.

If you're here, you're part of that mission. Welcome to the community. What we're building together has the potential to genuinely change lives — to help people navigate the most uncertain career landscape in a generation, and to come out the other side doing work they care about.

We're called to adapt. Let's make sure no one has to do it alone.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, guidelines, and how to submit changes.

## Security

See [SECURITY.md](SECURITY.md) for the security audit, hardening documentation, and how to report vulnerabilities.

## License

[MIT License](LICENSE.md). Workspace image scripts originally by [Kasm Technologies Inc](https://kasmweb.com), with additional work by [Coeadapt](https://coeadapt.com).
