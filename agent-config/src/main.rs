use agent_config_core::{Config, RuleCollection, is_safe_rule_filename, is_safe_skill_name};
use anyhow::Context;
use clap::{Parser, Subcommand};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use tracing::{info, error};
use percent_encoding::percent_decode_str;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    let args = Cli::parse();

    match args.command {
        Commands::Build { config_root, repo_dir, .. } => {
            run_build(BuildArgs { config_root, repo_dir }).await
        }
        Commands::Sync { .. } => {
            run_sync(SyncArgs {}).await
        }
        Commands::Deeplink { deeplink } => {
            run_deeplink(DeeplinkArgs { deeplink }).await
        }
        Commands::Install { .. } => {
            run_install(InstallArgs {}).await
        }
    }
}

#[derive(Parser, Debug)]
#[command(name = "agent-config")]
#[command(about = "Agent Config - Manage AI agent conventions and skills", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Generate tool configurations from canonical rules
    Build {
        /// Override configuration root directory
        #[arg(long, env = "AGENT_CONFIG_ROOT")]
        config_root: Option<String>,

        /// Override repository directory
        #[arg(long, env = "AGENT_CONFIG_REPO_DIR")]
        repo_dir: Option<String>,

        /// Verbose output
        #[arg(short, long)]
        verbose: bool,
    },
    /// Distribute skills to all tool directories
    Sync {
        /// Verbose output
        #[arg(short, long)]
        verbose: bool,
    },
    /// Process agent-config:// URLs
    Deeplink {
        /// Deeplink URL to process
        deeplink: String,
    },
    /// Install agent-config system and handlers
    Install {
        /// Verbose output
        #[arg(short, long)]
        verbose: bool,
    },
}

async fn run_build(args: BuildArgs) -> anyhow::Result<()> {
    // Set environment overrides if provided
    if let Some(config_root) = args.config_root {
        std::env::set_var("AGENT_CONFIG_ROOT", config_root);
    }
    if let Some(repo_dir) = args.repo_dir {
        std::env::set_var("AGENT_CONFIG_REPO_DIR", repo_dir);
    }

    // Load configuration
    let config = Config::from_env()
        .context("Failed to load configuration")?;

    info!("Configuration loaded:");
    info!("  Config root: {}", config.config_root.display());
    info!("  Repo dir: {}", config.repo_dir.display());

    info!("Starting build process");

    // Ensure configuration directories exist
    ensure_directories(&config)?;

    // Load rules
    info!("Loading rules from {}", config.rules_dir().display());
    let mut rules = RuleCollection::load_from_dir(&config.rules_dir())
        .context("Failed to load rules")?;

    info!("Loaded {} rules", rules.rules().len());

    // Validate and sort rules
    for rule in rules.rules() {
        rule.validate()?;
    }
    rules.sort();

    // Generate AGENTS.md
    info!("Generating AGENTS.md");
    let agents_content = rules.concatenate();
    let agents_path = config.config_root.join("AGENTS.md");
    fs::write(&agents_path, agents_content)
        .context("Failed to write AGENTS.md")?;

    info!("Generated AGENTS.md at {}", agents_path.display());

    // Run rulesync if available
    if let Ok(_) = which::which("rulesync") {
        info!("Running rulesync");
        run_rulesync(&config)?;
    } else {
        info!("rulesync not found in PATH, skipping");
    }

    // Deploy to tool directories
    info!("Deploying to tool directories");
    deploy_to_tools(&config)?;

    info!("Build completed successfully");

    Ok(())
}

async fn run_sync(_args: SyncArgs) -> anyhow::Result<()> {
    // Find canonical skills directory
    let canonical = find_canonical_skills_dir()
        .context("Failed to find canonical skills directory")?;

    if !canonical.exists() {
        info!("No canonical skills directory found, exiting");
        return Ok(());
    }

    info!("Found canonical skills directory: {}", canonical.display());

    // Define tool targets
    let tools = vec!["codex", "cursor", "gemini", "devin", "claude"];

    // Sync to each tool
    for tool in tools {
        sync_to_tool(&canonical, tool)?;
    }

    info!("Skills fanout complete (canonical: {})", canonical.display());

    Ok(())
}

