interface Props {
  percent: number;
  label?: string;
  indeterminate?: boolean;
}

export function ProgressBar({ percent, label, indeterminate }: Props) {
  return (
    <div className="w-full">
      {label && (
        <div className="flex justify-between mb-1">
          <span className="text-sm text-gray-300">{label}</span>
          {!indeterminate && (
            <span className="text-sm text-gray-400">{Math.round(percent)}%</span>
          )}
        </div>
      )}
      <div className="w-full bg-gray-700 rounded-full h-2 overflow-hidden">
        {indeterminate ? (
          <div className="bg-coral-500 h-2 rounded-full w-1/3 animate-[shimmer_1.5s_ease-in-out_infinite]" />
        ) : (
          <div
            className="bg-coral-500 h-2 rounded-full transition-all duration-300"
            style={{ width: `${Math.min(100, Math.max(0, percent))}%` }}
          />
        )}
      </div>
    </div>
  );
}
