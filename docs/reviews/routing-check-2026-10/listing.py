#!/usr/bin/env python3
"""Build the skill listing a router sees, and score router answers.

    python3 listing.py build <arm> > listing.txt   # arm: current | deployed | rewritten
    python3 listing.py score answers.json [--holdout | --all]

Arms:
  current    fork descriptions as committed before the rewrite (git ref PRE_REWRITE),
             in full, plus the Anthropic-provided skills synced from claude.ai
  deployed   exactly what the local claude.ai sync holds, with descriptions blanked
             for the 13 skills Claude Code listed by name only on 2026-10-03
  rewritten  fork descriptions from the working tree, plus the Anthropic skills

The listing is alphabetical, one `- name: description` line per skill, as
Claude Code renders it.
"""

import glob
import json
import os
import re
import subprocess
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FORK = ("hta", "biostatistics", "ml-clinical", "research-methods")
PRE_REWRITE = os.environ.get("PRE_REWRITE", "098931b")
SYNC = os.environ.get("SKILLS_SYNC_DIR", os.path.expanduser("~/.claude/skills/synced"))
NAME_ONLY = {  # listed without a description in the 2026-10-03 session
    "ml-supervised-tabular", "multistate-models-hta", "network-meta-analysis-hta",
    "nice-economic-evaluation", "pdf", "penalised-regression",
    "population-adjusted-comparisons", "pptx", "shiny-hta", "skill-creator",
    "survival-analysis-hta", "tripod-ai-reporting", "xlsx",
}


def desc(text):
    m = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    return " ".join(str((yaml.safe_load(m.group(1)) or {}).get("description", "")).split())


def synced():
    out = {}
    for p in glob.glob(os.path.join(SYNC, "**", "SKILL.md"), recursive=True):
        out[os.path.basename(os.path.dirname(p))] = desc(open(p, encoding="utf-8").read())
    return out


def fork(ref=None):
    out = {}
    for c in FORK:
        for p in glob.glob(os.path.join(REPO, c, "*", "SKILL.md")):
            name = os.path.basename(os.path.dirname(p))
            if ref:
                rel = os.path.relpath(p, REPO)
                text = subprocess.run(["git", "-C", REPO, "show", f"{ref}:{rel}"],
                                      capture_output=True, text=True).stdout
            else:
                text = open(p, encoding="utf-8").read()
            if text:
                out[name] = desc(text)
    return out


def build(arm):
    sync = synced()
    fork_names = {os.path.basename(os.path.dirname(p)) for c in FORK
                  for p in glob.glob(os.path.join(REPO, c, "*", "SKILL.md"))}
    anthropic = {k: v for k, v in sync.items() if k not in fork_names}
    if arm == "deployed":
        skills = {k: ("" if k in NAME_ONLY else v) for k, v in sync.items()}
    elif arm == "current":
        skills = {**anthropic, **fork(PRE_REWRITE)}
    elif arm == "rewritten":
        skills = {**anthropic, **fork()}
    else:
        sys.exit(f"unknown arm {arm}")
    for name in sorted(skills):
        d = skills[name]
        print(f"- {name}: {d}" if d else f"- {name}")


def score(path, which):
    prompts = {p["id"]: p for p in json.load(open(os.path.join(HERE, "prompts.json")))}
    fork_names = {os.path.basename(os.path.dirname(p)) for c in FORK
                  for p in glob.glob(os.path.join(REPO, c, "*", "SKILL.md"))}
    answers = json.load(open(path))
    rows, passed = [], 0
    for pid, p in prompts.items():
        if which == "dev" and p["holdout"] or which == "holdout" and not p["holdout"]:
            continue
        picks = [x for x in answers.get(pid, []) if x]
        expect = [e for e in p["expect"] if e]
        none_ok = not p["expect"] or "" in p["expect"]
        hit = bool(set(picks) & set(expect)) or (none_ok and not (set(picks) & fork_names))
        bad = set(picks) & set(p["never"])
        ok = hit and not bad
        passed += ok
        rows.append((pid, p["cls"], ok, picks))
    for pid, cls, ok, picks in rows:
        print(f"{'PASS' if ok else 'FAIL'}  {pid:4s} {cls:9s} {', '.join(picks) or '(none)'}")
    print(f"\n{passed}/{len(rows)} passed")


if __name__ == "__main__":
    if sys.argv[1] == "build":
        build(sys.argv[2])
    else:
        which = "all" if "--all" in sys.argv else "holdout" if "--holdout" in sys.argv else "dev"
        score(sys.argv[2], which)
