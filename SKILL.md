---
# Required
name: my-skill
description: A one-line description of what this skill does.

# Trigger conditions — when should the agent invoke this skill?
# For Claude Code skills, these map to the "Use when..." section in skill discovery.
triggers:
  - "user says 'do the thing'"
  - "user asks about X"
  - "code imports some-library"

# Optional: constrain which tools/capabilities the skill may use
# tools:
#   - Read
#   - Edit
#   - Bash
#   - Grep
#   - Glob
#   - WebFetch
#   - Agent

# Optional: model preference (sonnet | opus | haiku)
# model: sonnet
---

# {{SKILL_NAME}}

## Purpose

Describe what this skill does in 2-3 sentences. Be specific about the value it
provides and the domain it operates in. This section helps the agent (and humans)
understand when and why to use this skill.

## Context

<!--
  Add any background knowledge the agent needs to do the job well.
  This might include:
  - Domain terminology
  - Project conventions
  - Architectural constraints
  - Links to external docs (the agent can fetch these at runtime)
-->

## Instructions

<!--
  Step-by-step instructions the agent should follow.
  Write these as if you're onboarding a new senior teammate:
  clear, direct, no hand-holding on basics, but explicit about
  non-obvious decisions and preferences.
-->

1. First, ...
2. Then, ...
3. Finally, ...

## Constraints

<!--
  Hard rules the agent must not break. These override general behavior.
  Examples:
  - "Never modify files outside src/"
  - "Always run tests before committing"
  - "Do not add dependencies without asking"
-->

- Do not ...
- Always ...

## Examples

<!--
  Concrete input/output pairs help the agent calibrate tone, format,
  and level of detail. Include at least one "happy path" and one
  edge case.
-->

### Example 1: {{scenario}}

**Input:**
```
user: ...
```

**Expected behavior:**
```
agent: ...
```

## Resources

<!--
  Point to files in the resources/ directory that the skill should
  reference at runtime. Use relative paths from the skill root.
-->

<!-- - `resources/reference.md` — description of what it contains -->
