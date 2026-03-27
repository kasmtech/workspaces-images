import { useState, useEffect, useCallback } from "react";
import { tauri } from "../lib/tauri";
import type { DockerInfo } from "../lib/types";

export function useDocker() {
  const [info, setInfo] = useState<DockerInfo | null>(null);
  const [loading, setLoading] = useState(true);

  const check = useCallback(async () => {
    setLoading(true);
    try {
      const result = await tauri.detectRuntime();
      setInfo(result);
    } catch {
      setInfo(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    check();
  }, [check]);

  const isAvailable = info?.runtime !== "None" && info?.is_daemon_running;

  return { info, loading, isAvailable, refresh: check };
}
