//! Agent Config Core Library
//!
//! This library provides the core functionality for the agent-config system,
//! including rule parsing, skill management, and configuration handling.

pub mod config;
pub mod error;
pub mod rules;
pub mod skills;

pub use config::{Config, Environment, ToolTarget};
pub use error::{AgentConfigError, Result};
pub use rules::{Rule, RuleCollection, RuleFrontmatter};
pub use skills::{is_safe_rule_filename, is_safe_skill_name, Skill, SkillCollection, SkillFrontmatter};