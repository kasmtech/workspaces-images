import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useDiskSpace } from "../hooks/useDiskSpace";
import { useClaudeConnection } from "../hooks/useClaudeConnection";
import { useSettings } from "../hooks/useSettings";
import { DiskUsage } from "../components/DiskUsage";
import { StatusIndicator } from "../components/StatusIndicator";
import { ToggleSwitch } from "../components/ToggleSwitch";
import { STRINGS } from "../lib/constants";
import { tauri } from "../lib/tauri";

type Tab = "ai" | "workspace" | "general";

export default function Settings() {
  const navigate = useNavigate();
  const [tab, setTab] = useState<Tab>("workspace");
  const disk = useDiskSpace();
  const claude = useClaudeConnection();
  const appSettings = useSettings();
  const [resetting, setResetting] = useState(false);
  const [pruning, setPruning] = useState(false);
  const [copied, setCopied] = useState(false);

  const tabs: { id: Tab; label: string }[] = [
    { id: "ai", label: "AI Connection" },
    { id: "workspace", label: "Workspace" },
    { id: "general", label: "General" },
  ];

  const handleReset = async () => {
    if (!confirm("This will delete all your workspace data. Are you sure?")) return;
    setResetting(true);
    try {
      await tauri.resetWorkspace();
    } catch {
      // Ignore
    } finally {
      setResetting(false);
      disk.refresh();
    }
  };

  const handlePrune = async () => {
    setPruning(true);
    try {
      await tauri.pruneImages();
    } catch {
      // Ignore
    } finally {
      setPruning(false);
      disk.refresh();
    }
  };

  const copyUrl = async () => {
    await navigator.clipboard.writeText(STRINGS.MCP_URL);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="min-h-screen bg-surface-0 flex flex-col">
      <header className="flex items-center gap-3 px-6 py-4 border-b border-surface-300/50">
        <button onClick={() => navigate("/dashboard")} className="p-2 rounded-lg hover:bg-surface-200 transition-colors text-text-muted hover:text-text-secondary">
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" /></svg>
        </button>
        <span className="font-semibold text-lg">Settings</span>
      </header>

      <div className="flex-1 overflow-y-auto p-6">
        <div className="max-w-lg mx-auto space-y-5">
          {/* Tabs */}
          <div className="flex gap-1 bg-surface-100 rounded-xl p-1">
            {tabs.map((t) => (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className={`flex-1 px-4 py-2.5 rounded-lg text-sm font-medium transition-all ${
                  tab === t.id
                    ? "bg-surface-300 text-text-primary shadow-sm"
                    : "text-text-muted hover:text-text-secondary"
                }`}
              >
                {t.label}
              </button>
            ))}
          </div>

          {/* AI Connection Tab */}
          {tab === "ai" && (
            <div className="space-y-4 animate-fade-in">
              <div className="glass-card p-6 space-y-5">
                <div className="flex items-center gap-3">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${claude.mcpConnected ? "bg-brand-600/10" : "bg-surface-300"}`}>
                    <svg className={`w-5 h-5 ${claude.mcpConnected ? "text-brand-400" : "text-text-muted"}`} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 0 0-2.455 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z" /></svg>
                  </div>
                  <div>
                    <h3 className="font-medium text-sm">AI Copilot</h3>
                    <StatusIndicator status={claude.mcpConnected ? "running" : "stopped"} label={claude.mcpConnected ? STRINGS.AI_CONNECTED : STRINGS.AI_DISCONNECTED} />
                  </div>
                </div>

                <div className="space-y-2 text-sm">
                  <div className="flex items-center justify-between py-2 border-b border-surface-300/50">
                    <span className="text-text-muted">Claude Desktop</span>
                    <span className={claude.status?.is_installed ? "text-success" : "text-text-faint"}>
                      {claude.status?.is_installed ? "Detected" : "Not found"}
                    </span>
                  </div>
                  <div className="flex items-center justify-between py-2">
                    <span className="text-text-muted">Configuration</span>
                    <span className={claude.status?.is_configured ? "text-success" : "text-text-faint"}>
                      {claude.status?.is_configured ? "Connected" : "Not configured"}
                    </span>
                  </div>
                </div>

                <div className="flex gap-2">
                  <button onClick={claude.configureClaude} disabled={claude.configuring} className="btn-primary text-sm px-4 py-2.5">
                    {claude.configuring ? "Connecting..." : "Reconnect to Claude"}
                  </button>
                  <button onClick={copyUrl} className="btn-secondary text-sm px-4 py-2.5">
                    {copied ? "Copied!" : "Copy MCP URL"}
                  </button>
                </div>
              </div>

              <div className="glass-card p-5">
                <div className="flex items-center gap-2 text-text-muted text-xs">
                  <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" /></svg>
                  <span>MCP endpoint: <code className="text-brand-400 font-mono">{STRINGS.MCP_URL}</code></span>
                </div>
              </div>
            </div>
          )}

          {/* Workspace Tab */}
          {tab === "workspace" && (
            <div className="space-y-4 animate-fade-in">
              {disk.status && (
                <div className="glass-card p-6">
                  <DiskUsage status={disk.status} />
                </div>
              )}

              <div className="glass-card p-6 space-y-5">
                <div>
                  <h3 className="font-medium text-sm text-text-secondary">Configuration</h3>
                  <p className="text-xs text-text-faint mt-1">Changes apply the next time you reset your workspace.</p>
                </div>

                <div className="space-y-2">
                  <label className="text-sm text-text-muted">Memory</label>
                  <div className="flex gap-2">
                    {[
                      { label: "2 GB", value: 2048 },
                      { label: "4 GB", value: 4096 },
                      { label: "8 GB", value: 8192 },
                    ].map((opt) => (
                      <button
                        key={opt.value}
                        onClick={() => appSettings.setContainerMemory(opt.value)}
                        className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                          appSettings.settings.containerMemoryMb === opt.value
                            ? "bg-accent text-white"
                            : "bg-surface-200 text-text-muted hover:bg-surface-300"
                        }`}
                      >
                        {opt.label}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-sm text-text-muted">Workspace Password</label>
                  <input
                    type="password"
                    value={appSettings.settings.vncPassword}
                    onChange={(e) => appSettings.setVncPassword(e.target.value)}
                    placeholder="Enter password"
                    className="w-full px-4 py-2 bg-surface-200 border border-surface-300 rounded-lg text-sm text-text-primary placeholder-text-faint focus:outline-none focus:border-accent"
                  />
                </div>
              </div>

              <div className="glass-card p-6 space-y-4">
                <h3 className="font-medium text-sm text-text-secondary">Maintenance</h3>
                <div className="space-y-3">
                  <button onClick={handlePrune} disabled={pruning} className="btn-secondary w-full justify-start text-sm">
                    <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" /></svg>
                    {pruning ? "Cleaning..." : "Clean Up Old Images"}
                  </button>
                  <button onClick={handleReset} disabled={resetting} className="btn-danger w-full justify-start text-sm">
                    <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182M2.985 19.644l3.181 3.183" /></svg>
                    {resetting ? "Resetting..." : "Reset Workspace"}
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* General Tab */}
          {tab === "general" && (
            <div className="space-y-4 animate-fade-in">
              <div className="glass-card p-6 space-y-1">
                <h3 className="font-medium text-sm text-text-secondary mb-2">Startup</h3>
                <ToggleSwitch
                  label="Launch on startup"
                  description="Open Coeadapt automatically when you log in"
                  checked={appSettings.settings.autoStartApp}
                  onChange={appSettings.setAutoStartApp}
                  disabled={appSettings.loading}
                />
                <ToggleSwitch
                  label="Auto-start workspace"
                  description="Start your workspace automatically when the app opens"
                  checked={appSettings.settings.autoStartWorkspace}
                  onChange={appSettings.setAutoStartWorkspace}
                  disabled={appSettings.loading}
                />
                <ToggleSwitch
                  label="Auto-update workspace"
                  description="Download workspace updates automatically when available"
                  checked={appSettings.settings.autoUpdateImage}
                  onChange={appSettings.setAutoUpdateImage}
                  disabled={appSettings.loading}
                />
              </div>

              <div className="glass-card p-6 space-y-4">
                <h3 className="font-medium text-sm text-text-secondary">Application</h3>
                <div className="space-y-1 text-sm">
                  <div className="flex items-center justify-between py-2.5">
                    <span className="text-text-muted">Version</span>
                    <span className="text-text-secondary font-mono text-xs">0.1.0</span>
                  </div>
                </div>
              </div>

              <div className="glass-card p-6 space-y-3">
                <h3 className="font-medium text-sm text-text-secondary">About</h3>
                <div className="flex items-center gap-3">
                  <img src="/logo-color.png" alt="" className="w-8 h-8" />
                  <div>
                    <p className="text-sm font-medium">{STRINGS.APP_NAME}</p>
                    <p className="text-xs text-text-faint">Adapting Together</p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
