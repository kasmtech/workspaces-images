use crate::docker::docker_cmd;
use crate::state::{ContainerState, ContainerStatus, CONTAINER_NAME, IMAGE_NAME, VOLUME_NAME};

pub fn get_container_status() -> ContainerStatus {
    let result = docker_cmd(&[
        "inspect",
        "--format",
        "{{.State.Status}}|{{.Id}}|{{.State.StartedAt}}|{{.Config.Image}}",
        CONTAINER_NAME,
    ]);

    match result {
        Ok(output) => {
            let parts: Vec<&str> = output.split('|').collect();
            if parts.len() >= 4 {
                let state = match parts[0] {
                    "running" => ContainerState::Running,
                    "exited" | "dead" => ContainerState::Stopped,
                    "created" | "restarting" => ContainerState::Starting,
                    _ => ContainerState::Stopped,
                };
                let container_id = Some(parts[1][..12.min(parts[1].len())].to_string());
                let uptime = if state == ContainerState::Running {
                    Some(parts[2].to_string())
                } else {
                    None
                };
                ContainerStatus {
                    state,
                    container_id,
                    uptime,
                    image: parts[3].to_string(),
                }
            } else {
                ContainerStatus {
                    state: ContainerState::Error("Failed to parse container info".to_string()),
                    container_id: None,
                    uptime: None,
                    image: IMAGE_NAME.to_string(),
                }
            }
        }
        Err(_) => ContainerStatus {
            state: ContainerState::NotFound,
            container_id: None,
            uptime: None,
            image: IMAGE_NAME.to_string(),
        },
    }
}

pub fn create_container() -> Result<String, String> {
    docker_cmd(&[
        "run",
        "-d",
        "--name",
        CONTAINER_NAME,
        "--shm-size=512m",
        "-p",
        "6901:6901",
        "-v",
        &format!("{}:/home/kasm-user", VOLUME_NAME),
        "-e",
        "VNC_PW=coeadapt",
        "--restart",
        "unless-stopped",
        IMAGE_NAME,
    ])
}

pub fn start_container() -> Result<(), String> {
    docker_cmd(&["start", CONTAINER_NAME])?;
    Ok(())
}

pub fn stop_container() -> Result<(), String> {
    docker_cmd(&["stop", CONTAINER_NAME])?;
    Ok(())
}

pub fn remove_container() -> Result<(), String> {
    // Stop first if running
    let _ = docker_cmd(&["stop", CONTAINER_NAME]);
    docker_cmd(&["rm", CONTAINER_NAME])?;
    Ok(())
}

pub fn image_exists() -> bool {
    docker_cmd(&["image", "inspect", IMAGE_NAME]).is_ok()
}

pub fn check_for_image_update() -> Result<bool, String> {
    // Get the current image digest
    let _current_digest = docker_cmd(&[
        "image",
        "inspect",
        "--format",
        "{{index .RepoDigests 0}}",
        IMAGE_NAME,
    ])
    .unwrap_or_default();

    // Pull latest
    let pull_output = docker_cmd(&["pull", IMAGE_NAME])?;

    // Check if "Status: Image is up to date" is in the output
    Ok(!pull_output.contains("Image is up to date"))
}

pub fn remove_workspace_data() -> Result<(), String> {
    docker_cmd(&["volume", "rm", VOLUME_NAME])?;
    Ok(())
}

pub fn prune_images() -> Result<String, String> {
    docker_cmd(&["image", "prune", "-f"])
}
