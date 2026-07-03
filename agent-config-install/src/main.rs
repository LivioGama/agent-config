use clap::Parser;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use tracing::info;

/// Agent Config Install - Install agent-config system and handlers
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Verbose output
    #[arg(short, long)]
    verbose: bool,
}

fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    let _args = Args::parse();

    // Run installation
    install_agent_config()?;

    Ok(())
}

fn install_agent_config() -> anyhow::Result<()> {
    info!("🚀 Installing Agent Config...");

    // Clone repository if not already present
    let home_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?;
    let repo_dir = home_dir.join("agent-config");

    if !repo_dir.exists() {
        info!("Cloning repository to {}...", repo_dir.display());
        clone_repo(&repo_dir)?;
    }

    let config_root = home_dir.join(".agent-config");

    // Initialize live configuration
    if !config_root.join("rules").exists() {
        info!("Initializing live configuration at {}...", config_root.display());
        initialize_config(&repo_dir, &config_root)?;
    }

    // Detect OS and install handler
    let os = detect_os();
    info!("Detected OS: {}", os);

    match os.as_str() {
        "macos" => install_macos_handler(&repo_dir)?,
        "linux" => install_linux_handler(&repo_dir)?,
        "windows" => {
            info!("⚠️ Windows: Please follow manual installation steps");
        }
        _ => {
            info!("⚠️ Unsupported OS: {}", os);
        }
    }

    // Run initial build
    info!("🔄 Running initial build...");
    run_build(&repo_dir, &config_root)?;

    info!("✅ Agent Config installed successfully!");

    Ok(())
}

fn clone_repo(repo_dir: &PathBuf) -> anyhow::Result<()> {
    let output = Command::new("git")
        .arg("clone")
        .arg("https://github.com/LivioGama/agent-config.git")
        .arg(repo_dir)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("Git clone failed: {}", stderr));
    }

    Ok(())
}

fn initialize_config(repo_dir: &PathBuf, config_root: &PathBuf) -> anyhow::Result<()> {
    fs::create_dir_all(config_root)?;

    let source_config = repo_dir.join(".agent-config");
    if source_config.exists() {
        // Copy from repo config
        let output = Command::new("rsync")
            .arg("-a")
            .arg(&format!("{}/", source_config.display()))
            .arg(&format!("{}/", config_root.display()))
            .output()?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!("rsync failed: {}", stderr));
        }
    }

    Ok(())
}

fn detect_os() -> String {
    std::env::consts::OS.to_string()
}

fn install_macos_handler(repo_dir: &PathBuf) -> anyhow::Result<()> {
    info!("🍎 Building macOS AgentConfigHandler...");

    let handler_dir = repo_dir.join("AgentConfigHandler");
    let build_script = handler_dir.join("build.sh");

    if !build_script.exists() {
        info!("AgentConfigHandler not found, skipping macOS handler installation");
        return Ok(());
    }

    let output = Command::new("bash")
        .arg(&build_script)
        .current_dir(&handler_dir)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("macOS handler build failed: {}", stderr));
    }

    info!("macOS handler installed successfully");
    Ok(())
}

fn install_linux_handler(repo_dir: &PathBuf) -> anyhow::Result<()> {
    info!("🐧 Installing Linux AgentConfigHandler...");

    let handler_dir = repo_dir.join("AgentConfigHandler");
    let install_script = handler_dir.join("install-linux.sh");

    if !install_script.exists() {
        info!("Linux handler installer not found, skipping");
        return Ok(());
    }

    let output = Command::new("bash")
        .arg(&install_script)
        .current_dir(&handler_dir)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("Linux handler installation failed: {}", stderr));
    }

    info!("Linux handler installed successfully");
    Ok(())
}

fn run_build(repo_dir: &PathBuf, config_root: &PathBuf) -> anyhow::Result<()> {
    let build_script = repo_dir.join("build.sh");

    if !build_script.exists() {
        // Try Rust build binary instead
        let rust_build = repo_dir.join("target/release/agent-config-build");
        if rust_build.exists() {
            let output = Command::new(&rust_build)
                .arg("--config-root")
                .arg(config_root)
                .output()?;

            if !output.status.success() {
                let stderr = String::from_utf8_lossy(&output.stderr);
                return Err(anyhow::anyhow!("Rust build failed: {}", stderr));
            }
            return Ok(());
        }
    }

    let output = Command::new("bash")
        .arg(&build_script)
        .current_dir(repo_dir)
        .env("AGENT_CONFIG_ROOT", config_root)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("build.sh failed: {}", stderr));
    }

    Ok(())
}