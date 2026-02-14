import { useState, useEffect, useCallback } from "react";
import { listen } from "@tauri-apps/api/event";
import { tauri } from "../lib/tauri";
import type { ContainerStatus, PullProgress } from "../lib/types";

export function useContainer() {
  const [status, setStatus] = useState<ContainerStatus | null>(null);
  const [pullProgress, setPullProgress] = useState<PullProgress | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const s = await tauri.getWorkspaceStatus();
      setStatus(s);
      setError(null);
    } catch (e) {
      setError(String(e));
    }
  }, []);

  useEffect(() => {
    refresh();

    const unlistenPull = listen<PullProgress>("docker-pull-progress", (event) => {
      setPullProgress(event.payload);
    });

    const unlistenReady = listen<boolean>("workspace-ready", () => {
      refresh();
    });

    const interval = setInterval(refresh, 10000);

    return () => {
      unlistenPull.then((fn) => fn());
      unlistenReady.then((fn) => fn());
      clearInterval(interval);
    };
  }, [refresh]);

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

  const isRunning = status?.state === "Running";
  const isStopped = status?.state === "Stopped" || status?.state === "NotFound";

  return {
    status,
    pullProgress,
    loading,
    error,
    isRunning,
    isStopped,
    pullImage,
    createWorkspace,
    startWorkspace,
    stopWorkspace,
    openWorkspace,
    refresh,
  };
}
