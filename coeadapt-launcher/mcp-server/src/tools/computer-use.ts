import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { dockerExec } from "../docker-exec.js";

/**
 * Helper to call the in-VM computer-use HTTP service.
 * Falls back to direct xdotool commands if the service is unavailable.
 */
async function curlAgent(
  method: "GET" | "POST",
  path: string,
  body?: Record<string, unknown>,
): Promise<string> {
  const curlArgs = [
    "curl", "-sf", "-m", "10",
    "-H", "Content-Type: application/json",
  ];
  if (method === "POST" && body) {
    curlArgs.push("-X", "POST", "-d", JSON.stringify(body));
  }
  curlArgs.push(`http://127.0.0.1:7701${path}`);
  const { stdout } = await dockerExec(curlArgs.join(" "));
  return stdout;
}

export function registerComputerUseTools(
  server: McpServer,
  onToolCall: () => void,
) {
  // -----------------------------------------------------------------------
  // Screenshot
  // -----------------------------------------------------------------------
  server.tool(
    "computer_screenshot",
    "Capture a screenshot of the workspace desktop. Returns a base64-encoded PNG image.",
    {
      region: z
        .object({
          x: z.number().describe("Left edge X coordinate"),
          y: z.number().describe("Top edge Y coordinate"),
          width: z.number().describe("Width in pixels"),
          height: z.number().describe("Height in pixels"),
        })
        .optional()
        .describe("Optional region to capture. Omit for full screen."),
    },
    async ({ region }) => {
      onToolCall();
      try {
        const body = region || {};
        const raw = await curlAgent("POST", "/screen/screenshot", body);
        const parsed = JSON.parse(raw);
        if (parsed.image) {
          return {
            content: [
              {
                type: "image" as const,
                data: parsed.image,
                mimeType: "image/png",
              },
            ],
          };
        }
        return {
          content: [{ type: "text" as const, text: "Screenshot capture failed" }],
          isError: true,
        };
      } catch (err: any) {
        // Fallback to direct import command
        try {
          await dockerExec(
            "DISPLAY=:1 import -window root /tmp/screenshot.png 2>/dev/null",
          );
          const { stdout } = await dockerExec(
            "base64 -w 0 /tmp/screenshot.png 2>/dev/null",
          );
          if (stdout && stdout !== "") {
            return {
              content: [
                { type: "image" as const, data: stdout, mimeType: "image/png" },
              ],
            };
          }
        } catch {}
        return {
          content: [
            {
              type: "text" as const,
              text: `Screenshot error: ${err.message || err}`,
            },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Screen info
  // -----------------------------------------------------------------------
  server.tool(
    "computer_screen_size",
    "Get the screen dimensions (width, height) of the workspace desktop",
    {},
    async () => {
      onToolCall();
      try {
        const raw = await curlAgent("GET", "/screen/size");
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Mouse: move
  // -----------------------------------------------------------------------
  server.tool(
    "computer_mouse_move",
    "Move the mouse cursor to the specified screen coordinates",
    {
      x: z.number().describe("X coordinate (pixels from left)"),
      y: z.number().describe("Y coordinate (pixels from top)"),
    },
    async ({ x, y }) => {
      onToolCall();
      try {
        const raw = await curlAgent("POST", "/mouse/move", { x, y });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Mouse: click
  // -----------------------------------------------------------------------
  server.tool(
    "computer_click",
    "Click at the current mouse position or at specific coordinates",
    {
      x: z.number().optional().describe("X coordinate to click at (moves mouse first if provided)"),
      y: z.number().optional().describe("Y coordinate to click at (moves mouse first if provided)"),
      button: z
        .enum(["left", "right", "middle"])
        .default("left")
        .describe("Mouse button: left (1), right (3), or middle (2)"),
      double: z
        .boolean()
        .default(false)
        .describe("If true, perform a double-click"),
    },
    async ({ x, y, button, double }) => {
      onToolCall();
      const btn = button === "right" ? 3 : button === "middle" ? 2 : 1;
      try {
        if (x !== undefined && y !== undefined) {
          const endpoint = double ? "/action/double_click_at" : "/action/click_at";
          const raw = await curlAgent("POST", endpoint, { x, y, button: btn });
          return { content: [{ type: "text" as const, text: raw }] };
        }
        const endpoint = double ? "/mouse/double_click" : "/mouse/click";
        const raw = await curlAgent("POST", endpoint, { button: btn });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Mouse: scroll
  // -----------------------------------------------------------------------
  server.tool(
    "computer_scroll",
    "Scroll the mouse wheel up or down",
    {
      direction: z.enum(["up", "down"]).describe("Scroll direction"),
      clicks: z
        .number()
        .default(3)
        .describe("Number of scroll clicks (default 3)"),
    },
    async ({ direction, clicks }) => {
      onToolCall();
      try {
        const raw = await curlAgent("POST", "/mouse/scroll", { direction, clicks });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Mouse: drag
  // -----------------------------------------------------------------------
  server.tool(
    "computer_drag",
    "Click-and-drag from one position to another",
    {
      x1: z.number().describe("Start X coordinate"),
      y1: z.number().describe("Start Y coordinate"),
      x2: z.number().describe("End X coordinate"),
      y2: z.number().describe("End Y coordinate"),
    },
    async ({ x1, y1, x2, y2 }) => {
      onToolCall();
      try {
        const raw = await curlAgent("POST", "/mouse/drag", { x1, y1, x2, y2 });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Keyboard: type text
  // -----------------------------------------------------------------------
  server.tool(
    "computer_type",
    "Type text using the keyboard. For special keys, use computer_key_press instead.",
    {
      text: z.string().describe("Text to type"),
      x: z.number().optional().describe("X coordinate to click before typing"),
      y: z.number().optional().describe("Y coordinate to click before typing"),
    },
    async ({ text, x, y }) => {
      onToolCall();
      try {
        if (x !== undefined && y !== undefined) {
          const raw = await curlAgent("POST", "/action/type_at", { x, y, text });
          return { content: [{ type: "text" as const, text: raw }] };
        }
        const raw = await curlAgent("POST", "/keyboard/type", { text });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Keyboard: press key(s)
  // -----------------------------------------------------------------------
  server.tool(
    "computer_key_press",
    "Press a key or key combination. Examples: 'Return', 'ctrl+c', 'alt+F4', 'ctrl+shift+t', 'BackSpace', 'Tab', 'Escape'",
    {
      keys: z
        .string()
        .describe(
          "Key combo using xdotool syntax (e.g. 'Return', 'ctrl+c', 'alt+Tab', 'super')",
        ),
    },
    async ({ keys }) => {
      onToolCall();
      try {
        const raw = await curlAgent("POST", "/keyboard/press", { keys });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Window: get active window info
  // -----------------------------------------------------------------------
  server.tool(
    "computer_active_window",
    "Get information about the currently active (focused) window",
    {},
    async () => {
      onToolCall();
      try {
        const raw = await curlAgent("GET", "/window/active");
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Window: list windows
  // -----------------------------------------------------------------------
  server.tool(
    "computer_list_windows",
    "List all visible windows on the desktop",
    {},
    async () => {
      onToolCall();
      try {
        const raw = await curlAgent("GET", "/window/list");
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Window: focus a specific window
  // -----------------------------------------------------------------------
  server.tool(
    "computer_focus_window",
    "Bring a specific window to the foreground by its window ID",
    {
      window_id: z.string().describe("The window ID (from computer_list_windows)"),
    },
    async ({ window_id }) => {
      onToolCall();
      try {
        const raw = await curlAgent("POST", "/window/focus", { window_id });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Mouse: get position
  // -----------------------------------------------------------------------
  server.tool(
    "computer_mouse_position",
    "Get the current mouse cursor position",
    {},
    async () => {
      onToolCall();
      try {
        const raw = await curlAgent("GET", "/mouse/position");
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );
}
