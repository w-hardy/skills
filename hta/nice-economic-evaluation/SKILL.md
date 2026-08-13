---
name: nice-economic-evaluation
description: >-
  Align health economic work to the NICE reference case and methods (PMG36, the
  NICE technology appraisal and HST manual). Use whenever
  the user is building, reviewing, or sanity-checking an economic evaluation for
  NICE: cost-utility / cost-effectiveness models, ICERs, QALYs, EQ-5D utilities,
  comparator choice, time horizon, discounting, probabilistic / scenario /
  sensitivity analysis, survival extrapolation, fully incremental analysis, net
  health benefit, the severity modifier (absolute and proportional QALY
  shortfall), HST evaluations, or a draft manufacturer submission or EAG/ERG
  report. Trigger it even when the user just asks "does this meet NICE
  requirements?", "is my time horizon / discount rate / utility source OK for
  NICE?", or wants a severity weight, ICER, or efficiency frontier checked — and
  even when they say "NICE", "HTA", "cost per QALY" or "reference case" without
  naming this skill. Prefer it over memory, because the current manual's
  thresholds and modifiers differ from older NICE methods.
---

# NICE economic evaluation: reference-case alignment

Help the user bring an economic evaluation into line with the **NICE reference case**
and supporting methods (PMG36 — *NICE technology appraisal and highly specialised
technologies guidance: the manual*, <https://www.nice.org.uk/process/pmg36>; this skill's
content follows the manual as amended 31 March 2026, verified against the live manual on
3 July 2026). The job is to look at whatever they're working on and tell
them, element by element, where they align, where they deviate, whether the deviation is the
kind NICE accepts, and what's missing — always citing the clause so they can act on it and
quote it in their submission.

**Boundary with the neighbouring skill:** this skill owns the NICE *process* — reference case,
perspective, discounting, severity, thresholds as policy. The Bayesian estimation machinery
those requirements consume (PSA draws, CE plane/CEAC/CEAF construction, net benefit, BCEA,
value-of-information) lives in `bayesian-cea-r-hta`; questions like "is my CEAC acceptable for
NICE?" use both.

## The core principle: the reference case is a default, not a pass/fail gate

NICE *requires* a reference-case analysis, but explicitly *permits* departures from it when
each is **clearly specified, justified, and its impact quantified** (4.2.1, 4.2.3). The
committee then weighs the non-reference-case analysis on its merits. So don't act like a
linter emitting "violations". For each relevant element, place it in one of four states:

- **Aligned** — matches the reference case.
- **Justified deviation** — departs, but with a stated, evidence-backed reason and impact
  quantified (legitimate, often expected — e.g. mapping to EQ-5D, sub-lifetime horizon with
  no mortality difference, a 1.5% discount scenario meeting all conditions).
- **Unjustified deviation** — departs with no reason or no quantified impact. This is the
  main thing to surface: not fatal, but the user must add a justification *and* a
  reference-case version, or the committee will likely discount it.
- **Missing / unclear** — can't be located in the work, so can't be assessed; ask or flag.

This four-state framing is what makes the output useful rather than pedantic.

## Workflow

### 1. Read the right reference file(s) first
Don't work from memory — thresholds and the severity modifier in the current manual differ
from older NICE methods. Based on what the user brings, read the relevant file(s) in
`references/` before assessing:

- `reference-case.md` — Table 4.1 and the core elements: decision problem, comparators,
  perspective, type of evaluation, time horizon, QALYs/EQ-5D, costs, **discounting**,
  equity. Read this for almost any alignment review.
- `modelling-and-uncertainty.md` — model structure, surrogates, **survival extrapolation**,
  treatment switching, and the three sources of uncertainty (structural, source, precision)
  with PSA / scenario / sensitivity expectations (4.6–4.7).
- `results-and-presentation.md` — disaggregation, fully incremental analysis, net health
  benefit, survival curves, with/without discounting (4.10).
- `decision-making.md` — the £25,000–£35,000 (and HST £100,000) range, the **severity
  modifier** (Table 6.1), HST size-of-benefit (Table 6.2), opportunity cost, managed access
  (6.2–6.3).
- `tsd-index.md` — the DSU Technical Support Documents mapped to PMG36 clauses. The TSDs are
  the "how to implement it correctly" layer beneath the manual; consult this whenever a
  finding involves a *method choice* (survival extrapolation, switching, mapping, severity
  shortfall, indirect comparison, model structure) so you can name the specific TSD that
  resolves it.
- `tsd-methods/` — deeper methodological guidance for the TSDs that come up most (key
  assumptions, what an EAG checks, common errors): `severity-tsd23.md`,
  `survival-extrapolation-tsd14-21.md`, `treatment-switching-tsd24.md`,
  `mapping-itc-psm-tsd22-18-19.md`. Read the relevant one when a finding needs real
  method-level guidance rather than just a pointer.

If the work spans several areas (a full model or submission), read more than one. When in
doubt, start with `reference-case.md`.

### 2. Work out what the user has given you and what stage they're at
Common inputs: a model or its description; a results table; an analysis plan / SAP; a draft
submission or EAG report section; or a single methods question ("is a 5-year horizon OK?").
Tailor the depth — a single-question ask gets a focused answer on that element (still cited),
not a 12-point audit.

### 3. Assess each in-scope element and assign one of the four states
For every relevant reference-case element and methods requirement, state: the **status**,
the **clause** (e.g. "4.5.1", "Table 6.1"), the **requirement** in one line, and — crucially
— the **why** and **what to do**. For deviations, say specifically what justification +
quantification NICE would expect, since that's exactly the route NICE allows. When the
finding turns on a **method choice** (how to extrapolate, how to adjust for switching, how to
map utilities, how to calculate the severity shortfall, how to run an indirect comparison),
name the specific DSU TSD that resolves it from `tsd-index.md` — that turns a flag into an
actionable next step. Prefer the current version of any updated TSD (e.g. TSD 24 over 16).

