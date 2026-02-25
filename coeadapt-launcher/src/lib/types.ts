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

// ---------------------------------------------------------------------------
// Progress tracking types (mirrors the VM-side progress tracker data model)
// ---------------------------------------------------------------------------

export interface ProgressActivity {
  id: number;
  type: string;
  title: string;
  description: string;
  duration_minutes: number;
  tags: string[];
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface ProgressGoal {
  id: number;
  title: string;
  description: string;
  category: string;
  status: "active" | "completed" | "paused" | "abandoned";
  target_date: string | null;
  sub_goals: string[];
  completed_at?: string;
  created_at: string;
  updated_at: string;
}

export interface ProgressSkill {
  id: number;
  name: string;
  category: string;
  level: "beginner" | "intermediate" | "advanced" | "expert";
  evidence: string[];
  verified: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProgressMilestone {
  id: number;
  title: string;
  description: string;
  achieved: boolean;
  achieved_at: string | null;
  created_at: string;
}

export interface ProgressAssessment {
  id: number;
  type: string;
  skill: string;
  score: number;
  max_score: number;
  notes: string;
  created_at: string;
}

export interface ProgressData {
  version: number;
  activities: ProgressActivity[];
  assessments: ProgressAssessment[];
  goals: ProgressGoal[];
  skills: ProgressSkill[];
  milestones: ProgressMilestone[];
  daily_log: { date: string; activity_id: number }[];
  progress_percent: number;
  streak_days: number;
  last_activity_at: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface ProgressSummary {
  progress_percent: number;
  streak_days: number;
  total_activities: number;
  total_goals: number;
  completed_goals: number;
  total_skills: number;
  total_milestones: number;
  last_activity_at: string | null;
}

export interface AgentHealthInfo {
  progress_tracker: "ok" | "down";
  computer_use: "ok" | "down";
}
