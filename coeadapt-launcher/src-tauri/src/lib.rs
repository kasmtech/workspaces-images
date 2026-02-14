mod claude;
mod commands;
mod container;
mod disk;
mod docker;
mod health;
mod state;

use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Emitter, Manager,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .setup(|app| {
            // Build tray menu
            let open_workspace = MenuItem::with_id(app, "open_workspace", "Open Workspace", true, None::<&str>)?;
            let start = MenuItem::with_id(app, "start", "Start Workspace", true, None::<&str>)?;
            let stop = MenuItem::with_id(app, "stop", "Stop Workspace", true, None::<&str>)?;
            let show_window = MenuItem::with_id(app, "show", "Show Dashboard", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit CoeAdapt", true, None::<&str>)?;

            let menu = Menu::with_items(
                app,
                &[&open_workspace, &start, &stop, &show_window, &quit],
            )?;

            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .tooltip("CoeAdapt")
                .on_menu_event(move |app, event| match event.id.as_ref() {
                    "open_workspace" => {
                        let _ = commands::open_workspace_browser();
                    }
                    "start" => {
                        let status = container::get_container_status();
                        match status.state {
                            state::ContainerState::NotFound => {
                                let _ = container::create_container();
                            }
                            state::ContainerState::Stopped => {
                                let _ = container::start_container();
                            }
                            _ => {}
                        }
                    }
                    "stop" => {
                        let _ = container::stop_container();
                    }
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    "quit" => {
                        let _ = container::stop_container();
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            // On launch: verify Claude config
            let _ = claude::verify_and_repair_config();

            // Start disk monitoring (every 30 min)
            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                loop {
                    let status = disk::check_disk_space();
                    if status.is_low {
                        let _ = handle.emit("disk-warning", &status);
                    }
                    tokio::time::sleep(std::time::Duration::from_secs(1800)).await;
                }
            });

            Ok(())
        })
        .on_window_event(|window, event| {
            // Hide to tray on close instead of quitting
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                let _ = window.hide();
                api.prevent_close();
            }
        })
        .invoke_handler(tauri::generate_handler![
            commands::detect_container_runtime,
            commands::check_wsl2_status,
            commands::check_disk_space,
            commands::get_docker_disk_usage,
            commands::prune_docker_images,
            commands::get_workspace_status,
            commands::check_image_exists,
            commands::pull_workspace_image,
            commands::create_workspace,
            commands::start_workspace,
            commands::stop_workspace,
            commands::reset_workspace,
            commands::wait_for_workspace_ready,
            commands::check_mcp_status,
            commands::get_claude_status,
            commands::configure_claude,
            commands::open_workspace_browser,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
