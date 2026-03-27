import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { dockerExec } from "../docker-exec.js";

const APP_MAP: Record<string, string> = {
  firefox: "firefox",
  chrome: "google-chrome",
  "google-chrome": "google-chrome",
  terminal: "xfce4-terminal",
  "file-manager": "thunar",
  "text-editor": "xfce4-terminal -e nano",
  vscode: "code",
  "vs-code": "code",
  gimp: "gimp",
  thunderbird: "thunderbird",
  onlyoffice: "onlyoffice-desktopeditors",
  vlc: "vlc",
};

export function registerOpenApplication(
  server: McpServer,
  onToolCall: () => void,
) {
  server.tool(
    "open_application",
    "Launch an application in the workspace",
    { app_name: z.string().describe("Application name (e.g., firefox, chrome, terminal, vscode)") },
    async ({ app_name }) => {
      onToolCall();
      const cmd = APP_MAP[app_name.toLowerCase()] || app_name;
      try {
        await dockerExec(`DISPLAY=:1 nohup ${cmd} > /dev/null 2>&1 &`);
        return {
          content: [
            { type: "text" as const, text: `Launched ${app_name}` },
          ],
        };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error launching ${app_name}: ${err.stderr || err.message}` },
          ],
          isError: true,
        };
      }
    },
  );
}
