use crate::{claude, container, disk, docker, health, mcp};
use std::time::Duration;

// --- Docker Detection ---

#[tauri::command]
pub fn detect_container_runtime() -> crate::state::DockerInfo {
    docker::get_docker_info().unwrap_or(crate::state::DockerInfo {
        runtime: crate::state::ContainerRuntime::None,
        version: String::new(),
        is_daemon_running: false,
    })
}

#[tauri::command]
pub fn check_wsl2_status() -> bool {
    docker::is_wsl2_enabled()
}

// --- Disk Space ---

#[tauri::command]
pub fn check_disk_space() -> crate::state::DiskStatus {
    disk::check_disk_space()
}

#[tauri::command]
pub fn get_docker_disk_usage() -> Result<crate::state::DockerDiskUsage, String> {
    disk::get_docker_disk_usage()
}

#[tauri::command]
pub fn prune_docker_images() -> Result<String, String> {
    container::prune_images()
}

// --- Container Lifecycle ---

#[tauri::command]
pub fn get_workspace_status() -> crate::state::ContainerStatus {
    container::get_container_status()
}

#[tauri::command]
pub fn check_image_exists() -> bool {
    container::image_exists()
}

#[tauri::command]
pub async fn pull_workspace_image(app: tauri::AppHandle) -> Result<(), String> {
    // Run in a blocking thread since docker_pull_streaming uses std::process
    let app_clone = app.clone();
    tokio::task::spawn_blocking(move || {
        docker::docker_pull_streaming(crate::state::IMAGE_NAME, app_clone)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub fn create_workspace(app: tauri::AppHandle) -> Result<String, String> {
    use tauri_plugin_store::StoreExt;

    let (memory_mb, vnc_password) = if let Ok(store) = app.store("settings.json") {
        let mem = store
            .get("containerMemoryMb")
            .and_then(|v| v.as_u64())
            .unwrap_or(2048);
        let pw = store
            .get("vncPassword")
            .and_then(|v| v.as_str().map(|s| s.to_string()))
            .unwrap_or_else(|| "coeadapt".to_string());
        (mem, pw)
    } else {
        (2048, "coeadapt".to_string())
    };

    container::create_container_with_config(memory_mb, &vnc_password)
}

#[tauri::command]
pub fn start_workspace() -> Result<(), String> {
    container::start_container()
}

#[tauri::command]
pub fn stop_workspace() -> Result<(), String> {
    container::stop_container()
}

#[tauri::command]
pub fn reset_workspace() -> Result<(), String> {
    container::remove_container()?;
    container::remove_workspace_data()?;
    Ok(())
}

// --- Health ---

#[tauri::command]
pub async fn wait_for_workspace_ready(app: tauri::AppHandle) -> Result<(), String> {
    health::wait_for_workspace(app, Duration::from_secs(120)).await
}

// --- MCP ---

#[tauri::command]
pub async fn check_mcp_status() -> bool {
    health::check_mcp_health().await
}

#[tauri::command]
pub async fn get_mcp_health() -> crate::state::McpHealthInfo {
    health::get_mcp_health_info().await
}

#[tauri::command]
pub fn start_mcp(app: tauri::AppHandle) -> Result<(), String> {
    mcp::start_mcp_sidecar(&app)
}

#[tauri::command]
pub fn stop_mcp() -> Result<(), String> {
    mcp::stop_mcp_sidecar()
}

// --- Claude Connection ---

#[tauri::command]
pub fn get_claude_status() -> crate::state::ClaudeStatus {
    claude::get_claude_status()
}

#[tauri::command]
pub fn configure_claude() -> Result<(), String> {
    claude::inject_coeadapt_config()
}

// --- Workspace Browser ---

#[tauri::command]
pub fn open_workspace_browser() -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("cmd")
            .args(["/C", "start", "https://localhost:6901"])
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg("https://localhost:6901")
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg("https://localhost:6901")
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}
