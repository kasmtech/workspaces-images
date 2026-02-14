import { useState } from "react";
import { useDiskSpace } from "../hooks/useDiskSpace";
import { useClaudeConnection } from "../hooks/useClaudeConnection";
import { DiskUsage } from "../components/DiskUsage";
import { StatusIndicator } from "../components/StatusIndicator";
import { STRINGS } from "../lib/constants";
import { tauri } from "../lib/tauri";

type Tab = "account" | "ai" | "workspace" | "general";

export default function Settings() {
  const [tab, setTab] = useState<Tab>("workspace");
  const disk = useDiskSpace();
  const claude = useClaudeConnection();
  const [resetting, setResetting] = useState(false);
  const [pruning, setPruning] = useState(false);
  const [copied, setCopied] = useState(false);

  const tabs: { id: Tab; label: string }[] = [
    { id: "account", label: "Account" },
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
    <div className="min-h-screen bg-navy-900 p-8">
      <div className="max-w-2xl mx-auto space-y-6">
        <h1 className="text-2xl font-bold text-white">Settings</h1>

        {/* Tabs */}
        <div className="flex gap-1 bg-navy-800 rounded-lg p-1">
          {tabs.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                tab === t.id
                  ? "bg-navy-700 text-white"
                  : "text-gray-400 hover:text-gray-200"
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Account Tab */}
        {tab === "account" && (
          <div className="bg-navy-800 rounded-xl p-6 space-y-4">
            <p className="text-gray-300">Logged in as demo@coeadapt.com</p>
            <p className="text-gray-500 text-sm">
              Subscription: Active (Clerk auth coming soon)
            </p>
          </div>
        )}

        {/* AI Connection Tab */}
        {tab === "ai" && (
          <div className="bg-navy-800 rounded-xl p-6 space-y-4">
            <StatusIndicator
              status={claude.mcpConnected ? "running" : "stopped"}
              label={claude.mcpConnected ? STRINGS.AI_CONNECTED : STRINGS.AI_DISCONNECTED}
            />
            <div className="space-y-2">
              <p className="text-sm text-gray-400">
                Claude Desktop: {claude.status?.is_installed ? "Detected" : "Not found"}
              </p>
              <p className="text-sm text-gray-400">
                Config: {claude.status?.is_configured ? "Connected" : "Not configured"}
              </p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={claude.configureClaude}
                disabled={claude.configuring}
                className="px-4 py-2 bg-coral-500 hover:bg-coral-600 text-white rounded-lg text-sm disabled:opacity-50"
              >
                {claude.configuring ? "Connecting..." : "Reconnect to Claude"}
              </button>
              <button
                onClick={copyUrl}
                className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg text-sm"
              >
                {copied ? "Copied!" : "Copy MCP URL"}
              </button>
            </div>
          </div>
        )}

        {/* Workspace Tab */}
        {tab === "workspace" && (
          <div className="bg-navy-800 rounded-xl p-6 space-y-6">
            {disk.status && <DiskUsage status={disk.status} />}
            <div className="flex gap-3">
              <button
                onClick={handlePrune}
                disabled={pruning}
                className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg text-sm disabled:opacity-50"
              >
                {pruning ? "Cleaning..." : "Clean Up Old Images"}
              </button>
              <button
                onClick={handleReset}
                disabled={resetting}
                className="px-4 py-2 bg-red-700 hover:bg-red-600 text-white rounded-lg text-sm disabled:opacity-50"
              >
                {resetting ? "Resetting..." : "Reset Workspace"}
              </button>
            </div>
          </div>
        )}

        {/* General Tab */}
        {tab === "general" && (
          <div className="bg-navy-800 rounded-xl p-6 space-y-4">
            <p className="text-gray-400 text-sm">
              General settings (auto-start, auto-update) coming soon.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
