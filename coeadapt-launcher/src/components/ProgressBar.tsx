interface Props {
  percent: number;
  label?: string;
  indeterminate?: boolean;
}

export function ProgressBar({ percent, label, indeterminate }: Props) {
  return (
    <div className="w-full space-y-2">
      {label && (
        <div className="flex justify-between">
          <span className="text-sm text-text-secondary">{label}</span>
          {!indeterminate && (
            <span className="text-sm text-text-muted tabular-nums">
              {Math.round(percent)}%
            </span>
          )}
        </div>
      )}
      <div className="w-full bg-surface-300 rounded-full h-1.5 overflow-hidden">
        {indeterminate ? (
          <div className="h-full rounded-full w-1/3 brand-gradient animate-[shimmer_1.5s_ease-in-out_infinite]" />
        ) : (
          <div
            className="h-full rounded-full brand-gradient transition-all duration-500 ease-out"
            style={{ width: `${Math.min(100, Math.max(0, percent))}%` }}
          />
        )}
      </div>
    </div>
  );
}
