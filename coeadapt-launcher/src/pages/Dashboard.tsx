import { useNavigate } from "react-router-dom";
import { useContainer } from "../hooks/useContainer";
import { useDiskSpace } from "../hooks/useDiskSpace";
import { useClaudeConnection } from "../hooks/useClaudeConnection";
import { STANDALONE_MODE } from "../lib/mode";
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
  const navigate = useNavigate();
  const container = useContainer();
  const disk = useDiskSpace();
  const claude = useClaudeConnection();

  const handleStart = async () => {
    if (container.status?.state === "NotFound") await container.createWorkspace();
    else await container.startWorkspace();
  };

  return (
    <div className="min-h-screen bg-surface-0 flex flex-col">
      <header className="flex items-center justify-between px-6 py-4 border-b border-surface-300/50">
        <div className="flex items-center gap-3">
          <img src="/logo-color.png" alt="" className="w-7 h-7" />
          <span className="font-semibold text-lg">{STRINGS.APP_NAME}</span>
        </div>
        <button onClick={() => navigate("/settings")} className="p-2 rounded-lg hover:bg-surface-200 transition-colors text-text-muted hover:text-text-secondary">
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z" /><path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" /></svg>
        </button>
      </header>

      <div className="flex-1 overflow-y-auto p-6">
        <div className="max-w-lg mx-auto space-y-4">
          {/* Workspace */}
          <div className="glass-card p-6 space-y-5 animate-fade-in">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${container.isRunning ? "bg-success/10" : "bg-surface-300"}`}>
                <svg className={`w-5 h-5 ${container.isRunning ? "text-success" : "text-text-muted"}`} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M9 17.25v1.007a3 3 0 0 1-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0 1 15 18.257V17.25m6-12V15a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 15V5.25m18 0A2.25 2.25 0 0 0 18.75 3H5.25A2.25 2.25 0 0 0 3 5.25m18 0V12a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 12V5.25" /></svg>
              </div>
              <div>
                <h3 className="font-medium text-sm">Workspace</h3>
                <StatusIndicator status={container.status ? stateToIndicator(container.status.state) : "stopped"} label={container.status ? stateLabel(container.status.state) : "Loading..."} />
              </div>
            </div>
            <WorkspaceControls isRunning={container.isRunning} isStopped={container.isStopped} loading={container.loading} onStart={handleStart} onStop={container.stopWorkspace} onOpen={container.openWorkspace} />
            {container.isRunning && container.sslTrusted === false && (
              <div className="rounded-lg border border-warning/30 bg-warning/5 p-3 space-y-2">
                <p className="text-xs text-text-secondary">
                  Your browser will show a security warning when opening the workspace.
                  Install the workspace certificate to fix this.
                </p>
                <button
                  onClick={container.installSslCertificate}
                  disabled={container.sslInstalling}
                  className="btn-primary text-xs py-1.5 px-3"
                >
                  {container.sslInstalling ? "Installing..." : "Trust Workspace Certificate"}
                </button>
              </div>
            )}
            {container.error && <p className="text-danger text-sm">{container.error}</p>}
          </div>

          {/* AI Connection */}
          <div className="glass-card p-6 space-y-4 animate-fade-in delay-100">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${claude.mcpConnected ? "bg-brand-600/10" : "bg-surface-300"}`}>
                <svg className={`w-5 h-5 ${claude.mcpConnected ? "text-brand-400" : "text-text-muted"}`} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 0 0-2.455 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z" /></svg>
              </div>
              <div>
                <h3 className="font-medium text-sm">AI Copilot</h3>
                <StatusIndicator status={claude.mcpConnected ? "running" : "stopped"} label={claude.mcpConnected ? STRINGS.AI_CONNECTED : STRINGS.AI_DISCONNECTED} />
              </div>
            </div>
            {claude.isIdle && (
              <p className="text-xs text-text-faint">
                No AI activity for a while. This is normal when you're not using AI tools.
              </p>
            )}
            {claude.status?.is_installed && !claude.status?.is_configured && (
              <button onClick={claude.configureClaude} disabled={claude.configuring} className="btn-primary text-sm">
                {claude.configuring ? "Connecting..." : "Connect to Claude"}
              </button>
            )}
          </div>

          {/* Cora - AI Career Companion (CoeAdapt mode only) */}
          {!STANDALONE_MODE && (
            <div className="glass-card p-6 space-y-4 animate-fade-in delay-200">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center bg-brand-600/10">
                  <svg className="w-5 h-5 text-brand-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 0 1-.825-.242m9.345-8.334a2.126 2.126 0 0 0-.476-.095 48.64 48.64 0 0 0-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0 0 11.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155" /></svg>
                </div>
                <div>
                  <h3 className="font-medium text-sm">Cora</h3>
                  <p className="text-xs text-text-muted">AI Career Companion</p>
                </div>
              </div>
              <p className="text-xs text-text-tertiary">
                Get career guidance, track goals, and build your mastery with Cora.
              </p>
              <button onClick={() => navigate("/chat")} className="btn-primary text-sm w-full">
                Chat with Cora
              </button>
            </div>
          )}

          {/* Disk */}
          {disk.status && (
            <div className="glass-card p-6 animate-fade-in delay-300">
              <DiskUsage status={disk.status} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
