#!/usr/bin/env bash
# Compare the skills in this repository against the copies Claude has synced
# locally from claude.ai, and pull local edits back into the repository.
#
# This repository is the source of truth. Skills edited here are published to
# claude.ai by uploading them there; skills edited in the claude.ai editor land
# in the local sync directory and need pulling back in with `pull` so git does
# not fall behind.
#
# Usage:
#   ./sync-skills.sh              # report drift (default)
#   ./sync-skills.sh check        # same as above
#   ./sync-skills.sh diff <skill> # show what differs for one skill
#   ./sync-skills.sh pull <skill> # copy the local copy over the repo copy
#   ./sync-skills.sh pull --all   # copy every differing local copy into the repo
#
# Environment:
#   SKILLS_SYNC_DIR   local sync directory (default ~/.claude/skills/synced)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SKILLS_SYNC_DIR:-$HOME/.claude/skills/synced}"

# Categories in this repo that hold personally-authored skills. Posit's own
# categories are deliberately excluded: they are maintained upstream.
CATEGORIES=(hta biostatistics ml-clinical)

if [ ! -d "$SYNC_DIR" ]; then
  echo "Local sync directory not found: $SYNC_DIR" >&2
  echo "Set SKILLS_SYNC_DIR to point at it." >&2
  exit 1
fi

# Print the repo path for a skill name, or nothing if it is not in the repo.
repo_path_for() {
  local name=$1 cat
  for cat in "${CATEGORIES[@]}"; do
    if [ -d "$REPO_ROOT/$cat/$name" ]; then
      echo "$REPO_ROOT/$cat/$name"
      return 0
    fi
  done
  return 1
}

# Every skill name tracked in this repo, across all categories.
repo_skills() {
  local cat d
  for cat in "${CATEGORIES[@]}"; do
    [ -d "$REPO_ROOT/$cat" ] || continue
    for d in "$REPO_ROOT/$cat"/*/; do
      [ -f "${d}SKILL.md" ] && basename "$d"
    done
  done | sort
}

cmd_check() {
  local same=0 differ=0 missing_local=0 untracked=0
  local name repo

  while read -r name; do
    repo=$(repo_path_for "$name")
    if [ ! -d "$SYNC_DIR/$name" ]; then
      printf '  %-40s not synced locally\n' "$name"
      missing_local=$((missing_local + 1))
    elif diff -rq "$repo" "$SYNC_DIR/$name" >/dev/null 2>&1; then
      same=$((same + 1))
    else
      printf '  %-40s DIFFERS\n' "$name"
      differ=$((differ + 1))
    fi
  done < <(repo_skills)

  # Skills present locally but not in the repo — newly created in claude.ai,
  # or Anthropic-provided skills that are deliberately not vendored here.
  for d in "$SYNC_DIR"/*/; do
    name=$(basename "$d")
    [ -f "$d/SKILL.md" ] || continue
    if ! repo_path_for "$name" >/dev/null; then
      printf '  %-40s not in repo\n' "$name"
      untracked=$((untracked + 1))
    fi
  done

  echo
  echo "in sync: $same   differs: $differ   not synced locally: $missing_local   not in repo: $untracked"
  [ "$differ" -eq 0 ] || echo "Run './sync-skills.sh diff <skill>' to inspect, 'pull <skill>' to take the local copy."
}

cmd_diff() {
  local name=${1:?usage: sync-skills.sh diff <skill>}
  local repo
  repo=$(repo_path_for "$name") || { echo "Not in repo: $name" >&2; exit 1; }
  [ -d "$SYNC_DIR/$name" ] || { echo "Not synced locally: $name" >&2; exit 1; }
  diff -ru "$repo" "$SYNC_DIR/$name" || true
}

cmd_pull() {
  local target=${1:?usage: sync-skills.sh pull <skill>|--all}
  local names name repo

  if [ "$target" = "--all" ]; then
    names=$(repo_skills)
  else
    names=$target
  fi

  for name in $names; do
    repo=$(repo_path_for "$name") || { echo "Not in repo: $name" >&2; continue; }
    [ -d "$SYNC_DIR/$name" ] || { echo "Not synced locally: $name" >&2; continue; }
    diff -rq "$repo" "$SYNC_DIR/$name" >/dev/null 2>&1 && continue
    rm -rf "$repo"
    cp -r "$SYNC_DIR/$name" "$repo"
    echo "pulled: $name -> ${repo#"$REPO_ROOT"/}"
  done

  echo
  echo "Review with 'git diff', then commit."
}

case "${1:-check}" in
  check) cmd_check ;;
  diff)  shift; cmd_diff "$@" ;;
  pull)  shift; cmd_pull "$@" ;;
  *)     echo "usage: sync-skills.sh [check|diff <skill>|pull <skill>|pull --all]" >&2; exit 1 ;;
esac
