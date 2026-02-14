import { useContainer } from "../hooks/useContainer";
import { useDiskSpace } from "../hooks/useDiskSpace";
import { useClaudeConnection } from "../hooks/useClaudeConnection";
import { StatusIndicator } from "../components/StatusIndicator";
import { WorkspaceControls } from "../components/WorkspaceControls";
import { DiskUsage } from "../components/DiskUsage";
import { STRINGS } from "../lib/constants";
import type { ContainerState } from "../lib/types";

function stateToIndicator(state: ContainerState): "running" | "starting" | "stopped" | "error" {
  if (state === "Running") return "running";
  if (state === "Starting" || state === "Pulling") return "starting";
  if (state === "Stopped" || state === "NotFound") return "stopped";
  return "error";
}

function stateLabel(state: ContainerState): string {
  if (state === "Running") return STRINGS.DASHBOARD_RUNNING;
  if (state === "Stopped" || state === "NotFound") return STRINGS.DASHBOARD_STOPPED;
  if (state === "Starting") return "Starting...";
  if (state === "Pulling") return "Downloading...";
  if (typeof state === "object" && "Error" in state) return state.Error;
  return "Unknown";
}

export default function Dashboard() {
  const container = useContainer();
  const disk = useDiskSpace();
  const claude = useClaudeConnection();

  const handleStart = async () => {
    if (container.status?.state === "NotFound") {
      await container.createWorkspace();
    } else {
      await container.startWorkspace();
    }
  };

  return (
    <div className="min-h-screen bg-navy-900 p-8">
      <div className="max-w-2xl mx-auto space-y-8">
        <h1 className="text-2xl font-bold text-white">{STRINGS.APP_NAME}</h1>

        {/* Workspace Status */}
        <div className="bg-navy-800 rounded-xl p-6 space-y-6">
          <div className="flex items-center justify-between">
            <StatusIndicator
              status={container.status ? stateToIndicator(container.status.state) : "stopped"}
              label={container.status ? stateLabel(container.status.state) : "Loading..."}
            />
          </div>

          <WorkspaceControls
            isRunning={container.isRunning}
            isStopped={container.isStopped}
            loading={container.loading}
            onStart={handleStart}
            onStop={container.stopWorkspace}
            onOpen={container.openWorkspace}
          />

          {container.error && (
            <p className="text-red-400 text-sm">{container.error}</p>
          )}
        </div>

        {/* AI Connection */}
        <div className="bg-navy-800 rounded-xl p-6 space-y-4">
          <StatusIndicator
            status={claude.mcpConnected ? "running" : "stopped"}
            label={claude.mcpConnected ? STRINGS.AI_CONNECTED : STRINGS.AI_DISCONNECTED}
          />
          {claude.status?.is_installed && !claude.status?.is_configured && (
            <button
              onClick={claude.configureClaude}
              disabled={claude.configuring}
              className="px-4 py-2 bg-coral-500 hover:bg-coral-600 text-white rounded-lg text-sm disabled:opacity-50"
            >
              {claude.configuring ? "Connecting..." : "Connect to Claude"}
            </button>
          )}
        </div>

        {/* Disk Usage */}
        {disk.status && (
          <div className="bg-navy-800 rounded-xl p-6">
            <DiskUsage status={disk.status} />
          </div>
        )}
      </div>
    </div>
  );
}