Lead with what matters. The highest-leverage things to check, roughly in order:
comparators match the full scope; cost-utility with QALYs; **fully incremental** results;
lifetime (or justified) horizon; EQ-5D / patient-reported / UK-public-preference utilities;
NHS&PSS perspective with productivity costs excluded; **3.5% discounting** (1.5% only if all
five conditions hold); thorough **uncertainty** analysis; and the **severity modifier**.

### 4. Verify the quantitative claims with the scripts — don't eyeball
There are two kinds of tooling in `scripts/`, and which you reach for depends on whether
you're *checking* the user's work or helping them *produce* it.

**Python — `nice_calcs.py` — for your own verification during a review.** Run it in-container
rather than reasoning numbers out by hand; extended dominance and the "higher of
absolute/proportional" severity rule are easy to get wrong mentally. It provides:

- `fully_incremental(options)` — drops dominated and extendedly dominated options and
  returns sequential ICERs along the frontier. Check the user's reported ICER is the
  frontier ICER, not a stray pairwise one.
- `severity_weight(absolute_shortfall, proportional_shortfall)` — returns the Table 6.1
  weight (1, 1.2, 1.7), taking whichever shortfall implies greater severity, cut-offs
  rounding up. Remind the user both shortfalls must be discounted and age/sex matched to the
  treated population, calculated per the method in **TSD 23** (the current severity-shortfall
  guidance; see `tsd-index.md`).
- `hst_size_of_benefit_weight(incremental_qalys)` — HST-only Table 6.2 weight.
- `net_health_benefit(incremental_cost, incremental_qaly, threshold, qaly_weight)` — NHB,
  NMB, and the weighted ICER / effective threshold, so you can position results against
  £25,000–£35,000 with a severity weight applied.

**R — `severity_shortfall.R` and `survival_extrapolation.R` — deliverables the user runs in
their own environment.** This user works primarily in R, so when they want a tool to use on
their own data (not just a check), point them to these and explain how to call them — don't
hand them Python:

- `severity_shortfall.R` — full TSD 23 shortfall calculator: builds general-population QALYs
  from a life table + EQ-5D norms (which the user supplies — it ships no reference data),
  takes the established-practice QALYs from their model, and returns both shortfalls and the
  weight. Use this when they need to *calculate* severity, not just look up a weight.
- `survival_extrapolation.R` — TSD 14/21 workflow on `flexsurv`: fits the standard parametric
  set + splines, PH check, AIC/BIC, KM-vs-fit and hazard curves, RMST, a general-population
  mortality floor, and a no-continued-benefit scenario. Use when the finding is "the survival
  extrapolation is the problem" and they want to redo it properly. Remind them selection
  rests on fit + plausibility + external data, not AIC alone.

Show the user the numbers and what they imply (e.g. "weighted ICER £18,750 — below £25,000,
so cost-effective at the ×1.2 severity weight"), not just a verdict.

### 5. Produce the alignment review
Default to a compact table the user can act from, then a short prose summary. Use this shape:

```
## NICE reference-case alignment review

| Element | Status | Clause | Finding / action |
|---|---|---|---|
| Comparators | Aligned | 4.2.13 | All three scope comparators included. |
| Time horizon | Unjustified deviation | 4.2.23 | 10-yr horizon but survival differs — extend to lifetime or justify + quantify impact. |
| Utilities | Justified deviation | 4.3.9 | EQ-5D-5L mapped to 3L; method stated and tested in SA. OK. |
| Discounting | Aligned | 4.5.1 | 3.5% both. |
| Severity | Missing | Table 6.1 | Shortfall not calculated — compute absolute & proportional (discounted, age/sex matched). |
| ... | ... | ... | ... |

**Summary.** Reference-case analysis is largely in place. Priorities: (1) ... (2) ...
**Deviations needing justification:** ...
**Not assessable (please confirm):** ...
```

Always:
- **Cite the clause** for every point, so the user can verify and quote it.
- **Distinguish "must align" from "may deviate with justification"** — the four states.
- **Generalise to the reference case, not just the example** — give the rule and the reason,
  so the advice transfers to the user's other analyses.
- **Be specific and actionable.** "Extend to a lifetime horizon (4.2.23), or justify a
  shorter one by showing no differential mortality and short-lived cost differences (4.2.25),
  and quantify the impact" — not "consider your time horizon".

### 6. Scope and edge cases
- **HST**: no severity modifier (severity is implicit in HST selection, 6.2.20); use the
  size-of-benefit modifier instead; threshold is £100,000/QALY.
- **Diagnostics**: shortfall-based severity weights are usually not appropriate (6.2.19).
- **HealthTech appraisals**: severity captured in QALYs and considered deliberatively; NICE
  still developing the modifier here (6.2.12).
- **Cost-comparison** (not CUA): the health-effect rows of Table 4.1 don't apply; check
  similar-benefit logic and consistency with the comparator's published NICE guidance
  (4.2.18–4.2.21).
- If the user names an older manual version or different thresholds, align to *their* target
  and say which values you used. This manual's values are £25,000 / £35,000 / £100,000.

## What not to do
- Don't reproduce long passages of the manual; paraphrase and cite the clause number.
- Don't invent clause numbers. If unsure of the exact citation, name the section/topic and
  say it should be confirmed, rather than guessing a number.
- Don't treat every deviation as a failure — many are legitimate with justification, and
  saying so is part of aligning well.
