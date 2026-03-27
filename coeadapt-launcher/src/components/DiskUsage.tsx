import type { DiskStatus } from "../lib/types";

interface Props {
  status: DiskStatus;
}

export function DiskUsage({ status }: Props) {
  const usedGb = status.total_gb - status.available_gb;
  const usedPercent = (usedGb / status.total_gb) * 100;

  const barColor = status.is_low
    ? "bg-danger"
    : !status.meets_recommended
      ? "bg-warning"
      : "bg-success";

  return (
    <div className="space-y-3">
      <div className="flex justify-between items-baseline">
        <span className="text-sm font-medium text-text-secondary">Storage</span>
        <span className="text-xs text-text-muted tabular-nums">
          {status.available_gb} GB free of {status.total_gb} GB
        </span>
      </div>
      <div className="w-full bg-surface-300 rounded-full h-1.5">
        <div
          className={`h-1.5 rounded-full transition-all duration-500 ${barColor}`}
          style={{ width: `${usedPercent}%` }}
        />
      </div>
    </div>
  );
}
