use sysinfo::Disks;

use crate::docker::docker_cmd;
use crate::state::{DiskStatus, DockerDiskUsage};

pub fn check_disk_space() -> DiskStatus {
    let disks = Disks::new_with_refreshed_list();

    for disk in disks.list() {
        let mount = disk.mount_point().to_str().unwrap_or("");

        // On Windows, check C:\. On macOS/Linux, check /
        let is_target = if cfg!(target_os = "windows") {
            mount.starts_with("C:")
        } else {
            mount == "/"
        };

        if is_target {
            let available_gb = disk.available_space() as f64 / 1_073_741_824.0;
            let total_gb = disk.total_space() as f64 / 1_073_741_824.0;
            return DiskStatus {
                available_gb: (available_gb * 10.0).round() / 10.0,
                total_gb: (total_gb * 10.0).round() / 10.0,
                meets_minimum: available_gb >= 15.0,
                meets_recommended: available_gb >= 25.0,
                is_low: available_gb < 5.0,
            };
        }
    }

    // Fallback if we can't determine
    DiskStatus {
        available_gb: 100.0,
        total_gb: 500.0,
        meets_minimum: true,
        meets_recommended: true,
        is_low: false,
    }
}

pub fn get_docker_disk_usage() -> Result<DockerDiskUsage, String> {
    let output = docker_cmd(&["system", "df", "--format", "{{.Type}}\t{{.Size}}"])?;

    let mut images_size = String::from("0B");
    let mut containers_size = String::from("0B");
    let mut volumes_size = String::from("0B");

    for line in output.lines() {
        let parts: Vec<&str> = line.split('\t').collect();
        if parts.len() >= 2 {
            match parts[0] {
                "Images" => images_size = parts[1].to_string(),
                "Containers" => containers_size = parts[1].to_string(),
                "Local Volumes" => volumes_size = parts[1].to_string(),
                _ => {}
            }
        }
    }

    Ok(DockerDiskUsage {
        total_size: format!(
            "Images: {}, Containers: {}, Volumes: {}",
            images_size, containers_size, volumes_size
        ),
        images_size,
        containers_size,
        volumes_size,
    })
}
