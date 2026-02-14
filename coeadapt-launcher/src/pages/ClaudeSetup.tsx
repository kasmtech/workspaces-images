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
    <div className="min-h-screen bg-surface-0 flex flex-col">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-96 h-96 rounded-full bg-brand-600/5 blur-3xl" />
      </div>

      <div className="relative z-10 flex-1 flex items-center justify-center p-8">
        <div className="max-w-md w-full space-y-6 animate-fade-in">
          <div className="text-center space-y-3">
            <div className="w-14 h-14 mx-auto rounded-2xl bg-brand-600/10 flex items-center justify-center mb-4">
              <svg className="w-7 h-7 text-brand-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 0 0-2.455 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z" />
              </svg>
            </div>
            <h2 className="text-2xl font-semibold">Connect your AI copilot</h2>
            <p className="text-text-muted text-sm">Your workspace is running. Let's connect your AI assistant.</p>
          </div>

          {claude.status?.is_installed && (
            <div className="glass-card p-6 space-y-4 animate-fade-in delay-100">
              <div className="flex items-center gap-2">
                <svg className="w-4 h-4 text-success" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" /></svg>
                <span className="text-sm text-text-secondary">Claude Desktop detected</span>
              </div>
              <button
                onClick={async () => { await claude.configureClaude(); navigate("/dashboard"); }}
                disabled={claude.configuring || claude.status?.is_configured}
                className="btn-primary w-full"
              >
                {claude.status?.is_configured ? "Already Connected" : claude.configuring ? "Connecting..." : "Connect Automatically"}
              </button>
            </div>
          )}

          <div className="glass-card p-6 space-y-4 animate-fade-in delay-200">
            <p className="text-sm text-text-secondary font-medium">
              {claude.status?.is_installed ? "Or connect manually:" : "Manual setup:"}
            </p>
            <ol className="text-text-muted text-sm space-y-2 list-decimal list-inside">
              <li>Open Claude, ChatGPT, or your preferred AI</li>
              <li>Go to Settings &rarr; Connectors</li>
              <li>Add a custom MCP connector</li>
              <li>Paste this URL:</li>
            </ol>
            <div className="flex items-center gap-2">
              <code className="flex-1 bg-surface-300 text-brand-400 px-4 py-2.5 rounded-lg font-mono text-sm truncate">
                {STRINGS.MCP_URL}
              </code>
              <button onClick={copyUrl} className="btn-secondary shrink-0 text-xs px-3 py-2.5">
                {copied ? (
                  <svg className="w-4 h-4 text-success" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" /></svg>
                ) : (
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 0 1-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 0 1 1.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 0 0-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 0 1-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 0 0-3.375-3.375h-1.5a1.125 1.125 0 0 1-1.125-1.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H9.75" /></svg>
                )}
                {copied ? "Copied" : "Copy"}
              </button>
            </div>
          </div>

          <button onClick={() => navigate("/dashboard")} className="btn-secondary w-full animate-fade-in delay-300">
            Continue to Dashboard
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3" /></svg>
          </button>
        </div>
      </div>
    </div>
  );
}
