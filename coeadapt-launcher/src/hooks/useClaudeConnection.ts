import { useState, useEffect, useCallback } from "react";
import { tauri } from "../lib/tauri";
import type { ClaudeStatus } from "../lib/types";

export function useClaudeConnection() {
  const [status, setStatus] = useState<ClaudeStatus | null>(null);
  const [mcpConnected, setMcpConnected] = useState(false);
  const [configuring, setConfiguring] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const claudeStatus = await tauri.getClaudeStatus();
      setStatus(claudeStatus);
      const mcp = await tauri.checkMcpStatus();
      setMcpConnected(mcp);
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

  return { status, mcpConnected, configuring, configureClaude, refresh };
}
