# About this fork

This is a fork of [posit-dev/skills](https://github.com/posit-dev/skills) that
also carries personally-authored skills for health technology assessment,
biostatistics, and clinical machine learning. It tracks upstream so the Posit
skills stay current, and is the source of truth for the personal ones.

## What is local to this fork

| Path | Contents |
| --- | --- |
| `hta/` | Health economic evaluation and HTA in R (12 skills) |
| `biostatistics/` | Applied biostatistics for clinical research in R (8 skills) |
| `ml-clinical/` | Machine learning on tabular clinical data in R (4 skills) |
| `sync-skills.sh` | Drift check between this repo and the local claude.ai sync |
| `.github/workflows/sync-upstream.yml` | Weekly upstream merge PR |
| `FORK.md` | This file |

Everything else comes from upstream and is left untouched, so upstream merges
stay clean. The only shared files this fork edits are `README.md` and
`.claude-plugin/marketplace.json`, which is where new skills have to be
registered — expect occasional conflicts in those two and nowhere else.

Anthropic-provided skills that ship with Claude (`docx`, `pdf`, `pptx`, `xlsx`,
`skill-creator`, `morning`) are deliberately not vendored here.

## Staying current with upstream

`.github/workflows/sync-upstream.yml` runs every Monday at 06:00 UTC, and on
demand from the Actions tab. When `posit-dev/skills` has new commits it merges
them into a `sync-upstream` branch and opens a PR; if the merge conflicts it
opens an issue instead.

**GitHub disables scheduled workflows on forks by default.** Enable Actions on
this repository once (Actions tab → *I understand my workflows, go ahead and
enable them*) or the schedule will never fire.

To merge upstream by hand:

```bash
git remote add upstream https://github.com/posit-dev/skills.git   # once
git fetch upstream main
git merge upstream/main
```

## Keeping skills in sync with claude.ai

This repository is the source of truth. Claude syncs skills from claude.ai down
to `~/.claude/skills/synced/`, so the two copies can drift — most often when a
skill is edited in the claude.ai editor rather than here.

```bash
./sync-skills.sh                 # what differs between repo and local sync
./sync-skills.sh diff <skill>    # inspect one skill's differences
./sync-skills.sh pull <skill>    # take the local copy into the repo, then commit
./sync-skills.sh pull --all      # take every differing local copy
```

`pull` moves changes **into** the repo. Going the other way — publishing a
repo-edited skill back to claude.ai — is a manual upload through the claude.ai
skill editor; there is no CLI for it. Do that after committing, so git stays
ahead.

## Adding a skill

1. Create `<category>/<skill-name>/SKILL.md` with `name` and `description`
   frontmatter. Keep the description under 1024 characters — the CI validator
   errors above that.
2. Register it in `.claude-plugin/marketplace.json` under the right plugin.
3. Add it to the matching section of `README.md`.
4. Validate before pushing:

   ```bash
   go install github.com/agent-ecosystem/skill-validator/cmd/skill-validator@latest
   ~/go/bin/skill-validator check -o markdown <category>/<skill-name>/
   ```

   Warnings are advisory — several upstream Posit skills emit them too. Errors
   are not.
