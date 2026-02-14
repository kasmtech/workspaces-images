import { useEffect } from "react";
import { BrowserRouter, Routes, Route, Navigate, useNavigate } from "react-router-dom";
import { DiskWarningBanner } from "./components/DiskWarningBanner";
import { safeListen } from "./lib/tauri";
import Setup from "./pages/Setup";
import Dashboard from "./pages/Dashboard";
import ClaudeSetup from "./pages/ClaudeSetup";
import Settings from "./pages/Settings";

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

function App() {
  return (
    <BrowserRouter>
      <TrayNavigationListener />
      <div className="min-h-screen bg-surface-0 text-text-primary">
        <DiskWarningBanner />
        <Routes>
          <Route path="/setup" element={<Setup />} />
          <Route path="/claude-setup" element={<ClaudeSetup />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="*" element={<Navigate to="/setup" />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}

export default App;
