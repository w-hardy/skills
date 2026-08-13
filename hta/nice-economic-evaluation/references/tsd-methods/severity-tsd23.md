# TSD 23 — Calculating severity shortfall (methods)

*Supports PMG36 Table 6.1 and 6.2.13–6.2.18. Updated March 2026. Use alongside
`../decision-making.md`.* Full document:
https://sheffield.ac.uk/media/118621/download

## What it is for
The severity modifier needs two numbers: **absolute** and **proportional QALY shortfall**.
TSD 23 sets out how to calculate them consistently so committees can compare across
evaluations. The skill's `scripts/severity_shortfall.R` implements this method; this file
is the conceptual companion to it.

## The two quantities
For the population that will receive the new technology, matched on **age and sex**:

- **QALYs with the condition (under current/established NHS care)** = the total discounted
  QALYs people with the condition expect over their remaining lifetime under established
  practice. In a model, this is the QALY output of the **comparator / established-practice
  arm** — so it already exists; don't recompute it differently for the shortfall.
- **QALYs for the general population** = the discounted QALYs an age/sex-matched general
  population would expect over the same remaining lifetime, *absent* the condition. Built
  from two reference sources:
  - **mortality**: a recent national life table (ONS), giving survival by attained age/sex;
  - **HRQoL**: general-population EQ-5D **utility norms** by age and sex (a recent, robust
    published source).
  Expected QALYs = Σ over future years of [survival to that year] × [population utility at
  the attained age] × [discount factor], discounted at the reference-case rate.

Then:
- **Absolute shortfall** = general-population QALYs − condition QALYs.
- **Proportional shortfall** = absolute shortfall ÷ general-population QALYs.

Map to the Table 6.1 weight, taking **whichever implies greater severity** (6.2.18); a value
on a cut-off rounds to the higher level.

## Things a committee / EAG checks (and common errors)
- **Discounting applied to the shortfall** (3.5%). A frequent error is computing the general-
  population QALYs undiscounted while the model QALYs are discounted — inflates severity.
  Both sides must be discounted consistently.
- **Age/sex matching to the *treated* population**, using the modelled starting age
  distribution — not the trial's mean age rounded, and not a generic adult.
- **Condition QALYs = established-practice QALYs from the model**, including all currently
  available treatments / best supportive care, not an untreated natural-history estimate.
- **Mix of ages/sexes**: where the population spans ages/sexes, compute the general-
  population QALYs as the appropriately weighted average across the starting distribution,
  not from a single mean age (the relationship is non-linear, so the mean-age shortcut
  biases the result).
- **Reference-source currency**: use recent life tables and EQ-5D norms; state the sources.
- **Boundary cases**: when a shortfall sits exactly on 0.85 / 0.95 (proportional) or 12 / 18
  (absolute), the higher severity band applies.
- **Where it doesn't apply**: HST (severity implicit in selection, 6.2.20) and, usually,
  diagnostics (6.2.19). For HealthTech appraisals it's handled deliberatively.

## Reporting
Show the inputs (starting age/sex distribution, life-table and utility-norm sources, discount
rate), both shortfalls, the implied weights from each, and which one binds — so the
calculation is reproducible and the committee can verify it.
