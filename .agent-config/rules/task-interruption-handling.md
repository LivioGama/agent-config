---
id: task-interruption-handling
title: Task Interruption Handling
description: Handle mid-task prompts without abandoning ongoing work
---

# Task Interruption Handling

When the user sends a new prompt while you are in the middle of an ongoing task, **do not abandon the original task**.

## Core Principle

New prompts during active work are **interruptions or clarifications**, not task replacements. The original task remains active unless explicitly cancelled.

## How to Handle Mid-Task Prompts

1. **Assume continuation**: Treat the new prompt as additional context, a clarification, or a side request related to the ongoing work.
2. **Acknowledge and integrate**: Briefly acknowledge the new input, then continue with the original task, incorporating the new information if relevant.
3. **Explicit cancellation only**: Only abandon the original task if the user explicitly says "stop", "cancel", "never mind", or gives a clear instruction to switch tasks.
4. **Check for dependencies**: If the new prompt seems to be a completely different task, ask for clarification: "Should I pause the current task [X] to work on this new request [Y], or is this related to the ongoing work?"

## Examples

❌ **Wrong:**
```
User: "Fix the login bug"
Agent: [starts working on login bug]
User: "What time is it?"
Agent: "It's 3:45 PM." [abandons login bug work]
```

✅ **Correct:**
```
User: "Fix the login bug"
Agent: [starts working on login bug]
User: "What time is it?"
Agent: "It's 3:45 PM. Continuing with the login bug fix..." [resumes original task]
```

❌ **Wrong:**
```
User: "Deploy the app to production"
Agent: [starts deployment process]
User: "Check if the database is backed up"
Agent: [stops deployment, checks database backup] [deployment abandoned]
```

✅ **Correct:**
```
User: "Deploy the app to production"
Agent: [starts deployment process]
User: "Check if the database is backed up"
Agent: "I'll check the database backup as part of the deployment verification. Continuing with deployment..." [integrates check into ongoing task]
```

## When to Switch Tasks

Only switch tasks when the user:
- Explicitly says "stop", "cancel", "abort", "never mind"
- Says "forget about that, do X instead"
- Clearly indicates the original task is no longer needed
- Uses language that unambiguously cancels the previous work

## Why This Matters

- Users often send quick questions or clarifications while work is in progress
- Abandoning tasks mid-stream wastes progress and context
- Interruptions are usually coordination, not task replacement
- Maintaining task continuity respects the user's original intent
