# This fork

This repository is w-hardy's fork of `posit-dev/skills`. The root `CLAUDE.md` is upstream's and
describes the Posit collection; where it and this file differ, this file is the one that applies
here. [`FORK.md`](../FORK.md) is the full account of what the fork adds and how it stays current.

## What you may edit

The fork authors four categories: `hta/`, `biostatistics/`, `ml-clinical/` and `research-methods/`.
Make skill changes there. Everything else is upstream's or vendored: `superpowers/` and
`tidymodels/` are verbatim copies that a weekly workflow overwrites, and the Posit categories merge
in from upstream every week, so edits to them turn into merge conflicts. FORK.md lists the few
shared files the fork does edit; leave the rest as they are and report upstream problems instead.

Beyond upstream's categories, the fork registers `hta`, `biostatistics`, `ml-clinical`,
`research-methods`, `superpowers` and `tidymodels` as plugins in `.claude-plugin/marketplace.json`.

## Skill descriptions

Keep each `description` under 100 tokens (as `count-skill-tokens.py` counts them); aim for about 80.
Claude Code puts every installed skill's description into Claude's context on every turn, and when
the combined listing gets too long, later skills are listed by name only and stop triggering.
Say what the skill does, the kinds of request it serves, and the nearest sibling skill and what
separates them, rather than listing trigger phrases. Write it as an indented folded block, so no
line starts at column 0 and no apostrophe needs escaping:

```yaml
description: >-
  First sentence of the description,
  continued on an indented line.
```

`.github/scripts/check-skill-frontmatter.py` enforces this for the fork's categories in CI; run it
locally with `uv run .github/scripts/check-skill-frontmatter.py`.

## Skill bodies

Write the body for Claude: state the goal, the constraints and the reasons behind them, and cover
the hard judgment calls. Reserve numbered steps for operations where order matters.

## After changing a fork skill

1. Run the frontmatter check and `bash .github/scripts/validate-skills.sh main` (it validates
   uncommitted work too).
2. Commit.
3. Publish to claude.ai: `./sync-skills.sh package <skill>` writes `dist/<skill>.zip` for upload in
   the claude.ai skill editor. claude.ai copies sync down to `~/.claude/skills/synced/`;
   `./sync-skills.sh check` shows where they differ from the repo.

To try a skill in Claude Code without publishing, copy it to `~/.claude/skills/`.
