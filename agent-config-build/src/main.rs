use agent_config_core::{Config, RuleCollection};
use anyhow::Context;
use clap::Parser;
use std::process::Command;
use tracing::{info, error};

/// Agent Config Build - Generate tool configurations from canonical rules
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Override configuration root directory
    #[arg(long, env = "AGENT_CONFIG_ROOT")]
    config_root: Option<String>,

    /// Override repository directory
    #[arg(long, env = "AGENT_CONFIG_REPO_DIR")]
    repo_dir: Option<String>,

    /// Verbose output
    #[arg(short, long)]
    verbose: bool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    let args = Args::parse();

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

    // Run the build process
    run_build(&config).await?;

    Ok(())
}

async fn run_build(config: &Config) -> anyhow::Result<()> {
    info!("Starting build process");

    // Step 1: Ensure configuration directories exist
    ensure_directories(config)?;

    // Step 2: Load rules
    info!("Loading rules from {}", config.rules_dir().display());
    let mut rules = RuleCollection::load_from_dir(&config.rules_dir())
        .context("Failed to load rules")?;

    info!("Loaded {} rules", rules.rules().len());

    // Step 3: Validate and sort rules
    for rule in rules.rules() {
        rule.validate()?;
    }
    rules.sort();

    // Step 4: Generate AGENTS.md
    info!("Generating AGENTS.md");
    let agents_content = rules.concatenate();
    let agents_path = config.config_root.join("AGENTS.md");
    std::fs::write(&agents_path, agents_content)
        .context("Failed to write AGENTS.md")?;

    info!("Generated AGENTS.md at {}", agents_path.display());

    // Step 5: Run rulesync if available
    if let Ok(_) = which::which("rulesync") {
        info!("Running rulesync");
        run_rulesync(config)?;
    } else {
        info!("rulesync not found in PATH, skipping");
    }

    // Step 6: Deploy to tool directories
    info!("Deploying to tool directories");
    deploy_to_tools(config)?;

    info!("Build completed successfully");

    Ok(())
}

fn ensure_directories(config: &Config) -> anyhow::Result<()> {
    std::fs::create_dir_all(&config.config_root)
        .context("Failed to create config root")?;
    std::fs::create_dir_all(config.rules_dir())
        .context("Failed to create rules directory")?;
    std::fs::create_dir_all(config.skills_dir())
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
    // Deploy to Claude
    let claude_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?
        .join(".claude");

    if claude_dir.exists() {
        let agents_md = config.config_root.join("AGENTS.md");
        let claude_agents = claude_dir.join("CLAUDE.md");
        let claude_agents_md = claude_dir.join("AGENTS.md");

        std::fs::copy(&agents_md, &claude_agents)
            .context("Failed to copy to CLAUDE.md")?;
        std::fs::copy(&agents_md, &claude_agents_md)
            .context("Failed to copy to AGENTS.md")?;

        info!("Deployed to ~/.claude/");
    }

    // Deploy to Codex (simplified - full implementation would include browser policy injection)
    let codex_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?
        .join(".codex");

    if codex_dir.exists() {
        let agents_md = config.config_root.join("AGENTS.md");
        let codex_agents = codex_dir.join("AGENTS.md");

        std::fs::copy(&agents_md, &codex_agents)
            .context("Failed to copy to Codex AGENTS.md")?;

        info!("Deployed to ~/.codex/");
    }

    // Deploy to Devin
    let devin_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?
        .join(".devin");

    if devin_dir.exists() {
        let devin_rules = devin_dir.join("rules");
        if devin_rules.exists() {
            // Copy rule files to Devin
            for entry in std::fs::read_dir(&config.rules_dir())? {
                let entry = entry?;
                if entry.path().extension().and_then(|s| s.to_str()) == Some("md") {
                    let dest = devin_rules.join(entry.file_name());
                    std::fs::copy(entry.path(), &dest)?;
                }
            }
            info!("Deployed to ~/.devin/rules/");
        }
    }

    Ok(())
}