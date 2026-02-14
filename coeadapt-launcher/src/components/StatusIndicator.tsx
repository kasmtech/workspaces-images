interface Props {
  status: "running" | "starting" | "stopped" | "error";
  label: string;
}

const colors = {
  running: "bg-emerald-500",
  starting: "bg-amber-400 animate-pulse",
  stopped: "bg-gray-400",
  error: "bg-red-500",
};

export function StatusIndicator({ status, label }: Props) {
  return (
    <div className="flex items-center gap-2">
      <span className={`inline-block w-3 h-3 rounded-full ${colors[status]}`} />
      <span className="text-sm font-medium text-gray-200">{label}</span>
    </div>
  );
}
