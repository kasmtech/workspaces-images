import type { ProgressSummary, AgentHealthInfo } from "../lib/types";
import { ProgressBar } from "./ProgressBar";
import { StatusIndicator } from "./StatusIndicator";

interface ProgressCardProps {
  summary: ProgressSummary | null;
  agentHealth: AgentHealthInfo | null;
  loading: boolean;
}

export function ProgressCard({ summary, agentHealth, loading }: ProgressCardProps) {
  if (loading && !summary) {
    return (
      <div className="glass-card p-6 animate-fade-in delay-150">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-surface-300 flex items-center justify-center">
            <svg className="w-5 h-5 text-text-muted animate-pulse" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z" />
            </svg>
          </div>
          <div>
            <h3 className="font-medium text-sm">Career Progress</h3>
            <p className="text-xs text-text-muted">Loading...</p>
          </div>
        </div>
      </div>
    );
  }

  if (!summary) {
    return null;
  }

  const hasActivity = summary.total_activities > 0 || summary.total_goals > 0;

  return (
    <div className="glass-card p-6 space-y-4 animate-fade-in delay-150">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-brand-600/10 flex items-center justify-center">
          <svg className="w-5 h-5 text-brand-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z" />
          </svg>
        </div>
        <div className="flex-1">
          <h3 className="font-medium text-sm">Career Progress</h3>
          {hasActivity ? (
            <p className="text-xs text-text-muted">
              {summary.progress_percent}% complete
            </p>
          ) : (
            <p className="text-xs text-text-muted">Get started with your first activity</p>
          )}
        </div>
        {summary.streak_days > 0 && (
          <div className="text-right">
            <span className="text-lg font-bold text-brand-400">{summary.streak_days}</span>
            <p className="text-[10px] text-text-faint leading-tight">day streak</p>
          </div>
        )}
      </div>

      {/* Progress bar */}
      {hasActivity && (
        <ProgressBar percent={summary.progress_percent} />
      )}

      {/* Stats grid */}
      <div className="grid grid-cols-4 gap-3">
        <StatBox label="Activities" value={summary.total_activities} />
        <StatBox label="Goals" value={`${summary.completed_goals}/${summary.total_goals}`} />
        <StatBox label="Skills" value={summary.total_skills} />
        <StatBox label="Milestones" value={summary.total_milestones} />
      </div>

      {/* Agent services status (compact) */}
      {agentHealth && (
        <div className="flex items-center gap-4 pt-2 border-t border-surface-300/50">
          <StatusIndicator
            status={agentHealth.progress_tracker === "ok" ? "running" : "stopped"}
            label={agentHealth.progress_tracker === "ok" ? "Tracking" : "Tracker offline"}
          />
          <StatusIndicator
            status={agentHealth.computer_use === "ok" ? "running" : "stopped"}
            label={agentHealth.computer_use === "ok" ? "Computer use" : "Computer use offline"}
          />
        </div>
      )}

      {/* Empty state */}
      {!hasActivity && (
        <p className="text-xs text-text-tertiary text-center py-2">
          Use the AI copilot to log activities, set goals, and track your career development.
        </p>
      )}
    </div>
  );
}

function StatBox({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="text-center">
      <div className="text-base font-semibold text-text-primary">{value}</div>
      <div className="text-[10px] text-text-faint leading-tight">{label}</div>
    </div>
  );
}
