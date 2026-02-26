use std::path::PathBuf;
use std::process::Command;

use crate::docker::docker_cmd;
use crate::state::CONTAINER_NAME;

const CA_CONTAINER_PATH: &str = "/usr/share/coeadapt/ca.crt";
const CA_CERT_FILENAME: &str = "coeadapt-workspace-ca.crt";
const CA_SUBJECT_NAME: &str = "Coeadapt Workspace CA";

/// Local directory where we store the extracted CA cert on the host.
fn ca_data_dir() -> PathBuf {
    let dir = dirs::data_local_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("coeadapt-launcher");
    std::fs::create_dir_all(&dir).ok();
    dir
}

/// Full path to the CA cert on the host.
fn ca_cert_path() -> PathBuf {
    ca_data_dir().join(CA_CERT_FILENAME)
}

/// Extract the CA certificate from the running container to the host.
pub fn extract_ca_cert() -> Result<PathBuf, String> {
    let dest = ca_cert_path();
    let dest_str = dest.to_str().ok_or("Invalid path")?;
    let src = format!("{}:{}", CONTAINER_NAME, CA_CONTAINER_PATH);

    docker_cmd(&["cp", &src, dest_str])?;

    if dest.exists() {
        Ok(dest)
    } else {
        Err("CA cert was not extracted".to_string())
    }
}

/// Check whether the Coeadapt CA is already trusted by the host OS.
pub fn is_ca_installed() -> bool {
    #[cfg(target_os = "windows")]
    return is_ca_installed_windows();

    #[cfg(target_os = "macos")]
    return is_ca_installed_macos();

    #[cfg(target_os = "linux")]
    return is_ca_installed_linux();

    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    return false;
}

/// Install the CA certificate into the host OS trust store.
/// On Windows this triggers a security confirmation dialog.
pub fn install_ca_cert() -> Result<(), String> {
    let cert_path = ca_cert_path();

    // Extract first if not already on disk
    if !cert_path.exists() {
        extract_ca_cert()?;
    }

    #[cfg(any(target_os = "windows", target_os = "macos"))]
    let cert_str = cert_path.to_str().ok_or("Invalid cert path")?;

    #[cfg(target_os = "windows")]
    return install_ca_windows(cert_str);

    #[cfg(target_os = "macos")]
    return install_ca_macos(cert_str);

    #[cfg(target_os = "linux")]
    return install_ca_linux(&cert_path);

    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    return Err("Unsupported platform".to_string());
}

/// Remove the Coeadapt CA from the host trust store.
pub fn uninstall_ca_cert() -> Result<(), String> {
    #[cfg(target_os = "windows")]
    uninstall_ca_windows()?;

    #[cfg(target_os = "macos")]
    uninstall_ca_macos()?;

    #[cfg(target_os = "linux")]
    uninstall_ca_linux();

    // Remove local copy
    let _ = std::fs::remove_file(ca_cert_path());
    Ok(())
}

// --- Platform-specific implementations ---

#[cfg(target_os = "windows")]
fn is_ca_installed_windows() -> bool {
    let output = Command::new("powershell")
        .args([
            "-NoProfile",
            "-Command",
            &format!(
                "Get-ChildItem Cert:\\CurrentUser\\Root | Where-Object {{ $_.Subject -like '*{}*' }} | Measure-Object | Select-Object -ExpandProperty Count",
                CA_SUBJECT_NAME
            ),
        ])
        .output();

    match output {
        Ok(out) if out.status.success() => {
            let count = String::from_utf8_lossy(&out.stdout).trim().to_string();
            count != "0"
        }
        _ => false,
    }
}

#[cfg(target_os = "windows")]
fn install_ca_windows(cert_str: &str) -> Result<(), String> {
    let status = Command::new("certutil")
        .args(["-addstore", "-user", "Root", cert_str])
        .status()
        .map_err(|e| format!("Failed to run certutil: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err("Certificate installation failed. Please accept the security prompt.".to_string())
    }
}

#[cfg(target_os = "windows")]
fn uninstall_ca_windows() -> Result<(), String> {
    let status = Command::new("powershell")
        .args([
            "-NoProfile",
            "-Command",
            &format!(
                "Get-ChildItem Cert:\\CurrentUser\\Root | Where-Object {{ $_.Subject -like '*{}*' }} | Remove-Item",
                CA_SUBJECT_NAME
            ),
        ])
        .status()
        .map_err(|e| format!("Failed to remove CA: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err("Failed to remove CA certificate from trust store".to_string())
    }
}

#[cfg(target_os = "macos")]
fn is_ca_installed_macos() -> bool {
    let output = Command::new("security")
        .args(["find-certificate", "-c", CA_SUBJECT_NAME, "-a"])
        .output();

    matches!(output, Ok(out) if out.status.success())
}

#[cfg(target_os = "macos")]
fn install_ca_macos(cert_str: &str) -> Result<(), String> {
    let home = std::env::var("HOME")
        .map_err(|_| "HOME environment variable not set".to_string())?;
    let keychain = format!("{}/Library/Keychains/login.keychain-db", home);

    let status = Command::new("security")
        .args([
            "add-trusted-cert",
            "-r",
            "trustRoot",
            "-k",
            &keychain,
            cert_str,
        ])
        .status()
        .map_err(|e| format!("Failed to install CA: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err("Certificate installation failed".to_string())
    }
}

#[cfg(target_os = "macos")]
fn uninstall_ca_macos() -> Result<(), String> {
    let cert_path = ca_cert_path();
    if cert_path.exists() {
        if let Some(cert_str) = cert_path.to_str() {
            let _ = Command::new("security")
                .args(["remove-trusted-cert", cert_str])
                .status();
        }
    }
    Ok(())
}

#[cfg(target_os = "linux")]
fn is_ca_installed_linux() -> bool {
    std::path::Path::new(&format!(
        "/usr/local/share/ca-certificates/{}",
        CA_CERT_FILENAME
    ))
    .exists()
}

#[cfg(target_os = "linux")]
fn install_ca_linux(cert_path: &std::path::Path) -> Result<(), String> {
    let dest = format!("/usr/local/share/ca-certificates/{}", CA_CERT_FILENAME);
    let cert_str = cert_path.to_str().unwrap_or_default();

    // Use pkexec for privilege elevation (shows a graphical password prompt)
    let status = Command::new("pkexec")
        .args(["bash", "-c", &format!("cp '{}' '{}' && update-ca-certificates", cert_str, dest)])
        .status()
        .map_err(|e| format!("Failed to install CA cert: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err("Failed to install CA cert (authentication required)".to_string())
    }
}

#[cfg(target_os = "linux")]
fn uninstall_ca_linux() {
    let sys_cert = format!("/usr/local/share/ca-certificates/{}", CA_CERT_FILENAME);
    let _ = std::fs::remove_file(&sys_cert);
    let _ = Command::new("update-ca-certificates").status();
}
