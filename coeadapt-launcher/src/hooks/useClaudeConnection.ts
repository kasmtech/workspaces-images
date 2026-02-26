import { useState, useEffect, useCallback } from "react";
import { tauri } from "../lib/tauri";
import type { ClaudeStatus, McpHealthInfo } from "../lib/types";

export function useClaudeConnection() {
  const [status, setStatus] = useState<ClaudeStatus | null>(null);
  const [mcpConnected, setMcpConnected] = useState(false);
  const [mcpHealth, setMcpHealth] = useState<McpHealthInfo | null>(null);
  const [configuring, setConfiguring] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const claudeStatus = await tauri.getClaudeStatus();
      setStatus(claudeStatus);
      const health = await tauri.getMcpHealth();
      setMcpConnected(health.is_running);
      setMcpHealth(health);
    } catch {
      // Ignore
    }
  }, []);

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 30000);
    return () => clearInterval(interval);
  }, [refresh]);

  const configureClaude = useCallback(async () => {
    setConfiguring(true);
    try {
      await tauri.configureClaude();
      await refresh();
    } catch {
      // Ignore
    } finally {
      setConfiguring(false);
    }
  }, [refresh]);

  // MCP is connected but no tool calls for 5+ minutes
  const isIdle =
    mcpConnected &&
    mcpHealth?.last_tool_call != null &&
    Date.now() - mcpHealth.last_tool_call > 5 * 60 * 1000;

  return { status, mcpConnected, mcpHealth, isIdle, configuring, configureClaude, refresh };
}
