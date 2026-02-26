import { useAuth } from "@clerk/clerk-react";
import { useState, useEffect, useCallback } from "react";
import { api, setDeviceToken } from "../lib/api";

export function useDeviceToken() {
  const { isSignedIn } = useAuth();
  const [deviceToken, setDeviceTokenState] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadOrGenerate = useCallback(async () => {
    if (!isSignedIn) return;
    setLoading(true);
    setError(null);

    try {
      // Try to load existing token from Tauri store
      const { Store } = await import("@tauri-apps/plugin-store");
      const store = await Store.load("auth.json");
      const existing = await store.get<string>("deviceToken");

      if (existing) {
        // Verify it's still valid
        setDeviceToken(existing);
        try {
          const result = await api.verifyToken();
          if (result.valid) {
            setDeviceTokenState(existing);
            setLoading(false);
            return;
          }
        } catch {
          // Token invalid, fall through to generate new one
        }
      }

      // Generate new device token
      const hostname = `Career-Box-${Date.now().toString(36)}`;
      const result = await api.generateDeviceToken(hostname);
      await store.set("deviceToken", result.token);
      await store.save();
      setDeviceToken(result.token);
      setDeviceTokenState(result.token);
    } catch (err: any) {
      console.error("Failed to setup device token:", err);
      setError(err.message || "Failed to connect to Coeadapt");
    } finally {
      setLoading(false);
    }
  }, [isSignedIn]);

  useEffect(() => {
    loadOrGenerate();
  }, [loadOrGenerate]);

  const regenerate = useCallback(async () => {
    // Clear existing token and generate fresh
    try {
      const { Store } = await import("@tauri-apps/plugin-store");
      const store = await Store.load("auth.json");
      await store.delete("deviceToken");
      await store.save();
    } catch {
      // Ignore store errors
    }
    setDeviceTokenState(null);
    setDeviceToken(null);
    await loadOrGenerate();
  }, [loadOrGenerate]);

  return { deviceToken, loading, error, regenerate };
}
