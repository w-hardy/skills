#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "pyyaml==6.0.3",
# ]
# ///
"""Compare skills by content rather than by bytes, for sync-skills.sh.

Usage:
    skill-content.py same <dir-a> <dir-b>     # exit 0 if the two skills match
    skill-content.py same-file <a> <b>        # exit 0 if two SKILL.md files match

claude.ai rewrites SKILL.md frontmatter when it stores a skill (a folded `>-`
description comes back as one single-quoted line), so a byte comparison reports
every uploaded skill as changed. Here SKILL.md frontmatter is compared as parsed
YAML and the body as text (ignoring trailing newlines); every other file must
match byte for byte. Directories named in --exclude (default: evals) are
skipped, since they exist only in the repo and are never uploaded.

Exit status: 0 same, 1 different, 2 usage error.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml


def parse_skill_md(text: str) -> tuple[object, str]:
    """Split SKILL.md into (parsed frontmatter, body); unparseable -> raw text."""
    if text.startswith("---"):
        parts = text.split("\n---", 1)
        if len(parts) == 2:
            head = parts[0][3:]
            rest = parts[1]
            body = rest.split("\n", 1)[1] if "\n" in rest else ""
            try:
                return yaml.safe_load(head), body.rstrip("\n")
            except yaml.YAMLError:
                pass
    return None, text.rstrip("\n")


def same_skill_md(a: Path, b: Path) -> bool:
    try:
        ta = a.read_text(encoding="utf-8")
        tb = b.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return a.read_bytes() == b.read_bytes()
    return parse_skill_md(ta) == parse_skill_md(tb)


def files(root: Path, exclude: set[str]) -> set[Path]:
    out = set()
    for p in root.rglob("*"):
        rel = p.relative_to(root)
        if p.is_file() and not exclude.intersection(rel.parts):
            out.add(rel)
    return out


def same_dir(a: Path, b: Path, exclude: set[str]) -> bool:
    fa, fb = files(a, exclude), files(b, exclude)
    if fa != fb:
        return False
    for rel in fa:
        if rel == Path("SKILL.md"):
            if not same_skill_md(a / rel, b / rel):
                return False
        elif (a / rel).read_bytes() != (b / rel).read_bytes():
            return False
    return True


def main(argv: list[str]) -> int:
    exclude = {"evals"}
    args = []
    it = iter(argv)
    for arg in it:
        if arg == "--exclude":
            exclude.add(next(it, ""))
        else:
            args.append(arg)
    if len(args) == 3 and args[0] == "same":
        return 0 if same_dir(Path(args[1]), Path(args[2]), exclude) else 1
    if len(args) == 3 and args[0] == "same-file":
        return 0 if same_skill_md(Path(args[1]), Path(args[2])) else 1
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
