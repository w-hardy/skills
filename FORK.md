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
| `superpowers/` | Vendored from [obra/superpowers](https://github.com/obra/superpowers), MIT (14 skills) |
| `tidymodels/` | Vendored from [tidymodels/skills](https://github.com/tidymodels/skills), MIT (1 skill) |
| `.claude/settings.json` | Registers this fork's marketplace and enables every plugin for sessions opened in this repo |
| `sync-skills.sh` | Drift check between this repo and the local claude.ai sync |
| `.github/workflows/sync-upstream.yml` | Weekly upstream merge PR |
| `FORK.md` | This file |

Everything else comes from upstream and is left untouched, so upstream merges
stay clean. The only shared files this fork edits are `README.md` and
`.claude-plugin/marketplace.json`, which is where new skills have to be
registered — expect occasional conflicts in those two and nowhere else.

Anthropic-provided skills that ship with Claude (`docx`, `pdf`, `pptx`, `xlsx`,
`skill-creator`, `morning`) are deliberately not vendored here.

`superpowers/` is third-party code, not personally authored: it is a verbatim
copy of the `skills/` tree from [obra/superpowers](https://github.com/obra/superpowers)
at a pinned commit, under its own MIT licence. Do not edit those skills in place —
fixes go upstream, and refreshes are a clean overwrite. See
[`superpowers/README.md`](./superpowers/README.md) for the pinned version, what is
deliberately left out (notably the session-start hook), and the refresh procedure.
It is excluded from `sync-skills.sh`, which only tracks the personally-authored
categories.

`tidymodels/` is vendored the same way: a verbatim copy of the `users/tabular-data-ml`
skill from [tidymodels/skills](https://github.com/tidymodels/skills) at a pinned commit.
Its `LICENSE` is locally authored, not upstream's, because upstream's README claims MIT
but ships no LICENSE file at the pinned commit. See
[`tidymodels/README.md`](./tidymodels/README.md) for the pinned commit and the manual
refresh recipe.

## Marketplace identity

The manifest in `.claude-plugin/marketplace.json` declares `"name": "w-hardy-skills"`.
Upstream's manifest carries Posit's own marketplace name; this fork renames it because
Claude Code resolves plugin ids (`hta@w-hardy-skills`) against the manifest's own `name`, not
against the key a consumer writes in `extraKnownMarketplaces`. A consumer that registers
this fork under `w-hardy-skills` while the manifest still carries the upstream name fails
silently: no plugin resolves and the session falls back to user-scope installs. The
rename also stops the fork colliding with the real posit-dev/skills marketplace when
both are registered. Everything else in the manifest — `owner`, `metadata.description`
— identifies the fork and the families it adds; the `plugins` list is upstream's plus
the local categories.

Consumers register it like this (this repo's own `.claude/settings.json` is the
reference copy, and enables every plugin so a session here sees the whole collection):

```json
{
  "extraKnownMarketplaces": {
    "w-hardy-skills": { "source": { "source": "github", "repo": "w-hardy/skills" } }
  },
  "enabledPlugins": { "hta@w-hardy-skills": true }
}
```

Renaming the marketplace again breaks every consumer at once, so any future change to
`name` has to land in each consumer's `.claude/settings.json` first.

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
