import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { dockerExec } from "../docker-exec.js";

export function registerFilesystemTools(
  server: McpServer,
  onToolCall: () => void,
) {
  server.tool(
    "read_file",
    "Read a file from the workspace filesystem",
    { path: z.string().describe("Absolute path to the file") },
    async ({ path }) => {
      onToolCall();
      try {
        const { stdout } = await dockerExec(`cat "${path}"`);
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

  server.tool(
    "write_file",
    "Write content to a file in the workspace",
    {
      path: z.string().describe("Absolute path to write"),
      content: z.string().describe("Content to write"),
    },
    async ({ path, content }) => {
      onToolCall();
      try {
        const b64 = Buffer.from(content).toString("base64");
        await dockerExec(`echo "${b64}" | base64 -d > "${path}"`);
        return {
          content: [{ type: "text" as const, text: `Written to ${path}` }],
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

  server.tool(
    "list_files",
    "List files and directories at a given path",
    {
      path: z
        .string()
        .describe("Directory path to list")
        .default("/home/kasm-user"),
    },
    async ({ path }) => {
      onToolCall();
      try {
        const { stdout } = await dockerExec(`ls -la "${path}"`);
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
