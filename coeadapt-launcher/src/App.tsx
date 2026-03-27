import { useEffect } from "react";
import { BrowserRouter, Routes, Route, Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "@clerk/clerk-react";
import { STANDALONE_MODE } from "./lib/mode";
import { DiskWarningBanner } from "./components/DiskWarningBanner";
import { AuthGuard } from "./components/AuthGuard";
import { safeListen } from "./lib/tauri";
import { setAuthProvider } from "./lib/api";
import { useDeviceToken } from "./hooks/useDeviceToken";
import Login from "./pages/Login";
import Setup from "./pages/Setup";
import Dashboard from "./pages/Dashboard";
import ClaudeSetup from "./pages/ClaudeSetup";
import Settings from "./pages/Settings";
import Chat from "./pages/Chat";

/** Listens for "navigate" events from the Rust tray menu and routes accordingly. */
function TrayNavigationListener() {
  const navigate = useNavigate();
  useEffect(() => {
    const unlisten = safeListen<string>("navigate", (event) => {
      navigate(event.payload);
    });
    return () => { unlisten.then((fn) => fn()); };
  }, [navigate]);
  return null;
}

/** Wires Clerk auth into the API client and auto-generates device token. */
function AuthWiring() {
  const { getToken, isSignedIn } = useAuth();
  useDeviceToken(); // Auto-generates and stores device token after sign-in

  useEffect(() => {
    if (isSignedIn) {
      setAuthProvider(getToken);
    }
  }, [isSignedIn, getToken]);

  return null;
}

function App() {
  return (
    <BrowserRouter>
      <TrayNavigationListener />
      {!STANDALONE_MODE && <AuthWiring />}
      <div className="min-h-screen bg-surface-0 text-text-primary">
        <DiskWarningBanner />
        <Routes>
          {!STANDALONE_MODE && <Route path="/login" element={<Login />} />}
          <Route path="/setup" element={<AuthGuard><Setup /></AuthGuard>} />
          <Route path="/claude-setup" element={<AuthGuard><ClaudeSetup /></AuthGuard>} />
          <Route path="/dashboard" element={<AuthGuard><Dashboard /></AuthGuard>} />
          <Route path="/settings" element={<AuthGuard><Settings /></AuthGuard>} />
          {!STANDALONE_MODE && <Route path="/chat" element={<AuthGuard><Chat /></AuthGuard>} />}
          <Route path="*" element={<Navigate to={STANDALONE_MODE ? "/setup" : "/login"} />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}

export default App;
