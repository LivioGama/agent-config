use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Configuration for the agent-config system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// Root directory for canonical configurations
    pub config_root: PathBuf,
    /// Repository directory
    pub repo_dir: PathBuf,
    /// Environment variables
    pub env: Environment,
}

/// Environment configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Environment {
    /// AGENT_CONFIG_ROOT override
    pub agent_config_root: Option<String>,
    /// AGENT_CONFIG_REPO_DIR override
    pub agent_config_repo_dir: Option<String>,
    /// PATH environment variable
    pub path: String,
}

impl Config {
    /// Create a new configuration from environment
    pub fn from_env() -> Result<Self, super::error::AgentConfigError> {
        let env = Environment {
            agent_config_root: std::env::var("AGENT_CONFIG_ROOT").ok(),
            agent_config_repo_dir: std::env::var("AGENT_CONFIG_REPO_DIR").ok(),
            path: std::env::var("PATH").unwrap_or_else(|_| String::from("/usr/bin:/bin")),
        };

        let repo_dir = if let Some(override_dir) = &env.agent_config_repo_dir {
            PathBuf::from(override_dir)
        } else {
            Self::find_repo_dir()?
        };

        let config_root = if let Some(override_root) = &env.agent_config_root {
            PathBuf::from(override_root)
        } else {
            dirs::home_dir()
                .map(|h| h.join(".agent-config"))
                .ok_or_else(|| super::error::AgentConfigError::InvalidConfig("Cannot determine home directory".to_string()))?
        };

        Ok(Config {
            config_root,
            repo_dir,
            env,
        })
    }

    /// Find the repository directory by checking candidate locations
    fn find_repo_dir() -> Result<PathBuf, super::error::AgentConfigError> {
        let home_dir = dirs::home_dir()
            .ok_or_else(|| super::error::AgentConfigError::InvalidConfig("Cannot determine home directory".to_string()))?;

        let candidates = vec![
            PathBuf::from("/opt/homebrew/opt/agent-config/libexec"),
            PathBuf::from("/usr/local/opt/agent-config/libexec"),
            home_dir.join("agent-config"),
        ];

        for candidate in candidates {
            let build_script = candidate.join("build.sh");
            if build_script.exists() {
                return Ok(candidate);
            }
        }

        Ok(home_dir.join("agent-config"))
    }

    /// Get the rules directory
    pub fn rules_dir(&self) -> PathBuf {
        self.config_root.join("rules")
    }

    /// Get the skills directory
    pub fn skills_dir(&self) -> PathBuf {
        self.config_root.join("skills")
    }

    /// Get the build script path
    pub fn build_script(&self) -> PathBuf {
        self.repo_dir.join("build.sh")
    }
}

/// Tool target for configuration generation
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ToolTarget {
    Amp,
    Copilot,
    CopilotCli,
    Cursor,
    ClaudeCode,
    CodexCli,
    Goose,
    HermesAgent,
    GrokCli,
    Cline,
    Kilo,
    Roo,
    RovoDev,
    Takt,
    Vibe,
    QwenCode,
    Reasonix,
    KiroCli,
    KiroIde,
    AntigravityCli,
    AntigravityIde,
    AugmentCode,
    Junie,
    Devin,
    Gemini,
    Warp,
    Replit,
    Pi,
    Zed,
    DeepAgents,
    FactoryDroid,
    OpenCode,
}

impl ToolTarget {
    /// Get the home directory name for this tool
    pub fn home_dir_name(&self) -> &str {
        match self {
            ToolTarget::CodexCli => ".codex",
            ToolTarget::ClaudeCode => ".claude",
            ToolTarget::Cursor => ".cursor",
            ToolTarget::Devin => ".devin",
            ToolTarget::Gemini => ".gemini",
            _ => panic!("Tool target home dir not implemented: {:?}", self),
        }
    }
}