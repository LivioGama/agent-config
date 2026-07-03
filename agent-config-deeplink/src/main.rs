use agent_config_core::{is_safe_rule_filename, is_safe_skill_name};
use clap::Parser;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use tracing::info;
use percent_encoding::percent_decode_str;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    let args = Args::parse();

    if args.deeplink.is_empty() {
        return Err(anyhow::anyhow!("Deeplink URL is required"));
    }

    process_deeplink(&args.deeplink).await?;

    Ok(())
}

/// Agent Config Deeplink - Process agent-config:// URLs
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Deeplink URL to process
    #[arg(name = "DEEPLINK")]
    deeplink: String,
}

async fn process_deeplink(deeplink: &str) -> anyhow::Result<()> {
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

fn capitalize(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
    }
}

fn determine_destination(url: &str) -> anyhow::Result<(String, PathBuf)> {
    let home_dir = dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Cannot determine home directory"))?;
    let config_root = home_dir.join(".agent-config");

    // Parse URL path to determine installation kind
    let url_path = url
        .split('/')
        .skip(3) // Skip https:// and domain
        .collect::<Vec<&str>>()
        .join("/");

    // Check for skill pattern: .../skills/<skill-name>/SKILL.md
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

    // Check for agent config pattern: .../.agent-config/AGENTS.md
    if url_path.contains(".agent-config/AGENTS.md") {
        let dest = config_root.join("AGENTS.md");
        return Ok(("agent config".to_string(), dest));
    }

    // Default to rule
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

    // Create parent directory
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent)?;
    }

    // Download file
    let response = reqwest::get(url).await?;
    if !response.status().is_success() {
        return Err(anyhow::anyhow!(
            "Download failed with status: {}",
            response.status()
        ));
    }

    let content = response.bytes().await?;

    // Validate file is not empty
    if content.is_empty() {
        return Err(anyhow::anyhow!("Downloaded file is empty"));
    }

    // Write to destination
    fs::write(dest, content)?;

    info!("Saved to {}", dest.display());

    Ok(())
}

fn run_build_script() -> anyhow::Result<()> {
    info!("Running build.sh...");

    // Find build script
    let repo_dir = find_repo_dir()?;
    let build_script = repo_dir.join("build.sh");

    if !build_script.exists() {
        return Err(anyhow::anyhow!(
            "build.sh not found at {}",
            build_script.display()
        ));
    }

    // Execute build script
    let output = Command::new(&build_script)
        .current_dir(&repo_dir)
        .env("AGENT_CONFIG_ROOT", dirs::home_dir().unwrap().join(".agent-config"))
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("build.sh failed: {}", stderr));
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
        if candidate.join("build.sh").exists() {
            return Ok(candidate);
        }
    }

    Ok(home_dir.join("agent-config"))
}