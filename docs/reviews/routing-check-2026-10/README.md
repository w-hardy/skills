# Routing check: description rewrite, October 2026

Checks that shortening the 27 fork skill descriptions to under 100 tokens (#20) did not change
which skill Claude reaches for.

## Method

- `prompts.json` holds 49 requests, written and committed (ef69e90) before any description was
  changed: one paraphrased positive per fork skill, avoiding its quoted trigger phrases; ten
  boundary cases between siblings; the routing defects from #20 (an existing model's inputs
  changing, a file named `extrapolation_utils.R`, the price-year seam, Dirichlet transitions for a
  hand-built cohort model); and keyword collisions that no fork skill should take. Each lists the
  skills that should load and the skills that must not. Ten were held back and not looked at
  while drafting.
- `listing.py build <arm>` renders the alphabetical name-and-description listing a router sees:
  the fork skills plus the 13 Anthropic-provided skills from the local claude.ai sync.
  - `current`: descriptions as committed before the rewrite (098931b), in full.
  - `deployed`: exactly what the claude.ai sync held on 2026-10-03, with descriptions blanked for
    the 13 skills Claude Code listed by name only. It is a stale August upload, and it lacks
    `hesim-ctstm-hta`, `trial-based-cea-hta` and `scientific-writing`, which were never uploaded.
  - `rewritten`: the new descriptions.
- Each arm ran twice. Each run was a fresh subagent that read only the listing and the bare
  requests, picked 0–2 skills per request and saw no expected answers. `answers/` holds the
  raw picks; `listing.py score answers/<run>.json [--holdout|--all]` scores them.
- A request passes when a pick is one of the expected skills (or no fork skill is picked where
  none should be) and no must-not skill is picked.

## Results

| Arm | Development (39) | Held out (10) |
| --- | ---: | ---: |
| current, runs 1 and 2 | 39, 39 | 10, 10 |
| deployed, runs 1 and 2 | 34, 34 | 10, 10 |
| rewritten, runs 1 and 2 | 39, 39 | 10, 10 |

The rewrite routes as well as the full descriptions it replaces, at 41% of their length
(10,750 characters across the 27, from 26,267), and passes all four #20 cases.

The deployed listing's five failures are the three skills missing from claude.ai (P11 and B02
want `hesim-ctstm-hta`, P25 `trial-based-cea-hta`, P27 `scientific-writing`) and C1, which the
stale `bayesian-cea-r-hta` description cannot catch because the "inputs changed" clause was added
after the August upload. The 13 name-only skills cost nothing in this test: a router given only a
name such as `nice-economic-evaluation` still picked it for these requests. That is a limit of
the test, whose prompts are written to be answerable, rather than evidence that descriptions do
not matter: a bare name carries no scope, boundary or "prefer over memory" signal.

The held-out ten did not separate the arms; every arm passed them.

## Limits

One router model (the session's), two runs per arm, 49 requests. It measures which skill is
picked from a listing, not whether the skill then helps.
