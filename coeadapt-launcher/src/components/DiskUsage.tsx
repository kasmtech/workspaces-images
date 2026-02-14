import type { DiskStatus } from "../lib/types";

interface Props {
  status: DiskStatus;
}

export function DiskUsage({ status }: Props) {
  const usedGb = status.total_gb - status.available_gb;
  const usedPercent = (usedGb / status.total_gb) * 100;

  return (
    <div className="space-y-2">
      <div className="flex justify-between text-sm">
        <span className="text-gray-300">Storage</span>
        <span className="text-gray-400">
          {status.available_gb}GB free of {status.total_gb}GB
        </span>
      </div>
      <div className="w-full bg-gray-700 rounded-full h-2">
        <div
          className={`h-2 rounded-full transition-all ${
            status.is_low
              ? "bg-red-500"
              : !status.meets_recommended
                ? "bg-amber-500"
                : "bg-emerald-500"
          }`}
          style={{ width: `${usedPercent}%` }}
        />
      </div>
    </div>
  );
}
