export function Spinner({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  const dims = { sm: "w-5 h-5", md: "w-8 h-8", lg: "w-12 h-12" };
  return (
    <div className="flex items-center justify-center">
      <svg className={`${dims[size]} animate-spin`} viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="10" stroke="rgba(255,255,255,0.1)" strokeWidth="3" />
        <path
          d="M12 2a10 10 0 0 1 10 10"
          stroke="url(#spinner-grad)"
          strokeWidth="3"
          strokeLinecap="round"
        />
        <defs>
          <linearGradient id="spinner-grad" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#4338ca" />
            <stop offset="100%" stopColor="#3b82f6" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}
