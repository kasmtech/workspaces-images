import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { DiskWarningBanner } from "./components/DiskWarningBanner";
import Setup from "./pages/Setup";
import Dashboard from "./pages/Dashboard";
import ClaudeSetup from "./pages/ClaudeSetup";
import Settings from "./pages/Settings";

function App() {
  return (
    <BrowserRouter>
      <DiskWarningBanner />
      <Routes>
        <Route path="/setup" element={<Setup />} />
        <Route path="/claude-setup" element={<ClaudeSetup />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="*" element={<Navigate to="/setup" />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
