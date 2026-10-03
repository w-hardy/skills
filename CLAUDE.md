# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

A fork of Posit PBC's Claude Skills collection (`posit-dev/skills`) that adds health technology assessment, biostatistics, clinical machine learning, research-methods and vendored third-party skills. Skills are structured markdown files that teach Claude specialized workflows (e.g., Shiny app development, R package testing, GitHub PR workflows). There is no application code to build, compile, or deploy — the primary artifacts are Markdown files consumed directly by Claude's skill system.

## Utility Script

Two utility scripts live at the repository root. `count-skill-tokens.py` reports line and token counts for a skill:

```bash
# Requires uv
./count-skill-tokens.py shiny/shiny-bslib
# or
uv run count-skill-tokens.py r-lib/cli
```

Warns when `SKILL.md` exceeds **5,000 tokens / 500 lines**, or when the skill `description` frontmatter exceeds **100 tokens**.

`sync-skills.sh` compares the `hta/`, `biostatistics/` and `ml-clinical/` skills against the copies synced locally from claude.ai (`~/.claude/skills/synced`); see its header for usage.

## Directory Structure

```
<category>/
  README.md                   # Category-level notes (optional per skill)
  <skill-name>/
    SKILL.md                  # Required: skill definition with YAML frontmatter
    references/               # Optional: supplementary docs loaded on demand
      *.md
    scripts/                  # Optional: R or shell helpers
    templates/                # Optional: document templates
```

Do **not** create a `README.md` inside individual skill directories — documentation about a skill's design goes in the category README.

## SKILL.md Format

Every skill requires YAML frontmatter at minimum:

```yaml
---
name: your-skill-name        # kebab-case, matches directory name
description: >               # Claude reads this to decide when to activate the skill
  Clear description of what this skill does and when to trigger it.
  Keep under 100 tokens.
---
```

The body is instructions written **for Claude**, not end users: state the goal, the constraints and the reasons behind them, and cover the hard judgment calls. Reserve numbered steps for operations where order matters.

## Registering a New Skill

After creating the skill directory, add it to the appropriate plugin in `.claude-plugin/marketplace.json`:

```json
{
  "name": "open-source",
  "skills": [
    "./open-source/release-post",
    "./open-source/your-new-skill"   ← add here
  ]
}
```

If a skill spans multiple categories (like `brand-yml` for both Shiny and Quarto), add its path to multiple plugin `skills` arrays. The `source` field is always `"./"` (repo root).

When adding a new plugin to `marketplace.json`, also update the root `README.md` "Method 2: Direct Installation" section so it lists the `/plugin install` command for every plugin. All plugins in `marketplace.json` must have a corresponding install line in the README.

## Skill Categories

| Category | Purpose |
|----------|---------|
| `posit-dev/` | General developer skills (code review, architecture docs) |
| `github/` | PR creation and review thread workflows |
| `open-source/` | R/Python package release and changelog workflows |
| `r-lib/` | R package development with the r-lib ecosystem |
| `shiny/` | Shiny app development |
| `quarto/` | Quarto document authoring |
| `connect/` | Deploying and managing content on Posit Connect |
| `brand-yml/` | Shared skill registered under both `shiny` and `quarto` plugins |
| `alt-text/` | Shared skill registered under both `r-lib` and `quarto` plugins |
| `ggsql/` | Writing ggsql queries (a grammar of graphics for SQL) |
| `hta/` | Health technology assessment and health economic evaluation in R |
| `biostatistics/` | Applied biostatistics for clinical research in R |
| `ml-clinical/` | Machine learning on tabular clinical data in R |
| `research-methods/` | General research methodology and manuscript craft |
| `superpowers/` | Vendored from `obra/superpowers` (development methodology for coding agents) |
| `tidymodels/` | Vendored from `tidymodels/skills` (tidymodels tabular ML) |

## Key Conventions

- **Progressive disclosure**: Put specialized or large reference content in `references/*.md` and instruct Claude to read those files only when needed. This keeps the main `SKILL.md` within token limits.
- **R scripts**: Use a shebang (`#!/usr/bin/env Rscript`), include inline usage docs, check for required packages at startup, and exit non-zero on error.
- **Testing**: Install locally via `cp -r <category>/<skill> ~/.claude/skills/` and verify Claude activates the skill in Claude Code.
