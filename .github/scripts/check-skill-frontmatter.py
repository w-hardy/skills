#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "pyyaml==6.0.3",
#   "tiktoken==0.14.0",
# ]
# ///
"""Check SKILL.md frontmatter in the fork's own skill categories.

Usage:
    uv run .github/scripts/check-skill-frontmatter.py            # every fork skill
    uv run .github/scripts/check-skill-frontmatter.py hta/foo/   # named skill dirs

Only hta/, biostatistics/, ml-clinical/ and research-methods/ are checked: the
upstream Posit categories and the vendored superpowers/ and tidymodels/ trees
are not edited in this fork, so findings there would not be actionable.

Errors (exit 1):
  - the frontmatter is missing or is not valid YAML
  - `name` does not match the skill's directory name
  - `description` is missing, over 100 tokens (cl100k_base, the same count as
    count-skill-tokens.py), or over 1,024 characters
  - a line of the description starts at column 0 (Claude Code drops such
    descriptions even though the YAML parses)
  - the description contains `<` or `>` (rejected on upload to claude.ai) or a
    literal `''` (a single-quote escape that survived into the text)

Warnings: a description or body that points at a skill name that does not exist.

The combined length of all checked descriptions is printed, because Claude Code
lists every installed skill's description in one budget.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import tiktoken
import yaml

FORK_CATEGORIES = ("hta", "biostatistics", "ml-clinical", "research-methods")
TOKEN_LIMIT = 100
CHAR_LIMIT = 1024

REPO = Path(__file__).resolve().parents[2]
FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)
KEBAB = r"[a-z0-9]+(?:-[a-z0-9]+)+"
# A kebab-case word used as a skill reference: backticked, or introduced by a
# routing verb ("use x", "see x", "hands off to x", "x skill").
SKILL_REF = re.compile(
    rf"`({KEBAB})`"
    rf"|\b(?:use|see|via|to|into|from|with)\s+({KEBAB})\b"
    rf"|\b({KEBAB})\s+skill\b"
)


def all_skill_names() -> set[str]:
    names = set()
    for skill_md in REPO.glob("**/SKILL.md"):
        if ".git" not in skill_md.parts:
            names.add(skill_md.parent.name)
    return names


def description_block(raw: str) -> list[str]:
    """Raw frontmatter lines belonging to the `description` key."""
    lines = raw.splitlines()
    block, inside = [], False
    for line in lines:
        if re.match(r"^description\s*:", line):
            inside = True
            block.append(line)
            continue
        if inside:
            if re.match(r"^[A-Za-z_][\w-]*\s*:", line):
                break
            block.append(line)
    return block


def check(skill_dir: Path, enc, known: set[str]) -> tuple[list[str], list[str], int, int]:
    errors: list[str] = []
    warnings: list[str] = []
    text = (skill_dir / "SKILL.md").read_text(encoding="utf-8")
    m = FRONTMATTER.match(text)
    if not m:
        return ["no YAML frontmatter"], warnings, 0, 0
    try:
        meta = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as e:
        return [f"frontmatter is not valid YAML: {str(e).splitlines()[0]}"], warnings, 0, 0

    name = meta.get("name")
    if name != skill_dir.name:
        errors.append(f"name {name!r} does not match directory {skill_dir.name!r}")

    desc = meta.get("description")
    if not isinstance(desc, str) or not desc.strip():
        return errors + ["description is missing or empty"], warnings, 0, 0

    n_tokens = len(enc.encode(desc))
    if n_tokens > TOKEN_LIMIT:
        errors.append(f"description is {n_tokens} tokens (limit {TOKEN_LIMIT})")
    if len(desc) > CHAR_LIMIT:
        errors.append(f"description is {len(desc)} characters (limit {CHAR_LIMIT})")
    for line in description_block(m.group(1))[1:]:
        if line.strip() and not line[0].isspace():
            errors.append(f"description line starts at column 0: {line[:40]!r}")
            break
    if "<" in desc or ">" in desc:
        errors.append("description contains < or >")
    if "''" in desc:
        errors.append("description contains a literal '' (escaped quote)")

    body = text[m.end():]
    for source, where in ((desc, "description"), (body, "body")):
        for groups in SKILL_REF.findall(source):
            ref = next(g for g in groups if g)
            if ref not in known and looks_like_skill(ref):
                warnings.append(f"{where} points at {ref!r}, which is not a skill in this repo")
    return errors, sorted(set(warnings)), n_tokens, len(desc)


def looks_like_skill(word: str) -> bool:
    """Skill names here end in a domain suffix; ordinary hyphenated words do not."""
    return bool(re.search(
        r"-(hta|clinical|reporting|modelling|models|regression|analysis|practices|"
        r"evaluation|comparisons|gmethods|splines|mice|tabular|writing|grouper|"
        r"checklists?|design)$",
        word,
    ))


def main(argv: list[str]) -> int:
    if argv:
        dirs = [Path(a).resolve() for a in argv]
    else:
        dirs = sorted(
            p.parent for cat in FORK_CATEGORIES for p in (REPO / cat).glob("*/SKILL.md")
        )
    dirs = [d for d in dirs if d.relative_to(REPO).parts[0] in FORK_CATEGORIES]
    if not dirs:
        print("No fork skills to check.")
        return 0

    enc = tiktoken.get_encoding("cl100k_base")
    known = all_skill_names()
    failed = 0
    total_chars = 0
    print(f"| Skill | Tokens | Chars | Result |\n|---|---:|---:|---|")
    report: list[str] = []
    for d in dirs:
        rel = d.relative_to(REPO).as_posix()
        errors, warnings, n_tokens, n_chars = check(d, enc, known)
        total_chars += n_chars
        status = "error" if errors else ("warning" if warnings else "ok")
        print(f"| {rel} | {n_tokens} | {n_chars} | {status} |")
        failed += bool(errors)
        report += [f"ERROR   {rel}: {e}" for e in errors]
        report += [f"WARNING {rel}: {w}" for w in warnings]
    print()
    print(f"{len(dirs)} skills checked; combined description length {total_chars:,} characters.")
    if report:
        print()
        print("\n".join(report))
    if failed:
        print(f"\n{failed} skill(s) failed. Descriptions: under {TOKEN_LIMIT} tokens, as an indented `>-` block.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
