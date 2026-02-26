import { useDiskSpace } from "../hooks/useDiskSpace";

export function DiskWarningBanner() {
  const { status, showWarning, dismissWarning } = useDiskSpace();

  if (!showWarning || !status) return null;

  return (
    <div className="bg-warning/10 border-b border-warning/20 px-4 py-2.5 flex items-center justify-between animate-fade-in">
      <div className="flex items-center gap-2">
        <svg className="w-4 h-4 text-warning shrink-0" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
        </svg>
        <span className="text-warning text-sm">
          Low disk space ({status.available_gb} GB remaining)
        </span>
      </div>
      <button
        onClick={dismissWarning}
        className="text-text-muted hover:text-text-secondary transition-colors p-1"
      >
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  );
}
