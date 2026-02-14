interface Props {
  isRunning: boolean;
  isStopped: boolean;
  loading: boolean;
  onStart: () => void;
  onStop: () => void;
  onOpen: () => void;
}

export function WorkspaceControls({
  isRunning,
  isStopped,
  loading,
  onStart,
  onStop,
  onOpen,
}: Props) {
  return (
    <div className="flex gap-3">
      {isRunning && (
        <>
          <button
            onClick={onOpen}
            className="px-6 py-3 bg-coral-500 hover:bg-coral-600 text-white font-semibold rounded-lg transition-colors text-lg"
          >
            Open Workspace
          </button>
          <button
            onClick={onStop}
            disabled={loading}
            className="px-4 py-3 bg-gray-600 hover:bg-gray-500 text-white rounded-lg transition-colors disabled:opacity-50"
          >
            Stop
          </button>
        </>
      )}
      {isStopped && (
        <button
          onClick={onStart}
          disabled={loading}
          className="px-6 py-3 bg-coral-500 hover:bg-coral-600 text-white font-semibold rounded-lg transition-colors text-lg disabled:opacity-50"
        >
          {loading ? "Starting..." : "Start Workspace"}
        </button>
      )}
    </div>
  );
}
