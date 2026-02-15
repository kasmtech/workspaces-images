import { useAuth } from "@clerk/clerk-react";
import { Navigate } from "react-router-dom";
import { STANDALONE_MODE } from "../lib/mode";
import { Spinner } from "./Spinner";

/**
 * In CoeAdapt mode, delegates to ClerkAuthGuard which uses the useAuth hook.
 * In standalone mode, renders children immediately with no auth check.
 */
export function AuthGuard({ children }: { children: React.ReactNode }) {
  if (STANDALONE_MODE) return <>{children}</>;
  return <ClerkAuthGuard>{children}</ClerkAuthGuard>;
}

/** Separated component so useAuth hook is always called (Rules of Hooks). */
function ClerkAuthGuard({ children }: { children: React.ReactNode }) {
  const { isSignedIn, isLoaded } = useAuth();

  if (!isLoaded) {
    return (
      <div className="min-h-screen bg-surface-0 flex items-center justify-center">
        <Spinner />
      </div>
    );
  }

  if (!isSignedIn) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}
