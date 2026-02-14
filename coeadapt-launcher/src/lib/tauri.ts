import { invoke } from "@tauri-apps/api/core";
import type {
  DockerInfo,
  DiskStatus,
  DockerDiskUsage,
  ContainerStatus,
  ClaudeStatus,
} from "./types";

export const tauri = {
  detectRuntime: () => invoke<DockerInfo>("detect_container_runtime"),
  checkWsl2: () => invoke<boolean>("check_wsl2_status"),
  checkDiskSpace: () => invoke<DiskStatus>("check_disk_space"),
  getDockerDiskUsage: () => invoke<DockerDiskUsage>("get_docker_disk_usage"),
  pruneImages: () => invoke<string>("prune_docker_images"),
  getWorkspaceStatus: () => invoke<ContainerStatus>("get_workspace_status"),
  checkImageExists: () => invoke<boolean>("check_image_exists"),
  pullWorkspaceImage: () => invoke<void>("pull_workspace_image"),
  createWorkspace: () => invoke<string>("create_workspace"),
  startWorkspace: () => invoke<void>("start_workspace"),
  stopWorkspace: () => invoke<void>("stop_workspace"),
  resetWorkspace: () => invoke<void>("reset_workspace"),
  waitForReady: () => invoke<void>("wait_for_workspace_ready"),
  checkMcpStatus: () => invoke<boolean>("check_mcp_status"),
  getClaudeStatus: () => invoke<ClaudeStatus>("get_claude_status"),
  configureClaude: () => invoke<void>("configure_claude"),
  openWorkspaceBrowser: () => invoke<void>("open_workspace_browser"),
};
