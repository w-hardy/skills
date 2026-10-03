#!/usr/bin/env bash
# Compare the skills in this repository against the copies Claude has synced
# locally from claude.ai, pull genuine claude.ai edits back into the repository,
# and package committed skills for upload.
#
# This repository is the source of truth. Skills edited here are published to
# claude.ai by uploading them there; skills edited in the claude.ai editor land
# in the local sync directory and need pulling back in with `pull` so git does
# not fall behind.
#
# Usage:
#   ./sync-skills.sh                    # report drift (default)
#   ./sync-skills.sh check              # same as above
#   ./sync-skills.sh diff <skill>       # show what differs for one skill
#   ./sync-skills.sh pull <skill>       # copy the local copy over the repo copy
#   ./sync-skills.sh pull --all         # pull every differing local copy
#   ./sync-skills.sh pull --force ...   # pull even a copy that matches an older commit
#   ./sync-skills.sh package <skill>    # write dist/<skill>.zip from the committed version
#   ./sync-skills.sh package --all      # package every skill in the fork's categories
#
# `pull` never deletes files that exist only in the repo (such as evals/), and it
# refuses a local copy whose SKILL.md matches an older committed version: that
# copy is stale, not edited, and taking it would revert later work.
#
# Environment:
#   SKILLS_SYNC_DIR   local sync directory (default ~/.claude/skills/synced). Skills
#                     may sit directly under it or one level down (the sync groups
#                     them by account, e.g. synced/<org>_<user>/<skill>/).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SKILLS_SYNC_DIR:-$HOME/.claude/skills/synced}"
DIST_DIR="$REPO_ROOT/dist"

# Categories in this repo that hold personally-authored skills. Posit's own
# categories and the vendored families are deliberately excluded.
CATEGORIES=(hta biostatistics ml-clinical research-methods)

# Directories that exist only in the repo and are never uploaded.
REPO_ONLY_DIRS=(evals)

need_sync_dir() {
  if [ ! -d "$SYNC_DIR" ]; then
    echo "Local sync directory not found: $SYNC_DIR" >&2
    echo "Set SKILLS_SYNC_DIR to point at it." >&2
    exit 1
  fi
}

# Print the repo path for a skill name, or nothing if it is not in the repo.
repo_path_for() {
  local name=$1 cat
  for cat in "${CATEGORIES[@]}"; do
    if [ -f "$REPO_ROOT/$cat/$name/SKILL.md" ]; then
      echo "$REPO_ROOT/$cat/$name"
      return 0
    fi
  done
  return 1
}

# Every skill name tracked in this repo, across the fork's categories.
repo_skills() {
  local cat d
  for cat in "${CATEGORIES[@]}"; do
    [ -d "$REPO_ROOT/$cat" ] || continue
    for d in "$REPO_ROOT/$cat"/*/; do
      [ -f "${d}SKILL.md" ] && basename "$d"
    done
  done | sort
}

# Every synced skill directory (one per line), flat or one level down.
synced_dirs() {
  find "$SYNC_DIR" -mindepth 2 -maxdepth 3 -name SKILL.md -type f 2>/dev/null \
    | sed 's|/SKILL\.md$||' | sort
}

# Print the synced directory for a skill name, or nothing if it is not synced.
synced_path_for() {
  synced_dirs | awk -v n="$1" -F/ '$NF == n { print; exit }'
}

exclude_args() {
  local d
  for d in "${REPO_ONLY_DIRS[@]}"; do printf -- '-x\n%s\n' "$d"; done
}

same_content() {
  local args
  mapfile -t args < <(exclude_args)
  diff -rq "${args[@]}" "$1" "$2" >/dev/null 2>&1
}

# Succeeds when any file in the synced copy matches an older committed version
# of the same file and not HEAD's, i.e. the synced copy is (at least partly) an
# older upload. A claude.ai edit to one file does not make the rest current.
is_stale() {
  local repo=$1 synced=$2 rel file blob commit head
  rel=${repo#"$REPO_ROOT"/}
  while IFS= read -r file; do
    blob=$(git -C "$REPO_ROOT" hash-object "$synced/$file")
    head=$(git -C "$REPO_ROOT" rev-parse "HEAD:$rel/$file" 2>/dev/null || true)
    [ "$blob" = "$head" ] && continue
    for commit in $(git -C "$REPO_ROOT" rev-list HEAD -- "$rel/$file"); do
      if [ "$blob" = "$(git -C "$REPO_ROOT" rev-parse "$commit:$rel/$file" 2>/dev/null)" ]; then
        return 0
      fi
    done
  done < <(cd "$synced" && find . -type f | sed 's|^\./||')
  return 1
}

cmd_check() {
  need_sync_dir
  local same=0 differ=0 stale=0 missing_local=0 untracked=0
  local name repo synced dups chars

  while read -r name; do
    repo=$(repo_path_for "$name")
    synced=$(synced_path_for "$name")
    if [ -z "$synced" ]; then
      printf '  %-40s not synced locally\n' "$name"
      missing_local=$((missing_local + 1))
    elif same_content "$repo" "$synced"; then
      same=$((same + 1))
    elif is_stale "$repo" "$synced"; then
      printf '  %-40s STALE (local copy is an older upload)\n' "$name"
      stale=$((stale + 1))
    else
      printf '  %-40s DIFFERS\n' "$name"
      differ=$((differ + 1))
    fi
  done < <(repo_skills)

  # Skills present locally but not in the repo: newly created in claude.ai, or
  # Anthropic-provided skills that are deliberately not vendored here.
  while read -r synced; do
    name=$(basename "$synced")
    if ! repo_path_for "$name" >/dev/null; then
      printf '  %-40s not in repo\n' "$name"
      untracked=$((untracked + 1))
    fi
  done < <(synced_dirs)

  # An upload that added a second copy instead of replacing the first shows up
  # as the same skill name twice.
  dups=$(synced_dirs | while read -r d; do
    sed -n 's/^name:[[:space:]]*//p' "$d/SKILL.md" | head -1
  done | sort | uniq -d)
  [ -z "$dups" ] || printf '\nDuplicate skill names in the sync: %s\n' "$(echo "$dups" | tr '\n' ' ')"

  # Claude Code lists every installed skill's description in one budget.
  chars=$(synced_dirs | while read -r d; do
    awk '/^---$/{n++; next} n==1' "$d/SKILL.md" | awk '
      /^description:/ {inside=1; sub(/^description:[[:space:]]*>?-?[[:space:]]*/, ""); printf "%s", $0; next}
      inside && /^[A-Za-z_][A-Za-z0-9_-]*:/ {inside=0}
      inside {sub(/^[[:space:]]+/, " "); printf "%s", $0}'
  done | wc -c)

  echo
  echo "in sync: $same   stale: $stale   differs: $differ   not synced locally: $missing_local   not in repo: $untracked"
  echo "synced description text: ~$chars characters in total"
  [ "$stale" -eq 0 ] || echo "Stale copies need the repo version uploaded: './sync-skills.sh package <skill>'."
  [ "$differ" -eq 0 ] || echo "Run './sync-skills.sh diff <skill>' to inspect, 'pull <skill>' to take the local copy."
}

