#!/bin/bash
# Refreshes the vendored skill families (superpowers/, tidymodels/) from the
# upstream sources listed in .github/vendored-skills.json.
#
# superpowers/ and tidymodels/ are verbatim copies of an upstream directory
# pinned at a commit, with no shared git history with their upstreams, so they
# cannot be refreshed by the merge-based sync-upstream.yml workflow. Instead,
# for each source in the manifest, this script:
#   1. Clones the upstream repo at its ref.
#   2. Overwrites dest from the clone's subdir with `rsync -a --delete`,
#      excluding the manifest's `exclude` list plus LICENSE/README.md (which
#      are always locally kept, never deleted or overwritten by rsync).
#   3. Restores/verifies dest/LICENSE per the manifest's `license` field.
#   4. Detects drift between the skill directories now under dest and the
#      matching plugin's `skills` array in .claude-plugin/marketplace.json,
#      and reports it (never edits marketplace.json or README.md).
#   5. Updates the category README's provenance table in place.
#   6. Writes a report (path from $REPORT, default vendored-skills-report.md)
#      summarizing what happened, for a workflow to turn into a PR body.
#
# Runnable locally with no GitHub credentials (only network access to
# github.com for the upstream clones). Usage:
#
#   bash .github/scripts/refresh-vendored-skills.sh
#   git status
#   git checkout -- . && git clean -fd superpowers tidymodels
#
# Exits 0 whether or not anything changed; the caller (a human, or the
# refresh-vendored-skills.yml workflow) decides what to do with the diff.
# Exits non-zero only on a hard failure (missing LICENSE, missing provenance
# row, etc.) — those indicate the manifest or a README drifted from what this
# script expects and need a human to fix, not a routine refresh to paper over.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MANIFEST=".github/vendored-skills.json"
REPORT="${REPORT:-vendored-skills-report.md}"
MARKETPLACE=".claude-plugin/marketplace.json"

if [ ! -f "$MANIFEST" ]; then
  echo "error: manifest not found at $MANIFEST" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

: > "$REPORT"
{
  echo "# Vendored skills refresh report"
  echo
  echo "Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) by refresh-vendored-skills.sh."
  echo
} >> "$REPORT"

ANY_MANIFEST_DRIFT=0

n_sources=$(jq -r '.sources | length' "$MANIFEST")

