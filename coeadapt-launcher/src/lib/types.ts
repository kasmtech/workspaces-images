export interface DockerInfo {
  runtime: "Docker" | "Podman" | "None";
  version: string;
  is_daemon_running: boolean;
}

export interface DiskStatus {
  available_gb: number;
  total_gb: number;
  meets_minimum: boolean;
  meets_recommended: boolean;
  is_low: boolean;
}

export interface DockerDiskUsage {
  images_size: string;
  containers_size: string;
  volumes_size: string;
  total_size: string;
}

export type ContainerState =
  | "NotFound"
  | "Running"
  | "Stopped"
  | "Starting"
  | "Pulling"
  | { Error: string };

export interface ContainerStatus {
  state: ContainerState;
  container_id: string | null;
  uptime: string | null;
  image: string;
}

export interface ClaudeStatus {
  is_installed: boolean;
  config_path: string | null;
  is_configured: boolean;
  needs_restart: boolean;
}

export interface PullProgress {
  status: string;
  progress: string | null;
  percent: number;
}

export interface McpHealthInfo {
  is_running: boolean;
  last_tool_call: number | null;
  uptime_secs: number | null;
}
