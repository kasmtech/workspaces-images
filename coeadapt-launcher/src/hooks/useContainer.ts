import { useState, useEffect, useCallback } from "react";
import { tauri, safeListen } from "../lib/tauri";
import type { ContainerStatus, PullProgress } from "../lib/types";

export function useContainer() {
  const [status, setStatus] = useState<ContainerStatus | null>(null);
  const [pullProgress, setPullProgress] = useState<PullProgress | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sslTrusted, setSslTrusted] = useState<boolean | null>(null);
  const [sslInstalling, setSslInstalling] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const s = await tauri.getWorkspaceStatus();
      setStatus(s);
      setError(null);
    } catch {
      // Not in Tauri or command failed
    }
  }, []);

  const checkSsl = useCallback(async () => {
    try {
      const trusted = await tauri.checkSslTrust();
      setSslTrusted(trusted);
      return trusted;
    } catch {
      setSslTrusted(null);
      return false;
    }
  }, []);

  useEffect(() => {
    refresh();

    const unlistenPull = safeListen<PullProgress>("docker-pull-progress", (event) => {
      setPullProgress(event.payload);
    });
    const unlistenReady = safeListen<boolean>("workspace-ready", () => {
      refresh();
      checkSsl();
    });

    const interval = setInterval(refresh, 10000);

    return () => {
      unlistenPull.then((fn) => fn());
      unlistenReady.then((fn) => fn());
      clearInterval(interval);
    };
  }, [refresh, checkSsl]);

  const pullImage = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      await tauri.pullWorkspaceImage();
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
      setPullProgress(null);
      refresh();
    }
  }, [refresh]);

  const createWorkspace = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      await tauri.createWorkspace();
      refresh();
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, [refresh]);

  const startWorkspace = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      await tauri.startWorkspace();
      refresh();
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, [refresh]);

  const stopWorkspace = useCallback(async () => {
    setLoading(true);
    try {
      await tauri.stopWorkspace();
      refresh();
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, [refresh]);

  const openWorkspace = useCallback(async () => {
    try {
      await tauri.openWorkspaceBrowser();
    } catch (e) {
      setError(String(e));
    }
  }, []);

  const installSslCertificate = useCallback(async () => {
    setSslInstalling(true);
    setError(null);
    try {
      await tauri.installSslCertificate();
      setSslTrusted(true);
    } catch (e) {
      setError(String(e));
    } finally {
      setSslInstalling(false);
    }
  }, []);

  const isRunning = status?.state === "Running";
  const isStopped = status?.state === "Stopped" || status?.state === "NotFound";

  // Check SSL trust when container becomes running
  useEffect(() => {
    if (isRunning) checkSsl();
  }, [isRunning, checkSsl]);

  return {
    status, pullProgress, loading, error, isRunning, isStopped,
    sslTrusted, sslInstalling,
    pullImage, createWorkspace, startWorkspace, stopWorkspace, openWorkspace, refresh,
    installSslCertificate,
  };
}