for i in $(seq 0 $((n_sources - 1))); do
  src_json=$(jq -c ".sources[$i]" "$MANIFEST")
  get() { echo "$src_json" | jq -r "$1"; }

  name=$(get '.name')
  upstream=$(get '.upstream')
  ref=$(get '.ref')
  subdir=$(get '.subdir')
  dest=$(get '.dest')
  license=$(get '.license')
  version_from=$(get '.version_from')
  readme=$(get '.readme')
  plugin=$(get '.plugin')
  mapfile -t excludes < <(echo "$src_json" | jq -r '.exclude[]?')

  echo "=== $name ($upstream @ $ref) ==="

  if [ ! -d "$dest" ]; then
    echo "error: dest '$dest' for source '$name' does not exist" >&2
    exit 1
  fi
  if [ ! -f "$readme" ]; then
    echo "error: readme '$readme' for source '$name' does not exist" >&2
    exit 1
  fi

  # --- Parse the previously-vendored commit out of the README before we touch it ---
  prev_commit=$(grep -E '^\| Vendored commit \|' "$readme" | sed -E 's/^\| Vendored commit \| `([0-9a-f]+)`.*/\1/' || true)
  if [ -z "$prev_commit" ]; then
    echo "error: could not find a 'Vendored commit' row in $readme" >&2
    exit 1
  fi

  # --- Clone upstream at ref ---
  clone_dir="$WORKDIR/$name"
  git clone --quiet --depth 1 --branch "$ref" "https://github.com/$upstream" "$clone_dir"
  new_commit=$(git -C "$clone_dir" rev-parse HEAD)
  new_date=$(git -C "$clone_dir" log -1 --format=%cs)

  new_version=""
  if [ "$version_from" != "null" ]; then
    version_file="$clone_dir/$version_from"
    if [ -f "$version_file" ]; then
      new_version=$(jq -r '.version // empty' "$version_file")
    else
      echo "error: version_from '$version_from' for source '$name' not found in upstream clone" >&2
      exit 1
    fi
  fi

  src_dir="$clone_dir/$subdir"
  if [ ! -d "$src_dir" ]; then
    echo "error: subdir '$subdir' for source '$name' not found in upstream clone" >&2
    exit 1
  fi

  # --- Overwrite dest from src_dir, never touching LICENSE/README.md ---
  rsync_args=(-a --delete --exclude=/LICENSE --exclude=/README.md)
  for ex in "${excludes[@]:-}"; do
    [ -n "$ex" ] && rsync_args+=(--exclude="/$ex")
  done
  rsync "${rsync_args[@]}" "$src_dir"/ "$dest"/

  # --- LICENSE step ---
  case "$license" in
    upstream:*)
      lic_path="${license#upstream:}"
      if [ -f "$clone_dir/$lic_path" ]; then
        cp "$clone_dir/$lic_path" "$dest/LICENSE"
      fi
      ;;
    local)
      : # locally authored; must already exist, verified below
      ;;
    *)
      echo "error: unrecognized license spec '$license' for source '$name'" >&2
      exit 1
      ;;
  esac

  if [ ! -f "$dest/LICENSE" ]; then
    echo "error: $dest/LICENSE is missing after refreshing source '$name' (license: $license)" >&2
    exit 1
  fi

  # --- Skill drift detection ---
  # Computed on dest as it stands *after* the overwrite, i.e. on exactly the
  # tree this run would commit, so a skill upstream added or removed is
  # flagged in the same PR that brings the change in. marketplace.json and
  # the root README are never edited here; the report tells a human what to
  # change.
  skill_dirs=()
  if [ -f "$dest/SKILL.md" ]; then
    skill_dirs+=("./$dest")
  else
    while IFS= read -r d; do
      skill_dirs+=("./$d")
    done < <(find "$dest" -mindepth 1 -maxdepth 1 -type d | while read -r d; do
      [ -f "$d/SKILL.md" ] && echo "$d"
    done | sort)
  fi

  mapfile -t manifest_skills < <(jq -r --arg p "$plugin" '.plugins[] | select(.name == $p) | .skills[]' "$MARKETPLACE" | sort)
  mapfile -t actual_skills < <(printf '%s\n' "${skill_dirs[@]}" | sort)

  mapfile -t added < <(comm -23 <(printf '%s\n' "${actual_skills[@]}") <(printf '%s\n' "${manifest_skills[@]}"))
  mapfile -t removed < <(comm -13 <(printf '%s\n' "${actual_skills[@]}") <(printf '%s\n' "${manifest_skills[@]}"))

  drift=0
  if [ "${#added[@]}" -gt 0 ] || [ "${#removed[@]}" -gt 0 ]; then
    drift=1
    ANY_MANIFEST_DRIFT=1
  fi

  # --- Provenance update ---
  if ! grep -qE '^\| Vendored commit \|' "$readme"; then
    echo "error: 'Vendored commit' row disappeared from $readme before update" >&2
    exit 1
  fi
  # Delimiter is @ rather than the customary | because the replacement text
  # itself contains literal "|" (table cell separators) which would otherwise
  # terminate the sed s@@@ groups early and corrupt the file.
  sed -i -E "s@^\| Vendored commit \|.*\$@| Vendored commit | \`${new_commit}\` (${new_date}) |@" "$readme"

  if [ "$version_from" != "null" ]; then
    if ! grep -qE '^\| Upstream version \|' "$readme"; then
      echo "error: 'Upstream version' row not found in $readme but version_from is set for source '$name'" >&2
      exit 1
    fi
    sed -i -E "s@^\| Upstream version \|.*\$@| Upstream version | ${new_version} |@" "$readme"
  fi

  changed="false"
  if [ -n "$(git status --porcelain -- "$dest" "$readme")" ]; then
    changed="true"
  fi

  echo "  previous commit: $prev_commit"
  echo "  new commit:      $new_commit ($new_date)"
  [ -n "$new_version" ] && echo "  upstream version: $new_version"
  echo "  changed:         $changed"
  [ "$drift" -eq 1 ] && echo "  manifest drift:  added=${#added[@]} removed=${#removed[@]}"

  {
    echo "## $name"
    echo
    echo "- Upstream: \`$upstream\` (ref \`$ref\`)"
    echo "- Previous vendored commit: \`$prev_commit\`"
    echo "- New vendored commit: \`$new_commit\` ($new_date)"
    [ -n "$new_version" ] && echo "- Upstream version: $new_version"
    echo "- Files changed: $changed"
    echo
  } >> "$REPORT"

  if [ "$drift" -eq 1 ]; then
    {
      echo "### Manifest action needed: $name"
      echo
      echo "The skill directories under \`$dest\` no longer match the \`$plugin\` plugin's"
      echo "\`skills\` list in \`.claude-plugin/marketplace.json\`. Update that list (and the"
      echo "matching section of the root \`README.md\`) by hand:"
      echo
      if [ "${#added[@]}" -gt 0 ]; then
        echo "Add:"
        for a in "${added[@]}"; do echo "- \`$a\`"; done
      fi
      if [ "${#removed[@]}" -gt 0 ]; then
        echo "Remove:"
        for r in "${removed[@]}"; do echo "- \`$r\`"; done
      fi
      echo
    } >> "$REPORT"
  else
    {
      echo "No manifest drift for \`$name\`: the \`$plugin\` plugin's skill list still matches \`$dest\`."
      echo
    } >> "$REPORT"
  fi
done

echo
echo "=== Summary ==="
cat "$REPORT"

exit 0
