use std::path::PathBuf;

use crate::state::ClaudeStatus;

pub fn claude_config_path() -> Option<PathBuf> {
    if cfg!(target_os = "macos") {
        dirs::home_dir()
            .map(|h| h.join("Library/Application Support/Claude/claude_desktop_config.json"))
    } else if cfg!(target_os = "windows") {
        std::env::var("APPDATA")
            .ok()
            .map(|a| PathBuf::from(a).join("Claude").join("claude_desktop_config.json"))
    } else {
        dirs::config_dir().map(|c| c.join("Claude/claude_desktop_config.json"))
    }
}

pub fn is_claude_installed() -> bool {
    claude_config_path()
        .map(|p| {
            p.parent()
                .map(|d| d.exists())
                .unwrap_or(false)
        })
        .unwrap_or(false)
}

pub fn is_coeadapt_configured() -> bool {
    let Some(config_path) = claude_config_path() else {
        return false;
    };
    if !config_path.exists() {
        return false;
    }
    let Ok(contents) = std::fs::read_to_string(&config_path) else {
        return false;
    };
    let Ok(config) = serde_json::from_str::<serde_json::Value>(&contents) else {
        return false;
    };
    config
        .get("mcpServers")
        .and_then(|s| s.get("coeadapt"))
        .is_some()
}

pub fn inject_coeadapt_config() -> Result<(), String> {
    let config_path = claude_config_path().ok_or("Cannot determine Claude config path")?;

    // Create backup before first edit
    if config_path.exists() {
        let backup = config_path.with_extension("json.bak");
        if !backup.exists() {
            std::fs::copy(&config_path, &backup).map_err(|e| e.to_string())?;
        }
    }

    let mut config: serde_json::Value = if config_path.exists() {
        let contents = std::fs::read_to_string(&config_path).map_err(|e| e.to_string())?;
        serde_json::from_str(&contents).map_err(|e| {
            format!(
                "Claude config JSON parse error: {}. Not modifying file.",
                e
            )
        })?
    } else {
        // Create parent directory if needed
        if let Some(parent) = config_path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        serde_json::json!({})
    };

    // Ensure mcpServers exists
    if config.get("mcpServers").is_none() {
        config["mcpServers"] = serde_json::json!({});
    }

    // Only add if not already present
    if config["mcpServers"].get("coeadapt").is_none() {
        config["mcpServers"]["coeadapt"] = serde_json::json!({
            "command": "npx",
            "args": ["mcp-remote", "http://localhost:3100/mcp"],
            "env": {}
        });
    }

    let formatted = serde_json::to_string_pretty(&config).map_err(|e| e.to_string())?;
    std::fs::write(&config_path, formatted).map_err(|e| e.to_string())?;
    Ok(())
}

pub fn remove_coeadapt_config() -> Result<(), String> {
    let config_path = claude_config_path().ok_or("Cannot determine Claude config path")?;
    if !config_path.exists() {
        return Ok(());
    }

    let contents = std::fs::read_to_string(&config_path).map_err(|e| e.to_string())?;
    let mut config: serde_json::Value =
        serde_json::from_str(&contents).map_err(|e| e.to_string())?;

    if let Some(servers) = config.get_mut("mcpServers") {
        if let Some(obj) = servers.as_object_mut() {
            obj.remove("coeadapt");
        }
    }

    let formatted = serde_json::to_string_pretty(&config).map_err(|e| e.to_string())?;
    std::fs::write(&config_path, formatted).map_err(|e| e.to_string())?;
    Ok(())
}

pub fn get_claude_status() -> ClaudeStatus {
    let installed = is_claude_installed();
    let config_path = claude_config_path().map(|p| p.to_string_lossy().to_string());
    let configured = is_coeadapt_configured();

    ClaudeStatus {
        is_installed: installed,
        config_path,
        is_configured: configured,
        needs_restart: false,
    }
}

pub fn verify_and_repair_config() -> Result<bool, String> {
    if !is_claude_installed() {
        return Ok(false);
    }
    if is_coeadapt_configured() {
        return Ok(false); // Already configured, no repair needed
    }
    // Config missing or coeadapt entry removed (e.g., Claude update)
    inject_coeadapt_config()?;
    Ok(true) // Repaired
}
