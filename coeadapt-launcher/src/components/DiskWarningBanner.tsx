import { useDiskSpace } from "../hooks/useDiskSpace";

export function DiskWarningBanner() {
  const { status, showWarning, dismissWarning } = useDiskSpace();

  if (!showWarning || !status) return null;

  return (
    <div className="bg-amber-900/80 border-b border-amber-700 px-4 py-2 flex items-center justify-between">
      <span className="text-amber-200 text-sm">
        You're running low on disk space ({status.available_gb}GB remaining). This
        may affect your workspace.
      </span>
      <button
        onClick={dismissWarning}
        className="text-amber-300 hover:text-amber-100 text-sm ml-4"
      >
        Dismiss
      </button>
    </div>
  );
}
