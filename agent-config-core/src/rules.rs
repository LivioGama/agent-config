use crate::error::{AgentConfigError, Result};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// Represents a single rule with frontmatter and content
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rule {
    /// Frontmatter metadata
    pub frontmatter: RuleFrontmatter,
    /// Markdown content (without frontmatter)
    pub content: String,
    /// Source file path
    pub source_path: String,
}

/// Frontmatter for a rule
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleFrontmatter {
    /// Whether this is a root rule
    #[serde(default)]
    pub root: bool,
    /// Target tools (empty means all)
    #[serde(default)]
    pub targets: Vec<String>,
    /// Rule description
    pub description: Option<String>,
    /// File glob patterns
    #[serde(default)]
    pub globs: Vec<String>,
    /// Trigger condition
    #[serde(default)]
    pub trigger: Option<String>,
    /// Rule ID
    #[serde(default)]
    pub id: Option<String>,
    /// Rule title
    #[serde(default)]
    pub title: Option<String>,
}

impl Default for RuleFrontmatter {
    fn default() -> Self {
        RuleFrontmatter {
            root: false,
            targets: Vec::new(),
            description: None,
            globs: Vec::new(),
            trigger: None,
            id: None,
            title: None,
        }
    }
}

impl Rule {
    /// Parse a rule from a markdown file
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self> {
        let path = path.as_ref();
        let content = fs::read_to_string(path)
            .map_err(|_e| AgentConfigError::FileNotFound(path.display().to_string()))?;

        Self::parse(&content, path.display().to_string())
    }

    /// Parse rule content from a string
    pub fn parse(content: &str, source_path: String) -> Result<Self> {
        let (frontmatter, body) = Self::split_frontmatter(content)?;

        let frontmatter: RuleFrontmatter = if frontmatter.is_empty() {
            RuleFrontmatter::default()
        } else {
            serde_yaml::from_str(frontmatter)
                .map_err(|e| AgentConfigError::InvalidFrontmatter(format!("YAML error: {}", e)))?
        };

        Ok(Rule {
            frontmatter,
            content: body.to_string(),
            source_path,
        })
    }

    /// Split YAML frontmatter from markdown content
    fn split_frontmatter(content: &str) -> Result<(&str, &str)> {
        if !content.starts_with("---") {
            return Ok(("", content));
        }

        let parts: Vec<&str> = content.splitn(3, "---").collect();
        if parts.len() < 3 {
            return Err(AgentConfigError::InvalidFrontmatter(
                "Invalid frontmatter format".to_string(),
            ));
        }

        Ok((parts[1].trim(), parts[2].trim()))
    }

    /// Validate the rule
    pub fn validate(&self) -> Result<()> {
        // Check for required fields based on rule type
        if self.frontmatter.root && self.frontmatter.targets.is_empty() {
            // Root rules typically target all tools
        }

        // Validate globs if present
        for glob in &self.frontmatter.globs {
            if glob.is_empty() {
                return Err(AgentConfigError::RuleValidation(
                    "Empty glob pattern".to_string(),
                ));
            }
        }

        Ok(())
    }
}

/// Rule collection with sorting and filtering
#[derive(Debug, Clone)]
pub struct RuleCollection {
    rules: Vec<Rule>,
}

impl RuleCollection {
    /// Create an empty rule collection
    pub fn new() -> Self {
        RuleCollection { rules: Vec::new() }
    }

    /// Add a rule to the collection
    pub fn add(&mut self, rule: Rule) {
        self.rules.push(rule);
    }

    /// Load all rules from a directory
    pub fn load_from_dir<P: AsRef<Path>>(dir: P) -> Result<Self> {
        let dir = dir.as_ref();
        if !dir.exists() {
            return Err(AgentConfigError::FileNotFound(dir.display().to_string()));
        }

        let mut collection = Self::new();

        for entry in fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("md") {
                match Rule::from_file(&path) {
                    Ok(rule) => collection.add(rule),
                    Err(_e) => {
                        eprintln!("Warning: Failed to load rule {:?}", path);
                    }
                }
            }
        }

        Ok(collection)
    }

    /// Sort rules by filename (numeric prefix)
    pub fn sort(&mut self) {
        self.rules.sort_by(|a, b| {
            let a_name = Self::extract_numeric_prefix(&a.source_path);
            let b_name = Self::extract_numeric_prefix(&b.source_path);
            a_name.cmp(&b_name)
        });
    }

    /// Extract numeric prefix from filename for sorting
    fn extract_numeric_prefix(path: &str) -> String {
        let filename = Path::new(path)
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("");

        // Extract leading numbers
        let re = Regex::new(r"^(\d+)").unwrap();
        if let Some(caps) = re.captures(filename) {
            caps.get(1).map(|m| m.as_str().to_string()).unwrap_or_default()
        } else {
            filename.to_string()
        }
    }

    /// Filter rules by target
    pub fn filter_by_target(&self, target: &str) -> Vec<&Rule> {
        self.rules
            .iter()
            .filter(|rule| {
                rule.frontmatter.targets.is_empty()
                    || rule.frontmatter.targets.iter().any(|t| t == "*" || t == target)
            })
            .collect()
    }

    /// Concatenate all rule contents into a single string
    pub fn concatenate(&self) -> String {
        self.rules
            .iter()
            .map(|rule| {
                format!(
                    "# {}\n\n{}",
                    rule.frontmatter
                        .title
                        .as_ref()
                        .or(rule.frontmatter.description.as_ref())
                        .or(rule.frontmatter.id.as_ref())
                        .unwrap_or(&"Rule".to_string()),
                    rule.content
                )
            })
            .collect::<Vec<_>>()
            .join("\n\n---\n\n")
    }

    /// Get all rules
    pub fn rules(&self) -> &[Rule] {
        &self.rules
    }
}

impl Default for RuleCollection {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_rule_with_frontmatter() {
        let content = r#"---
root: true
targets: ["*"]
description: "Test rule"
---
This is the content"#;

        let rule = Rule::parse(content, "test.md".to_string()).unwrap();
        assert!(rule.frontmatter.root);
        assert_eq!(rule.frontmatter.targets, vec!["*"]);
        assert_eq!(rule.frontmatter.description, Some("Test rule".to_string()));
        assert_eq!(rule.content, "This is the content");
    }

    #[test]
    fn test_parse_rule_without_frontmatter() {
        let content = "This is content without frontmatter";
        let rule = Rule::parse(content, "test.md".to_string()).unwrap();
        assert!(!rule.frontmatter.root);
        assert_eq!(rule.content, "This is content without frontmatter");
    }
}