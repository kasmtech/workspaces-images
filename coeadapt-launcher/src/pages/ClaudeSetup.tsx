import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useClaudeConnection } from "../hooks/useClaudeConnection";
import { STRINGS } from "../lib/constants";

export default function ClaudeSetup() {
  const navigate = useNavigate();
  const claude = useClaudeConnection();
  const [copied, setCopied] = useState(false);

  const copyUrl = async () => {
    await navigator.clipboard.writeText(STRINGS.MCP_URL);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="min-h-screen bg-navy-900 flex items-center justify-center p-8">
      <div className="max-w-lg w-full space-y-8">
        <div className="text-center space-y-2">
          <h2 className="text-2xl font-bold text-white">Your workspace is running!</h2>
          <p className="text-gray-400">Last step: connect your AI copilot.</p>
        </div>

        {/* Auto-configure path */}
        {claude.status?.is_installed && (
          <div className="bg-navy-800 rounded-xl p-6 space-y-4">
            <p className="text-gray-300">
              We detected Claude Desktop on your system.
            </p>
            <button
              onClick={async () => {
                await claude.configureClaude();
                navigate("/dashboard");
              }}
              disabled={claude.configuring || claude.status?.is_configured}
              className="w-full px-6 py-3 bg-coral-500 hover:bg-coral-600 text-white font-semibold rounded-lg transition-colors disabled:opacity-50"
            >
              {claude.status?.is_configured
                ? "Already Connected"
                : claude.configuring
                  ? "Connecting..."
                  : "Connect to Claude"}
            </button>
          </div>
        )}

        {/* Manual path */}
        <div className="bg-navy-800 rounded-xl p-6 space-y-4">
          <p className="text-gray-300 text-sm">
            {claude.status?.is_installed ? "Or set up manually:" : "Connect your AI copilot:"}
          </p>
          <ol className="text-gray-400 text-sm space-y-2 list-decimal list-inside">
            <li>Open Claude (claude.ai, Claude Desktop, or Cowork)</li>
            <li>Go to Settings &rarr; Connectors</li>
            <li>Click "Add custom connector"</li>
            <li>Paste this URL:</li>
          </ol>
          <div className="flex items-center gap-2">
            <code className="flex-1 bg-gray-800 text-coral-400 px-4 py-2 rounded font-mono text-sm">
              {STRINGS.MCP_URL}
            </code>
            <button
              onClick={copyUrl}
              className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded text-sm"
            >
              {copied ? "Copied!" : "Copy"}
            </button>
          </div>
        </div>

        <button
          onClick={() => navigate("/dashboard")}
          className="w-full px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
        >
          Continue to Dashboard
        </button>
      </div>
    </div>
  );
}
