import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { dockerExec } from "../docker-exec.js";

export function registerScreenshot(
  server: McpServer,
  onToolCall: () => void,
) {
  server.tool(
    "take_screenshot",
    "Capture a screenshot of the current workspace desktop",
    {},
    async () => {
      onToolCall();
      try {
        // Use xwd + convert or import to capture the screen
        await dockerExec(
          "DISPLAY=:1 import -window root /tmp/screenshot.png 2>/dev/null || " +
          "DISPLAY=:1 xdotool key --delay 100 Print && sleep 1",
        );
        const { stdout } = await dockerExec(
          "base64 -w 0 /tmp/screenshot.png 2>/dev/null || echo 'NO_SCREENSHOT'",
        );
        if (stdout === "NO_SCREENSHOT") {
          return {
            content: [
              {
                type: "text" as const,
                text: "Screenshot capture not available. Install imagemagick in the workspace.",
              },
            ],
          };
        }
        return {
          content: [
            {
              type: "image" as const,
              data: stdout,
              mimeType: "image/png",
            },
          ],
        };
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
