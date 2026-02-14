import { useAuth } from "@clerk/clerk-react";
import { Navigate } from "react-router-dom";
import { STANDALONE_MODE } from "../lib/mode";
import { Spinner } from "./Spinner";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  if (STANDALONE_MODE) return <>{children}</>;

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
