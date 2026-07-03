use thiserror::Error;

/// Result type alias for convenience
pub type Result<T> = std::result::Result<T, AgentConfigError>;

/// Main error type for agent-config operations
#[derive(Error, Debug)]
pub enum AgentConfigError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("YAML parsing error: {0}")]
    Yaml(#[from] serde_yaml::Error),

    #[error("Process execution error: {0}")]
    Process(String),

    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),

    #[error("Rule validation error: {0}")]
    RuleValidation(String),

    #[error("Skill validation error: {0}")]
    SkillValidation(String),

    #[error("URL parsing error: {0}")]
    UrlParse(String),

    #[error("Download failed: {0}")]
    DownloadFailed(String),

    #[error("File not found: {0}")]
    FileNotFound(String),

    #[error("Permission denied: {0}")]
    PermissionDenied(String),

    #[error("Invalid frontmatter: {0}")]
    InvalidFrontmatter(String),

    #[error("Build script not found: {0}")]
    BuildScriptNotFound(String),

    #[error("Rulesync not found in PATH")]
    RulesyncNotFound,

    #[error("Unsupported platform: {0}")]
    UnsupportedPlatform(String),
}