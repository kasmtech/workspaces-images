import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { dockerExec } from "../docker-exec.js";

export function registerGetProgress(
  server: McpServer,
  onToolCall: () => void,
) {
  server.tool(
    "get_user_progress",
    "Get the user's career development progress and completed activities",
    {},
    async () => {
      onToolCall();
      try {
        const { stdout } = await dockerExec(
          "cat /home/kasm-user/.coeadapt/progress.json 2>/dev/null || " +
          'echo \'{"activities":[],"assessments":[],"progress_percent":0}\'',
        );
        return { content: [{ type: "text" as const, text: stdout }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.stderr || err.message}` },
          ],
          isError: true,
        };
      }
    },
  );
}
