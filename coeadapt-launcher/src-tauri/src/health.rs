use std::time::Duration;
use tauri::Emitter;

pub async fn wait_for_workspace(
    app: tauri::AppHandle,
    timeout: Duration,
) -> Result<(), String> {
    let client = reqwest::Client::builder()
        .danger_accept_invalid_certs(true)
        .timeout(Duration::from_secs(5))
        .build()
        .map_err(|e| e.to_string())?;

    let start = std::time::Instant::now();
    let mut attempt = 0u32;

    while start.elapsed() < timeout {
        attempt += 1;
        let _ = app.emit(
            "health-check",
            serde_json::json!({
                "attempt": attempt,
                "elapsed_secs": start.elapsed().as_secs(),
            }),
        );

        match client.get("https://localhost:6901").send().await {
            Ok(resp) if resp.status().is_success() || resp.status().is_redirection() => {
                let _ = app.emit("workspace-ready", true);
                return Ok(());
            }
            _ => {
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
        }
    }

    Err(format!(
        "Workspace not ready after {}s",
        timeout.as_secs()
    ))
}

pub async fn check_mcp_health() -> bool {
    get_mcp_health_info().await.is_running
}

pub async fn get_mcp_health_info() -> crate::state::McpHealthInfo {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(3))
        .build()
        .unwrap_or_default();

    match client.get("http://127.0.0.1:3100/health").send().await {
        Ok(resp) if resp.status().is_success() => {
            if let Ok(body) = resp.json::<serde_json::Value>().await {
                crate::state::McpHealthInfo {
                    is_running: true,
                    last_tool_call: body.get("lastToolCall").and_then(|v| v.as_u64()),
                    uptime_secs: body.get("uptime").and_then(|v| v.as_f64()),
                }
            } else {
                crate::state::McpHealthInfo {
                    is_running: true,
                    last_tool_call: None,
                    uptime_secs: None,
                }
            }
        }
        _ => crate::state::McpHealthInfo {
            is_running: false,
            last_tool_call: None,
            uptime_secs: None,
        },
    }
}
