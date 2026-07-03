use anyhow::Context;
use clap::Parser;
use std::fs;
use std::path::{Path, PathBuf};
use tracing::info;

/// Agent Config Sync - Distribute skills to all tool directories
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

fn find_canonical_skills_dir() -> anyhow::Result<PathBuf> {
    // Check .agent-config/skills first (repo directory)
    let repo_skills = PathBuf::from(".agent-config/skills");
    if repo_skills.exists() {
        return Ok(repo_skills);
    }

    // Check ~/.agents/skills (global installation)
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

    // Create tool skills directory if it doesn't exist
    fs::create_dir_all(&skills_dir)
        .context(format!("Failed to create skills directory for {}", tool))?;

    // Copy skills from canonical to tool directory
    let excludes = vec![".git", ".DS_Store", "*.zip", "benchmark-playground"];
    let mut synced_count = 0;

    for entry in fs::read_dir(canonical)? {
        let entry = entry?;
        let entry_path = entry.path();

        // Skip excluded files/directories
        let file_name = entry.file_name();
        let file_name_str = file_name.to_string_lossy();

        if excludes.iter().any(|exclude| {
            // Simple pattern matching
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

        // Remove existing if it's a file, or resolve symlinks
        if dest.exists() {
            if dest.is_file() || dest.is_symlink() {
                fs::remove_file(&dest)?;
            } else {
                // Skip directories to avoid conflicts
                continue;
            }
        }

        // Copy file or directory
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