import type {
  DockerInfo,
  DiskStatus,
  DockerDiskUsage,
  ContainerStatus,
  ClaudeStatus,
  McpHealthInfo,
} from "./types";

function isTauri(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

async function safeInvoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  if (!isTauri()) {
    throw new Error(`Not in Tauri context (tried to invoke "${cmd}")`);
  }
  const { invoke } = await import("@tauri-apps/api/core");
  return invoke<T>(cmd, args);
}

export async function safeListen<T>(
  event: string,
  handler: (event: { payload: T }) => void,
): Promise<() => void> {
  if (!isTauri()) return () => {};
  const { listen } = await import("@tauri-apps/api/event");
  return listen<T>(event, handler);
}

export const tauri = {
  isTauri,
  detectRuntime: () => safeInvoke<DockerInfo>("detect_container_runtime"),
  checkWsl2: () => safeInvoke<boolean>("check_wsl2_status"),
  checkDiskSpace: () => safeInvoke<DiskStatus>("check_disk_space"),
  getDockerDiskUsage: () => safeInvoke<DockerDiskUsage>("get_docker_disk_usage"),
  pruneImages: () => safeInvoke<string>("prune_docker_images"),
  getWorkspaceStatus: () => safeInvoke<ContainerStatus>("get_workspace_status"),
  checkImageExists: () => safeInvoke<boolean>("check_image_exists"),
  pullWorkspaceImage: () => safeInvoke<void>("pull_workspace_image"),
  createWorkspace: () => safeInvoke<string>("create_workspace"),
  startWorkspace: () => safeInvoke<void>("start_workspace"),
  stopWorkspace: () => safeInvoke<void>("stop_workspace"),
  resetWorkspace: () => safeInvoke<void>("reset_workspace"),
  waitForReady: () => safeInvoke<void>("wait_for_workspace_ready"),
  checkMcpStatus: () => safeInvoke<boolean>("check_mcp_status"),
  getMcpHealth: () => safeInvoke<McpHealthInfo>("get_mcp_health"),
  getClaudeStatus: () => safeInvoke<ClaudeStatus>("get_claude_status"),
  configureClaude: () => safeInvoke<void>("configure_claude"),
  openWorkspaceBrowser: () => safeInvoke<void>("open_workspace_browser"),
  startMcp: () => safeInvoke<void>("start_mcp"),
  stopMcp: () => safeInvoke<void>("stop_mcp"),
};