cmd_diff() {
  need_sync_dir
  local name=${1:?usage: sync-skills.sh diff <skill>}
  local repo synced args
  repo=$(repo_path_for "$name") || { echo "Not in repo: $name" >&2; exit 1; }
  synced=$(synced_path_for "$name")
  [ -n "$synced" ] || { echo "Not synced locally: $name" >&2; exit 1; }
  mapfile -t args < <(exclude_args)
  diff -ru "${args[@]}" "$repo" "$synced" || true
}

cmd_pull() {
  need_sync_dir
  local force=0
  if [ "${1:-}" = "--force" ]; then force=1; shift; fi
  local target=${1:?usage: sync-skills.sh pull [--force] <skill>|--all}
  local names name repo synced

  if [ "$target" = "--all" ]; then
    names=$(repo_skills)
  else
    names=$target
  fi

  for name in $names; do
    repo=$(repo_path_for "$name") || { echo "Not in repo: $name" >&2; continue; }
    synced=$(synced_path_for "$name")
    [ -n "$synced" ] || { echo "Not synced locally: $name" >&2; continue; }
    same_content "$repo" "$synced" && continue
    if [ "$force" -eq 0 ] && is_stale "$repo" "$synced"; then
      echo "skipped: $name — the local copy matches an older commit (stale upload); use --force to take it anyway" >&2
      continue
    fi
    # Copy over the repo copy without deleting files that exist only in the repo.
    cp -R "$synced"/. "$repo"/
    echo "pulled: $name -> ${repo#"$REPO_ROOT"/}"
  done

  echo
  echo "Review with 'git diff', then commit. Files deleted on claude.ai are not deleted here."
}

cmd_package() {
  local target=${1:?usage: sync-skills.sh package <skill>|--all}
  local names name repo rel exclude=() d

  if [ "$target" = "--all" ]; then
    names=$(repo_skills)
  else
    names=$target
  fi

  # Check the frontmatter of what is about to be uploaded.
  local dirs=()
  for name in $names; do
    repo=$(repo_path_for "$name") || { echo "Not in repo: $name" >&2; exit 1; }
    dirs+=("${repo#"$REPO_ROOT"/}")
  done
  (cd "$REPO_ROOT" && uv run .github/scripts/check-skill-frontmatter.py "${dirs[@]}" >/dev/null) \
    || { echo "Frontmatter check failed; run it directly for details." >&2; exit 1; }

  for d in "${REPO_ONLY_DIRS[@]}"; do exclude+=(":(exclude)$d"); done
  mkdir -p "$DIST_DIR"
  for name in $names; do
    repo=$(repo_path_for "$name")
    rel=${repo#"$REPO_ROOT"/}
    if ! git -C "$REPO_ROOT" diff --quiet HEAD -- "$rel" \
       || [ -n "$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$rel")" ]; then
      echo "warning: $rel has uncommitted changes; packaging the committed version" >&2
    fi
    rm -f "$DIST_DIR/$name.zip"
    (cd "$REPO_ROOT/$rel" && git archive --format=zip --prefix="$name/" \
      -o "$DIST_DIR/$name.zip" HEAD -- . "${exclude[@]}")
    echo "packaged: dist/$name.zip"
  done
  echo
  echo "Upload each zip in the claude.ai skill editor, replacing the existing skill of the same name."
}

case "${1:-check}" in
  check)   cmd_check ;;
  diff)    shift; cmd_diff "$@" ;;
  pull)    shift; cmd_pull "$@" ;;
  package) shift; cmd_package "$@" ;;
  *)       echo "usage: sync-skills.sh [check|diff <skill>|pull [--force] <skill>|pull --all|package <skill>|package --all]" >&2; exit 1 ;;
esac
