import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { dockerExec } from "../docker-exec.js";

export function registerRunCommand(
  server: McpServer,
  onToolCall: () => void,
) {
  server.tool(
    "run_command",
    "Execute a shell command inside the workspace",
    { command: z.string().describe("Shell command to execute") },
    async ({ command }) => {
      onToolCall();
      try {
        const { stdout, stderr } = await dockerExec(command);
        const output = stdout + (stderr ? `\nSTDERR: ${stderr}` : "");
        return { content: [{ type: "text" as const, text: output }] };
      } catch (err: any) {
        return {
          content: [
            {
              type: "text" as const,
              text: `Error (exit ${err.code}): ${err.stderr || err.message}`,
            },
          ],
          isError: true,
        };
      }
    },
  );
}
