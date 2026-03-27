import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { isContainerRunning } from "../docker-exec.js";

export function registerWorkspaceStatus(
  server: McpServer,
  onToolCall: () => void,
) {
  server.tool(
    "workspace_status",
    "Check if the Coeadapt workspace is running and healthy",
    {},
    async () => {
      onToolCall();
      const running = await isContainerRunning();
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              running,
              url: running ? "https://localhost:6901" : null,
              status: running ? "healthy" : "stopped",
            }),
          },
        ],
      };
    },
  );
}
