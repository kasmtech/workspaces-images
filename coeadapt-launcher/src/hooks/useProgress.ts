import { useState, useEffect, useCallback } from "react";
import type { ProgressSummary, AgentHealthInfo } from "../lib/types";

const PROGRESS_POLL_INTERVAL = 30_000; // 30 seconds

/**
 * Fetches progress summary from the in-VM agent via the MCP server health endpoint,
 * or falls back to docker exec for direct reads. In both cases, the data comes
 * from the progress tracker running inside the Kasm container.
 *
 * The MCP server is already running on the host at port 3100. We ask it to
 * proxy the progress summary request to the container.
 */
async function fetchProgressSummary(): Promise<ProgressSummary | null> {
  try {
    // The MCP health endpoint is always available on the host.
    // We piggyback a progress fetch by hitting the progress tracker
    // inside the container via the MCP server's tool mechanism.
    // However, for the dashboard we use a simpler direct approach:
    // hit the MCP server's health, then fetch progress via a lightweight
    // sidecar endpoint.
    const res = await fetch("http://127.0.0.1:3100/progress-summary", {
      signal: AbortSignal.timeout(5000),
    });
    if (res.ok) {
      return res.json();
    }
  } catch {
    // MCP progress endpoint not available — this is expected before
    // we add the proxy route. Return null to show "no data" state.
  }
  return null;
}

async function fetchAgentHealth(): Promise<AgentHealthInfo | null> {
  try {
    const res = await fetch("http://127.0.0.1:3100/agent-health", {
      signal: AbortSignal.timeout(5000),
    });
    if (res.ok) {
      return res.json();
    }
  } catch {
    // Not available
  }
  return null;
}

export function useProgress(isContainerRunning: boolean) {
  const [summary, setSummary] = useState<ProgressSummary | null>(null);
  const [agentHealth, setAgentHealth] = useState<AgentHealthInfo | null>(null);
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async () => {
    if (!isContainerRunning) {
      setSummary(null);
      setAgentHealth(null);
      return;
    }
    setLoading(true);
    try {
      const [summaryData, healthData] = await Promise.all([
        fetchProgressSummary(),
        fetchAgentHealth(),
      ]);
      setSummary(summaryData);
      setAgentHealth(healthData);
    } finally {
      setLoading(false);
    }
  }, [isContainerRunning]);

  useEffect(() => {
    refresh();
    if (!isContainerRunning) return;
    const interval = setInterval(refresh, PROGRESS_POLL_INTERVAL);
    return () => clearInterval(interval);
  }, [refresh, isContainerRunning]);

  return { summary, agentHealth, loading, refresh };
}
