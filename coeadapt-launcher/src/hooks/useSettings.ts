import { useState, useEffect, useCallback } from "react";

interface Settings {
  autoStartApp: boolean;
  autoStartWorkspace: boolean;
  autoUpdateImage: boolean;
  containerMemoryMb: number;
  vncPassword: string;
}

const DEFAULTS: Settings = {
  autoStartApp: false,
  autoStartWorkspace: false,
  autoUpdateImage: false,
  containerMemoryMb: 2048,
  vncPassword: "coeadapt",
};

let storeInstance: Awaited<ReturnType<typeof import("@tauri-apps/plugin-store").Store.load>> | null = null;

async function getStore() {
  if (!storeInstance) {
    const { Store } = await import("@tauri-apps/plugin-store");
    storeInstance = await Store.load("settings.json", {
      defaults: {
        autoStartWorkspace: false,
        autoUpdateImage: false,
        containerMemoryMb: 2048,
        vncPassword: "coeadapt",
      },
      autoSave: true,
    });
  }
  return storeInstance;
}

export function useSettings() {
  const [settings, setSettings] = useState<Settings>(DEFAULTS);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    try {
      // Autostart plugin
      const { isEnabled } = await import("@tauri-apps/plugin-autostart");
      const autoStartApp = await isEnabled();

      // Store-backed settings
      const store = await getStore();
      const autoStartWorkspace = (await store.get<boolean>("autoStartWorkspace")) ?? DEFAULTS.autoStartWorkspace;
      const autoUpdateImage = (await store.get<boolean>("autoUpdateImage")) ?? DEFAULTS.autoUpdateImage;
      const containerMemoryMb = (await store.get<number>("containerMemoryMb")) ?? DEFAULTS.containerMemoryMb;
      const vncPassword = (await store.get<string>("vncPassword")) ?? DEFAULTS.vncPassword;

      setSettings({ autoStartApp, autoStartWorkspace, autoUpdateImage, containerMemoryMb, vncPassword });
    } catch {
      // Not in Tauri context
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const setAutoStartApp = useCallback(async (value: boolean) => {
    try {
      const autostart = await import("@tauri-apps/plugin-autostart");
      if (value) {
        await autostart.enable();
      } else {
        await autostart.disable();
      }
      setSettings((prev) => ({ ...prev, autoStartApp: value }));
    } catch { /* ignore */ }
  }, []);

  const setAutoStartWorkspace = useCallback(async (value: boolean) => {
    const store = await getStore();
    await store.set("autoStartWorkspace", value);
    setSettings((prev) => ({ ...prev, autoStartWorkspace: value }));
  }, []);

  const setAutoUpdateImage = useCallback(async (value: boolean) => {
    const store = await getStore();
    await store.set("autoUpdateImage", value);
    setSettings((prev) => ({ ...prev, autoUpdateImage: value }));
  }, []);

  const setContainerMemory = useCallback(async (value: number) => {
    const store = await getStore();
    await store.set("containerMemoryMb", value);
    setSettings((prev) => ({ ...prev, containerMemoryMb: value }));
  }, []);

  const setVncPassword = useCallback(async (value: string) => {
    const store = await getStore();
    await store.set("vncPassword", value);
    setSettings((prev) => ({ ...prev, vncPassword: value }));
  }, []);

  return {
    settings,
    loading,
    refresh,
    setAutoStartApp,
    setAutoStartWorkspace,
    setAutoUpdateImage,
    setContainerMemory,
    setVncPassword,
  };
}
