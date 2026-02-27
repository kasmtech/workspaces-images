import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createServer } from "node:http";

import { registerWorkspaceStatus } from "./tools/workspace.js";
import { registerFilesystemTools } from "./tools/filesystem.js";
import { registerRunCommand } from "./tools/commands.js";
import { registerScreenshot } from "./tools/screenshot.js";
import { registerOpenApplication } from "./tools/applications.js";
import { registerGetProgress } from "./tools/progress.js";
import { registerComputerUseTools } from "./tools/computer-use.js";
import { dockerExec } from "./docker-exec.js";

const PORT = 3100;
const HOST = "127.0.0.1";

let lastToolCall = Date.now();

function onToolCall() {
  lastToolCall = Date.now();
}

// Create MCP server
const server = new McpServer({
  name: "coeadapt",
  version: "0.1.0",
});

// Register all tools
registerWorkspaceStatus(server, onToolCall);
registerFilesystemTools(server, onToolCall);
registerRunCommand(server, onToolCall);
registerScreenshot(server, onToolCall);
registerOpenApplication(server, onToolCall);
registerGetProgress(server, onToolCall);
registerComputerUseTools(server, onToolCall);

// Create HTTP server with Streamable HTTP transport
const httpServer = createServer(async (req, res) => {
  const url = new URL(req.url ?? "/", `http://${HOST}:${PORT}`);

  // Health endpoint
  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        status: "ok",
        lastToolCall,
        uptime: process.uptime(),
      }),
    );
    return;
  }

  // Progress summary proxy — fetches from in-VM progress tracker for the dashboard UI
  if (url.pathname === "/progress-summary") {
    try {
      const { stdout } = await dockerExec(
        "curl -sf -m 3 http://127.0.0.1:7700/progress/summary 2>/dev/null || " +
        'echo \'{"progress_percent":0,"streak_days":0,"total_activities":0,"total_goals":0,"completed_goals":0,"total_skills":0,"total_milestones":0,"last_activity_at":null}\'',
      );
      res.writeHead(200, {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      });
      res.end(stdout);
    } catch {
      res.writeHead(200, {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      });
      res.end(JSON.stringify({
        progress_percent: 0,
        streak_days: 0,
        total_activities: 0,
        total_goals: 0,
        completed_goals: 0,
        total_skills: 0,
        total_milestones: 0,
        last_activity_at: null,
      }));
    }
    return;
  }

  // Agent health proxy — reports status of in-VM services
  if (url.pathname === "/agent-health") {
    let progressOk = false;
    let computerOk = false;
    try {
      const { stdout } = await dockerExec(
        "curl -sf -m 2 http://127.0.0.1:7700/health >/dev/null 2>&1 && echo ok || echo down",
      );
      progressOk = stdout.trim() === "ok";
    } catch {}
    try {
      const { stdout } = await dockerExec(
        "curl -sf -m 2 http://127.0.0.1:7701/health >/dev/null 2>&1 && echo ok || echo down",
      );
      computerOk = stdout.trim() === "ok";
    } catch {}
    res.writeHead(200, {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    });
    res.end(JSON.stringify({
      progress_tracker: progressOk ? "ok" : "down",
      computer_use: computerOk ? "ok" : "down",
    }));
    return;
  }

  // MCP endpoint
  if (url.pathname === "/mcp") {
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
    });
    await server.connect(transport);
    await transport.handleRequest(req, res);
    return;
  }

  // 404 for everything else
  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

httpServer.listen(PORT, HOST, () => {
  console.log(`Coeadapt MCP server listening on http://${HOST}:${PORT}`);
  console.log(`  MCP endpoint: http://${HOST}:${PORT}/mcp`);
  console.log(`  Health check: http://${HOST}:${PORT}/health`);
});

// Graceful shutdown
process.on("SIGINT", () => {
  console.log("Shutting down MCP server...");
  httpServer.close();
  process.exit(0);
});

process.on("SIGTERM", () => {
  httpServer.close();
  process.exit(0);
});
