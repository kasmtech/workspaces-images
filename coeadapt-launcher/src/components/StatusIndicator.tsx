interface Props {
  status: "running" | "starting" | "stopped" | "error";
  label: string;
}

export function StatusIndicator({ status, label }: Props) {
  const dotColor = {
    running: "bg-success",
    starting: "bg-warning animate-pulse",
    stopped: "bg-surface-500",
    error: "bg-danger",
  };

  return (
    <div className="flex items-center gap-2.5">
      <span className="relative flex h-2.5 w-2.5">
        {status === "running" && (
          <span className="absolute inline-flex h-full w-full rounded-full bg-success/40 animate-ping" />
        )}
        <span className={`relative inline-flex rounded-full h-2.5 w-2.5 ${dotColor[status]}`} />
      </span>
      <span className="text-sm font-medium text-text-secondary">{label}</span>
    </div>
  );
}
