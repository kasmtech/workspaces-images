# Contributing to Career-Box

Thanks for your interest in contributing. Career-Box is an open-source project and we welcome contributions of all kinds — bug fixes, new workspace images, launcher improvements, documentation, and more.

## Getting started

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) or [Podman Desktop](https://podman-desktop.io/)
- [Bun](https://bun.sh/) (for the launcher frontend and MCP server)
- [Rust](https://rustup.rs/) (for the Tauri backend)
- [Git](https://git-scm.com/)

### Setup

```bash
# Clone the repo
git clone https://github.com/coeadapt/Career-Box.git
cd Career-Box

# Install launcher dependencies
cd coeadapt-launcher
bun install
cd mcp-server && bun install && cd ..

# Run the launcher in dev mode
bun run tauri dev
```

## What you can work on

### Workspace images

The `dockerfile-kasm-*` files and `src/*/install/` scripts define the containerized applications. To add or modify an image:

1. Create or edit a `dockerfile-kasm-<name>` in the repo root
2. Add install scripts in `src/ubuntu/install/<name>/`
3. Add documentation in `docs/<name>/README.md`
4. Test the build: `docker build -t kasmweb/<name>:dev -f dockerfile-kasm-<name> .`

Follow the patterns in existing images. See Kasm's [image building guide](https://kasmweb.com/docs/latest/how_to/building_images.html) for details on how Kasm images work.

### Coeadapt Launcher

The launcher lives in `coeadapt-launcher/` and is built with Tauri v2 + React + TypeScript. See [coeadapt-launcher/README.md](coeadapt-launcher/README.md) for the full architecture and project structure.

- **Frontend** (`src/`): React components, pages, hooks, and utilities
- **Backend** (`src-tauri/`): Rust commands for Docker management, disk monitoring, health checks
- **MCP Server** (`mcp-server/`): Node.js server exposing workspace tools via the Model Context Protocol

### Documentation

Improvements to READMEs, guides, and inline comments are always welcome.

## Submitting changes

1. Fork the repository
2. Create a feature branch from `develop`: `git checkout -b feature/my-change`
3. Make your changes
4. Test locally (build the launcher, build any modified Docker images)
5. Commit with a clear message describing what and why
6. Open a pull request against `develop`

### Commit messages

Use clear, descriptive commit messages. Prefix with the area of change:

- `feat:` — new features
- `fix:` — bug fixes
- `docs:` — documentation changes
- `security:` — security patches
- `refactor:` — code restructuring without behavior change

### Pull request guidelines

- Keep PRs focused — one logical change per PR
- Include a description of what changed and why
- If adding a new workspace image, include a screenshot or description of what it provides
- Reference any related issues

## Security

If you discover a security vulnerability, please **do not** open a public issue. See [SECURITY.md](SECURITY.md) for responsible disclosure guidelines.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE.md).
