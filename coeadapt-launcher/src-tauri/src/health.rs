use std::time::Duration;

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
    reqwest::get("http://127.0.0.1:3100/health")
        .await
        .map(|r| r.status().is_success())
        .unwrap_or(false)
}
