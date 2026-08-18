# Superpowers

Vendored copy of the skills from [obra/superpowers](https://github.com/obra/superpowers)
by Jesse Vincent — a software development methodology for coding agents, covering
brainstorming, planning, TDD, systematic debugging, code review, and skill authoring.

## Provenance

| | |
| --- | --- |
| Upstream | https://github.com/obra/superpowers |
| Upstream version | 6.3.0 |
| Vendored commit | `b36e0829c6d0140e93cfef2ca599b1b07d4a7797` (2026-08-12) |
| Licence | MIT — see [LICENSE](./LICENSE), Copyright (c) 2025 Jesse Vincent |

The 14 skill directories here are copied **verbatim** from upstream `skills/`, so
that refreshing them is a clean overwrite rather than a merge. Do not edit them in
place; send fixes upstream instead.

## What is not vendored

Upstream ships more than skills. Only `skills/` is carried here, because this
repository is a skills collection. Left behind:

- `hooks/` — a `SessionStart` hook that injects the "read `using-superpowers`
  first" instruction at the start of every session. Without it, the
  `using-superpowers` skill is discoverable but not automatically invoked.
- `.agents/`, `.codex-plugin/`, `.cursor-plugin/`, `.devin-plugin/`,
  `.hermes-plugin/`, `.kimi-plugin/`, `.opencode/`, `.pi/` — packaging for
  non-Claude agents.
- `tests/`, `scripts/`, `docs/`.

For the full experience including the session-start hook, install upstream
directly instead of using this copy:

```
/plugin marketplace add obra/superpowers
/plugin install superpowers@superpowers-marketplace
```

Cross-skill references inside these files use the `superpowers:<skill-name>` form.
They keep resolving here because the plugin registered in
`.claude-plugin/marketplace.json` is also named `superpowers`.

## Refreshing from upstream

```bash
git clone --depth 1 https://github.com/obra/superpowers /tmp/superpowers
rm -rf superpowers/*/                 # skill directories only; keeps LICENSE and this file
cp -r /tmp/superpowers/skills/. superpowers/
cp /tmp/superpowers/LICENSE superpowers/LICENSE
```

Then check whether upstream added or removed skills, and update the `superpowers`
plugin in `.claude-plugin/marketplace.json` and the root `README.md` to match.
