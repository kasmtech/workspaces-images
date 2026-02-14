import { useState, useEffect, useCallback } from "react";
import { listen } from "@tauri-apps/api/event";
import { tauri } from "../lib/tauri";
import type { DiskStatus } from "../lib/types";

export function useDiskSpace() {
  const [status, setStatus] = useState<DiskStatus | null>(null);
  const [showWarning, setShowWarning] = useState(false);

  const check = useCallback(async () => {
    try {
      const result = await tauri.checkDiskSpace();
      setStatus(result);
      setShowWarning(result.is_low);
    } catch {
      // Ignore disk check failures
    }
  }, []);

  useEffect(() => {
    check();

    const unlisten = listen<DiskStatus>("disk-warning", (event) => {
      setStatus(event.payload);
      setShowWarning(true);
    });

    return () => {
      unlisten.then((fn) => fn());
    };
  }, [check]);

  const dismissWarning = useCallback(() => {
    setShowWarning(false);
  }, []);

  return { status, showWarning, dismissWarning, refresh: check };
}
