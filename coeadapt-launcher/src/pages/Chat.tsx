import { useState, useRef, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useCoraChat } from "../hooks/useCoraChat";


export default function Chat() {
  const navigate = useNavigate();
  const { messages, isStreaming, error, sendMessage, stopStreaming } = useCoraChat();
  const [input, setInput] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const text = input.trim();
    if (!text || isStreaming) return;
    setInput("");
    sendMessage(text);
  };

  return (
    <div className="min-h-screen bg-surface-0 flex flex-col">
      {/* Header */}
      <header className="flex items-center gap-3 px-6 py-4 border-b border-surface-300/50">
        <button
          onClick={() => navigate("/dashboard")}
          className="p-2 rounded-lg hover:bg-surface-200 transition-colors text-text-muted hover:text-text-secondary"
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
          </svg>
        </button>
        <div className="w-8 h-8 rounded-lg bg-brand-600/10 flex items-center justify-center">
          <svg className="w-4 h-4 text-brand-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09Z" />
          </svg>
        </div>
        <div>
          <h1 className="font-semibold text-sm">Cora</h1>
          <p className="text-xs text-text-muted">AI Career Companion</p>
        </div>
      </header>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-6 space-y-4">
        {messages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-center animate-fade-in">
            <div className="w-16 h-16 rounded-2xl bg-brand-600/10 flex items-center justify-center mb-4">
              <svg className="w-8 h-8 text-brand-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09Z" />
              </svg>
            </div>
            <h2 className="text-lg font-medium text-text-primary mb-2">Hi, I'm Cora</h2>
            <p className="text-sm text-text-muted max-w-xs">
              Your AI career companion. Ask me about career paths, skill development, job strategies, or anything career-related.
            </p>
          </div>
        )}

        {messages.map((msg) => (
          <div key={msg.id} className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}>
            <div
              className={`max-w-[80%] rounded-2xl px-4 py-3 text-sm leading-relaxed ${
                msg.role === "user"
                  ? "bg-brand-600 text-white"
                  : "glass-card text-text-primary"
              }`}
            >
              {msg.content || (isStreaming && msg.role === "assistant" ? (
                <span className="inline-flex items-center gap-1 text-text-muted">
                  <span className="animate-breathe">Thinking</span>
                  <span className="animate-pulse">...</span>
                </span>
              ) : null)}
            </div>
          </div>
        ))}

        {error && (
          <div className="text-center">
            <p className="text-danger text-sm">{error}</p>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="p-4 border-t border-surface-300/50">
        <form onSubmit={handleSubmit} className="flex gap-3 max-w-lg mx-auto">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Ask Cora anything..."
            className="flex-1 bg-surface-200 border border-surface-300 rounded-xl px-4 py-3 text-sm text-text-primary placeholder:text-text-faint focus:outline-none focus:border-brand-500 transition-colors"
            disabled={isStreaming}
          />
          {isStreaming ? (
            <button
              type="button"
              onClick={stopStreaming}
              className="px-4 py-3 bg-surface-300 hover:bg-surface-400 rounded-xl transition-colors"
            >
              <svg className="w-5 h-5 text-text-secondary" fill="currentColor" viewBox="0 0 24 24">
                <rect x="6" y="6" width="12" height="12" rx="2" />
              </svg>
            </button>
          ) : (
            <button
              type="submit"
              disabled={!input.trim()}
              className="px-4 py-3 brand-gradient rounded-xl transition-all hover:shadow-lg hover:shadow-brand-600/20 disabled:opacity-40 disabled:shadow-none"
            >
              <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 12 3.269 3.125A59.769 59.769 0 0 1 21.485 12 59.768 59.768 0 0 1 3.27 20.875L5.999 12Zm0 0h7.5" />
              </svg>
            </button>
          )}
        </form>
      </div>
    </div>
  );
}
