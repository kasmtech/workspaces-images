use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ContainerRuntime {
    Docker,
    Podman,
    None,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DockerInfo {
    pub runtime: ContainerRuntime,
    pub version: String,
    pub is_daemon_running: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ContainerState {
    NotFound,
    Running,
    Stopped,
    Starting,
    Pulling,
    Error(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerStatus {
    pub state: ContainerState,
    pub container_id: Option<String>,
    pub uptime: Option<String>,
    pub image: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskStatus {
    pub available_gb: f64,
    pub total_gb: f64,
    pub meets_minimum: bool,
    pub meets_recommended: bool,
    pub is_low: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DockerDiskUsage {
    pub images_size: String,
    pub containers_size: String,
    pub volumes_size: String,
    pub total_size: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClaudeStatus {
    pub is_installed: bool,
    pub config_path: Option<String>,
    pub is_configured: bool,
    pub needs_restart: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PullProgress {
    pub status: String,
    pub progress: Option<String>,
    pub percent: f64,
}

pub const CONTAINER_NAME: &str = "coeadapt-workspace";
pub const IMAGE_NAME: &str = "coeadapt/workspace:latest";
pub const VOLUME_NAME: &str = "coeadapt-data";
