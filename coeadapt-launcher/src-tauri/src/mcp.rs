use std::sync::Mutex;
use tauri::Manager;
use tauri_plugin_shell::ShellExt;
use tauri_plugin_shell::process::{CommandChild, CommandEvent};
use tauri_plugin_store::StoreExt;

/// Global singleton holding the running sidecar child process.
/// Option so we can .take() it when killing (kill consumes self).
static MCP_CHILD: Mutex<Option<CommandChild>> = Mutex::new(None);

/// Spawn the MCP sidecar binary. Idempotent — does nothing if already running.
pub fn start_mcp_sidecar(app: &tauri::AppHandle) -> Result<(), String> {
    let mut guard = MCP_CHILD.lock().map_err(|e| e.to_string())?;

    // Already have a child handle — assume it's still running
    if guard.is_some() {
        return Ok(());
    }

    // Read device token and API URL from Tauri store for Navi API access
    let device_token = app
        .store("auth.json")
        .ok()
        .and_then(|store| store.get("deviceToken"))
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_default();

    let api_url = std::env::var("COEADAPT_API_URL")
        .unwrap_or_else(|_| "https://api.coeadapt.com".to_string());

    let sidecar_command = app
        .shell()
        .sidecar("coeadapt-mcp")
        .map_err(|e| format!("Failed to create sidecar command: {}", e))?
        .env("COEADAPT_DEVICE_TOKEN", &device_token)
        .env("COEADAPT_API_URL", &api_url);

    let (mut rx, child) = sidecar_command
        .spawn()
        .map_err(|e| format!("Failed to spawn MCP sidecar: {}", e))?;

    eprintln!("[mcp] Sidecar started (pid {})", child.pid());

    *guard = Some(child);
    drop(guard); // Release lock before spawning the reader task

    // Drain stdout/stderr and auto-restart on termination
    let app_handle = app.clone();
    tauri::async_runtime::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                CommandEvent::Stdout(bytes) => {
                    let line = String::from_utf8_lossy(&bytes);
                    eprintln!("[mcp-stdout] {}", line.trim());
                }
                CommandEvent::Stderr(bytes) => {
                    let line = String::from_utf8_lossy(&bytes);
                    eprintln!("[mcp-stderr] {}", line.trim());
                }
                CommandEvent::Terminated(payload) => {
                    eprintln!(
                        "[mcp] Sidecar terminated (code: {:?}, signal: {:?})",
                        payload.code, payload.signal
                    );
                    // Clear the stored child
                    if let Ok(mut guard) = MCP_CHILD.lock() {
                        *guard = None;
                    }
                    // Auto-restart after a short delay
                    tokio::time::sleep(std::time::Duration::from_secs(2)).await;
                    eprintln!("[mcp] Auto-restarting sidecar...");
                    if let Err(e) = start_mcp_sidecar(&app_handle) {
                        eprintln!("[mcp] Auto-restart failed: {}", e);
                    }
                    break;
                }
                _ => {}
            }
        }
    });

    Ok(())
}

/// Stop the MCP sidecar. Idempotent — does nothing if not running.
pub fn stop_mcp_sidecar() -> Result<(), String> {
    let mut guard = MCP_CHILD.lock().map_err(|e| e.to_string())?;
    if let Some(child) = guard.take() {
        child.kill().map_err(|e| format!("Failed to kill MCP sidecar: {}", e))?;
        eprintln!("[mcp] Sidecar stopped");
    }
    Ok(())
}

/// Check if the MCP sidecar child handle is present.
pub fn is_mcp_running() -> bool {
    MCP_CHILD
        .lock()
        .map(|guard| guard.is_some())
        .unwrap_or(false)
}
