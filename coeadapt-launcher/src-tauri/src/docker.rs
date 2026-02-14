use std::io::{BufRead, BufReader};
use std::process::{Command, Stdio};

use crate::state::{ContainerRuntime, DockerInfo, PullProgress};

pub fn detect_runtime() -> ContainerRuntime {
    if docker_cmd(&["info"]).is_ok() {
        ContainerRuntime::Docker
    } else if Command::new("podman")
        .arg("info")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        ContainerRuntime::Podman
    } else {
        ContainerRuntime::None
    }
}

pub fn get_docker_info() -> Result<DockerInfo, String> {
    let runtime = detect_runtime();
    match runtime {
        ContainerRuntime::None => Ok(DockerInfo {
            runtime: ContainerRuntime::None,
            version: String::new(),
            is_daemon_running: false,
        }),
        _ => {
            let version = docker_cmd(&["version", "--format", "{{.Server.Version}}"])
                .unwrap_or_else(|_| "unknown".to_string());
            Ok(DockerInfo {
                runtime: runtime.clone(),
                version,
                is_daemon_running: runtime != ContainerRuntime::None,
            })
        }
    }
}

pub fn docker_cmd(args: &[&str]) -> Result<String, String> {
    let output = Command::new("docker")
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| format!("Failed to execute docker: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).trim().to_string())
    }
}

pub fn docker_pull_streaming(
    image: &str,
    app_handle: tauri::AppHandle,
) -> Result<(), String> {
    let mut child = Command::new("docker")
        .args(["pull", image])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn docker pull: {}", e))?;

    let stdout = child.stdout.take().unwrap();
    let reader = BufReader::new(stdout);

    for line in reader.lines() {
        if let Ok(line) = line {
            let progress = parse_pull_line(&line);
            let _ = app_handle.emit("docker-pull-progress", &progress);
        }
    }

    let status = child.wait().map_err(|e| e.to_string())?;
    if !status.success() {
        return Err("Image pull failed".to_string());
    }
    Ok(())
}

fn parse_pull_line(line: &str) -> PullProgress {
    // Docker pull output looks like:
    // "abc123: Pulling fs layer"
    // "abc123: Downloading [===>   ] 12.5MB/100MB"
    // "abc123: Pull complete"
    // "Digest: sha256:..."
    // "Status: Downloaded newer image for ..."
    let percent = if line.contains("Pull complete") || line.contains("Already exists") {
        100.0
    } else if line.contains('/') && (line.contains("Downloading") || line.contains("Extracting")) {
        // Try to parse "12.5MB/100MB" style progress
        if let Some(bracket_start) = line.find(']') {
            if let Some(sizes) = line[bracket_start..].split_whitespace().nth(1) {
                let parts: Vec<&str> = sizes.split('/').collect();
                if parts.len() == 2 {
                    let current = parse_size(parts[0]);
                    let total = parse_size(parts[1]);
                    if total > 0.0 {
                        return PullProgress {
                            status: line.to_string(),
                            progress: Some(sizes.to_string()),
                            percent: (current / total * 100.0).min(100.0),
                        };
                    }
                }
            }
        }
        -1.0
    } else {
        -1.0
    };

    PullProgress {
        status: line.to_string(),
        progress: None,
        percent,
    }
}

fn parse_size(s: &str) -> f64 {
    let s = s.trim();
    if let Some(num) = s.strip_suffix("GB") {
        num.parse::<f64>().unwrap_or(0.0) * 1024.0
    } else if let Some(num) = s.strip_suffix("MB") {
        num.parse::<f64>().unwrap_or(0.0)
    } else if let Some(num) = s.strip_suffix("kB") {
        num.parse::<f64>().unwrap_or(0.0) / 1024.0
    } else if let Some(num) = s.strip_suffix("B") {
        num.parse::<f64>().unwrap_or(0.0) / 1024.0 / 1024.0
    } else {
        s.parse::<f64>().unwrap_or(0.0)
    }
}

#[cfg(target_os = "windows")]
pub fn is_wsl2_enabled() -> bool {
    Command::new("wsl")
        .args(["--list", "--verbose"])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

#[cfg(not(target_os = "windows"))]
pub fn is_wsl2_enabled() -> bool {
    true // Not applicable on non-Windows
}
