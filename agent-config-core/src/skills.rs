use crate::error::{AgentConfigError, Result};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// Represents a skill with frontmatter and content
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Skill {
    /// Frontmatter metadata
    pub frontmatter: SkillFrontmatter,
    /// Prompt content (without frontmatter)
    pub content: String,
    /// Skill name (directory name)
    pub name: String,
    /// Source directory path
    pub source_path: String,
}

/// Frontmatter for a skill
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillFrontmatter {
    /// Skill name
    pub name: String,
    /// Skill description
    pub description: String,
    /// Argument hint
    #[serde(default)]
    pub argument_hint: Option<String>,
    /// Model override
    #[serde(default)]
    pub model: Option<String>,
    /// Run as subagent
    #[serde(default)]
    pub subagent: bool,
    /// Custom subagent profile
    #[serde(default)]
    pub agent: Option<String>,
    /// Allowed tools
    #[serde(default)]
    pub allowed_tools: Vec<String>,
    /// Triggers
    #[serde(default)]
    pub triggers: Vec<String>,
}

impl Skill {
    /// Parse a skill from a SKILL.md file
    pub fn from_file<P: AsRef<Path>>(path: P, name: String) -> Result<Self> {
        let path = path.as_ref();
        let content = fs::read_to_string(path)
            .map_err(|_e| AgentConfigError::FileNotFound(path.display().to_string()))?;

        Self::parse(&content, name, path.display().to_string())
    }

    /// Parse skill content from a string
    pub fn parse(content: &str, name: String, source_path: String) -> Result<Self> {
        let (frontmatter, body) = Self::split_frontmatter(content)?;

        let frontmatter: SkillFrontmatter = serde_yaml::from_str(frontmatter)
            .map_err(|e| AgentConfigError::InvalidFrontmatter(format!("YAML error: {}", e)))?;

        Ok(Skill {
            frontmatter,
            content: body.to_string(),
            name,
            source_path,
        })
    }

    /// Split YAML frontmatter from markdown content
    fn split_frontmatter(content: &str) -> Result<(&str, &str)> {
        if !content.starts_with("---") {
            return Err(AgentConfigError::InvalidFrontmatter(
                "Skill must have YAML frontmatter".to_string(),
            ));
        }

        let parts: Vec<&str> = content.splitn(3, "---").collect();
        if parts.len() < 3 {
            return Err(AgentConfigError::InvalidFrontmatter(
                "Invalid frontmatter format".to_string(),
            ));
        }

        Ok((parts[1].trim(), parts[2].trim()))
    }

    /// Validate the skill
    pub fn validate(&self) -> Result<()> {
        // Validate skill name (safe slug)
        let safe_slug_regex = Regex::new(r"^[A-Za-z0-9][A-Za-z0-9._-]*$").unwrap();
        if !safe_slug_regex.is_match(&self.name) {
            return Err(AgentConfigError::SkillValidation(
                "Invalid skill name: must be a safe slug".to_string(),
            ));
        }

        // Validate required fields
        if self.frontmatter.name.is_empty() {
            return Err(AgentConfigError::SkillValidation(
                "Skill name is required".to_string(),
            ));
        }

        if self.frontmatter.description.is_empty() {
            return Err(AgentConfigError::SkillValidation(
                "Skill description is required".to_string(),
            ));
        }

        Ok(())
    }
}

/// Skill collection
#[derive(Debug, Clone)]
pub struct SkillCollection {
    skills: Vec<Skill>,
}

impl SkillCollection {
    /// Create an empty skill collection
    pub fn new() -> Self {
        SkillCollection { skills: Vec::new() }
    }

    /// Add a skill to the collection
    pub fn add(&mut self, skill: Skill) {
        self.skills.push(skill);
    }

    /// Load all skills from a directory
    pub fn load_from_dir<P: AsRef<Path>>(dir: P) -> Result<Self> {
        let dir = dir.as_ref();
        if !dir.exists() {
            return Err(AgentConfigError::FileNotFound(dir.display().to_string()));
        }

        let mut collection = Self::new();

        for entry in fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let skill_name = path
                    .file_name()
                    .and_then(|s| s.to_str())
                    .ok_or_else(|| {
                        AgentConfigError::SkillValidation(
                            "Invalid skill directory name".to_string(),
                        )
                    })?
                    .to_string();

                let skill_file = path.join("SKILL.md");
                if skill_file.exists() {
                    match Skill::from_file(&skill_file, skill_name) {
                        Ok(skill) => collection.add(skill),
                        Err(_e) => {
                            eprintln!("Warning: Failed to load skill {:?}", path);
                        }
                    }
                }
            }
        }

        Ok(collection)
    }

    /// Get all skills
    pub fn skills(&self) -> &[Skill] {
        &self.skills
    }

    /// Find a skill by name
    pub fn find_by_name(&self, name: &str) -> Option<&Skill> {
        self.skills.iter().find(|s| s.name == name)
    }
}

impl Default for SkillCollection {
    fn default() -> Self {
        Self::new()
    }
}

/// Validate a skill name (safe slug)
pub fn is_safe_skill_name(name: &str) -> bool {
    let safe_slug_regex = Regex::new(r"^[A-Za-z0-9][A-Za-z0-9._-]*$").unwrap();
    safe_slug_regex.is_match(name)
}

/// Validate a rule filename (safe .md basename)
pub fn is_safe_rule_filename(name: &str) -> bool {
    let safe_filename_regex = Regex::new(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.md$").unwrap();
    safe_filename_regex.is_match(name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_skill() {
        let content = r#"---
name: test-skill
description: "A test skill"
---
This is the skill content"#;

        let skill = Skill::parse(content, "test-skill".to_string(), "/path/to/skill".to_string()).unwrap();
        assert_eq!(skill.frontmatter.name, "test-skill");
        assert_eq!(skill.frontmatter.description, "A test skill");
        assert_eq!(skill.content, "This is the skill content");
    }

    #[test]
    fn test_safe_skill_name() {
        assert!(is_safe_skill_name("test-skill"));
        assert!(is_safe_skill_name("test_skill"));
        assert!(is_safe_skill_name("test.skill"));
        assert!(!is_safe_skill_name("-invalid"));
        assert!(!is_safe_skill_name("invalid name"));
    }

    #[test]
    fn test_safe_rule_filename() {
        assert!(is_safe_rule_filename("test-rule.md"));
        assert!(is_safe_rule_filename("10-rule.md"));
        assert!(!is_safe_rule_filename("invalid"));
        assert!(!is_safe_rule_filename("invalid.txt"));
    }
}