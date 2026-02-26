import { execSync } from "node:child_process";
import { mkdirSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const outDir = join(__dirname, "..", "src-tauri", "binaries");

// Determine target triple for Tauri sidecar naming
function getTargetTriple(): string {
  const platform = process.platform;
  const arch = process.arch;

  if (platform === "win32") {
    return arch === "arm64"
      ? "aarch64-pc-windows-msvc"
      : "x86_64-pc-windows-msvc";
  }
  if (platform === "darwin") {
    return arch === "arm64"
      ? "aarch64-apple-darwin"
      : "x86_64-apple-darwin";
  }
  // Linux
  return arch === "arm64"
    ? "aarch64-unknown-linux-gnu"
    : "x86_64-unknown-linux-gnu";
}

const triple = getTargetTriple();
const ext = process.platform === "win32" ? ".exe" : "";
const outFile = join(outDir, `coeadapt-mcp-${triple}${ext}`);

// Ensure output directory exists
if (!existsSync(outDir)) {
  mkdirSync(outDir, { recursive: true });
}

console.log(`Building MCP server sidecar for ${triple}...`);
console.log(`Output: ${outFile}`);

execSync(
  `bun build src/index.ts --compile --outfile "${outFile}"`,
  { cwd: __dirname, stdio: "inherit" },
);

console.log("Build complete!");