async fn run_deeplink(args: DeeplinkArgs) -> anyhow::Result<()> {
    let deeplink = args.deeplink;
    let scheme_prefix = "agent-config://";

    if !deeplink.starts_with(scheme_prefix) {
        return Err(anyhow::anyhow!(
            "Invalid deeplink format. Expected {}https://...",
            scheme_prefix
        ));
    }

    let encoded_or_raw_url = &deeplink[scheme_prefix.len()..];
    let url = if encoded_or_raw_url.starts_with("https://") {
        encoded_or_raw_url.to_string()
    } else {
        match percent_decode_str(encoded_or_raw_url).decode_utf8() {
            Ok(decoded) => decoded.to_string(),
            Err(_) => encoded_or_raw_url.to_string(),
        }
    };

    // Validate URL format
    if !url.starts_with("https://") {
        return Err(anyhow::anyhow!("URL must start with https://"));
    }

    info!("Processing deeplink: {}", url);

    // Determine installation kind and destination
    let (install_kind, dest) = determine_destination(&url)?;

    // Download the file
    download_file(&url, &dest).await?;

    // Run build script
    run_build_script()?;

    info!(
        "Done! {} installed and synced.",
        capitalize(&install_kind)
    );

    Ok(())
}

async fn run_install(_args: InstallArgs) -> anyhow::Result<()> {
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
    run_build_script_with_config(&repo_dir, &config_root)?;

    info!("✅ Agent Config installed successfully!");

    Ok(())
}

// Helper structs for args
#[derive(Debug)]
struct BuildArgs {
    config_root: Option<String>,
    repo_dir: Option<String>,
}

#[derive(Debug)]
struct SyncArgs {}

#[derive(Debug)]
struct DeeplinkArgs {
    deeplink: String,
}

#[derive(Debug)]
struct InstallArgs {}

// Helper functions from individual binaries
fn ensure_directories(config: &Config) -> anyhow::Result<()> {
    fs::create_dir_all(&config.config_root)
        .context("Failed to create config root")?;
    fs::create_dir_all(config.rules_dir())
        .context("Failed to create rules directory")?;
    fs::create_dir_all(config.skills_dir())
        .context("Failed to create skills directory")?;

    Ok(())
}

fn run_rulesync(config: &Config) -> anyhow::Result<()> {
    let output = Command::new("rulesync")
        .arg("generate")
        .arg("--targets")
        .arg("*")
        .current_dir(&config.repo_dir)
        .output()
        .context("Failed to execute rulesync")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        error!("rulesync failed: {}", stderr);
        return Err(anyhow::anyhow!("rulesync failed: {}", stderr));
    }

    Ok(())
}

fn deploy_to_tools(config: &Config) -> anyhow::Result<()> {
    let claude_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?
        .join(".claude");

    if claude_dir.exists() {
        let agents_md = config.config_root.join("AGENTS.md");
        let claude_agents = claude_dir.join("CLAUDE.md");
        let claude_agents_md = claude_dir.join("AGENTS.md");

        fs::copy(&agents_md, &claude_agents)
            .context("Failed to copy to CLAUDE.md")?;
        fs::copy(&agents_md, &claude_agents_md)
            .context("Failed to copy to AGENTS.md")?;

        info!("Deployed to ~/.claude/");
    }

    let codex_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?
        .join(".codex");

    if codex_dir.exists() {
        let agents_md = config.config_root.join("AGENTS.md");
        let codex_agents = codex_dir.join("AGENTS.md");

        fs::copy(&agents_md, &codex_agents)
            .context("Failed to copy to Codex AGENTS.md")?;

        info!("Deployed to ~/.codex/");
    }

    let devin_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?
        .join(".devin");

    if devin_dir.exists() {
        let devin_rules = devin_dir.join("rules");
        if devin_rules.exists() {
            for entry in fs::read_dir(&config.rules_dir())? {
                let entry = entry?;
                if entry.path().extension().and_then(|s| s.to_str()) == Some("md") {
                    let dest = devin_rules.join(entry.file_name());
                    fs::copy(entry.path(), &dest)?;
                }
            }
            info!("Deployed to ~/.devin/rules/");
        }
    }

    Ok(())
}

fn find_canonical_skills_dir() -> anyhow::Result<PathBuf> {
    let repo_skills = PathBuf::from(".agent-config/skills");
    if repo_skills.exists() {
        return Ok(repo_skills);
    }

    let home_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?;
    let global_skills = home_dir.join(".agents/skills");
    if global_skills.exists() {
        return Ok(global_skills);
    }

    Err(anyhow::anyhow!("No canonical skills directory found"))
}

fn sync_to_tool(canonical: &Path, tool: &str) -> anyhow::Result<()> {
    let home_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?;

    let tool_dir = home_dir.join(format!(".{}", tool));
    let skills_dir = tool_dir.join("skills");

    fs::create_dir_all(&skills_dir)
        .context(format!("Failed to create skills directory for {}", tool))?;

    let excludes = vec![".git", ".DS_Store", "*.zip", "benchmark-playground"];
    let mut synced_count = 0;

    for entry in fs::read_dir(canonical)? {
        let entry = entry?;
        let entry_path = entry.path();

        let file_name = entry.file_name();
        let file_name_str = file_name.to_string_lossy();

        if excludes.iter().any(|exclude| {
            if exclude.starts_with("*.") {
                let ext = entry_path.extension().and_then(|s| s.to_str()).unwrap_or("");
                &format!("*.{}", ext) == exclude
            } else {
                file_name_str == *exclude
            }
        }) {
            continue;
        }

        let dest = skills_dir.join(&file_name);

        if dest.exists() {
            if dest.is_file() || dest.is_symlink() {
                fs::remove_file(&dest)?;
            } else {
                continue;
            }
        }

        if entry_path.is_file() {
            fs::copy(&entry_path, &dest)?;
        } else if entry_path.is_dir() {
            copy_dir_recursive(&entry_path, &dest)?;
        }

        synced_count += 1;
    }

    info!(
        "Synced shared skills → ~/.{}/skills/ ({} total)",
        tool, synced_count
    );

    Ok(())
}

fn copy_dir_recursive(src: &Path, dest: &Path) -> anyhow::Result<()> {
    fs::create_dir_all(dest)?;

    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let entry_path = entry.path();
        let dest_path = dest.join(entry.file_name());

        if entry_path.is_file() {
            fs::copy(&entry_path, &dest_path)?;
        } else if entry_path.is_dir() {
            copy_dir_recursive(&entry_path, &dest_path)?;
        }
    }

    Ok(())
}

fn determine_destination(url: &str) -> anyhow::Result<(String, PathBuf)> {
    let home_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?;
    let config_root = home_dir.join(".agent-config");

    let url_path = url
        .split('/')
        .skip(3)
        .collect::<Vec<&str>>()
        .join("/");

    if let Some(skills_index) = url_path.find("/skills/") {
        let after_skills = &url_path[skills_index + 8..];
        if let Some(skill_end) = after_skills.find("/SKILL.md") {
            let skill_name = &after_skills[..skill_end];
            if is_safe_skill_name(skill_name) {
                let dest = config_root
                    .join("skills")
                    .join(skill_name)
                    .join("SKILL.md");
                return Ok(("skill".to_string(), dest));
            }
        }
    }

    if url_path.contains(".agent-config/AGENTS.md") {
        let dest = config_root.join("AGENTS.md");
        return Ok(("agent config".to_string(), dest));
    }

    let filename = url
        .split('/')
        .last()
        .ok_or_else(|| anyhow::anyhow!("Cannot extract filename from URL"))?;

    if !is_safe_rule_filename(filename) {
        return Err(anyhow::anyhow!(
            "Invalid rule filename. Expected a safe .md basename"
        ));
    }

    let dest = config_root.join("rules").join(filename);
    Ok(("rule".to_string(), dest))
}

async fn download_file(url: &str, dest: &Path) -> anyhow::Result<()> {
    info!("Downloading from {}...", url);

    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent)?;
    }

    let response = reqwest::get(url).await?;
    if !response.status().is_success() {
        return Err(anyhow::anyhow!(
            "Download failed with status: {}",
            response.status()
        ));
    }

    let content = response.bytes().await?;

    if content.is_empty() {
        return Err(anyhow::anyhow!("Downloaded file is empty"));
    }

    fs::write(dest, content)?;

    info!("Saved to {}", dest.display());

    Ok(())
}

fn run_build_script() -> anyhow::Result<()> {
    info!("Running build...");

    let repo_dir = find_repo_dir()?;
    let build_script = repo_dir.join("target/release/agent-config");

    if !build_script.exists() {
        return Err(anyhow::anyhow!(
            "agent-config binary not found at {}",
            build_script.display()
        ));
    }

    let output = Command::new(&build_script)
        .arg("build")
        .current_dir(&repo_dir)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("build failed: {}", stderr));
    }

    Ok(())
}

fn run_build_script_with_config(repo_dir: &PathBuf, config_root: &PathBuf) -> anyhow::Result<()> {
    let build_script = repo_dir.join("target/release/agent-config");

    if !build_script.exists() {
        return Err(anyhow::anyhow!(
            "agent-config binary not found at {}",
            build_script.display()
        ));
    }

    let output = Command::new(&build_script)
        .arg("build")
        .arg("--config-root")
        .arg(config_root)
        .current_dir(repo_dir)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("build failed: {}", stderr));
    }

    Ok(())
}

fn find_repo_dir() -> anyhow::Result<PathBuf> {
    let home_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?;

    let candidates = vec![
        PathBuf::from("/opt/homebrew/opt/agent-config/libexec"),
        PathBuf::from("/usr/local/opt/agent-config/libexec"),
        home_dir.join("agent-config"),
    ];

    for candidate in candidates {
        if candidate.join("target/release/agent-config").exists() {
            return Ok(candidate);
        }
    }

    Ok(home_dir.join("agent-config"))
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

fn capitalize(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
    }
}