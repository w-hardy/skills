# TSD 24 — Adjusting survival for treatment switching (methods)

*Supports the PMG36 section 4.6 treatment-switching clause. Update of TSD 16. Use alongside `../modelling-and-uncertainty.md`.*
Full document: https://sheffield.ac.uk/media/65536/download

## The problem
When control-arm patients switch onto the active treatment (or an effective successor),
usually at progression, the **ITT** comparison no longer reflects active-vs-comparator as the
comparator would be used in the NHS. ITT typically **dilutes** the apparent OS benefit
(control patients gain some of the active effect), biasing incremental QALYs — often against
the technology, though the direction depends on the setting. Naive fixes — **censoring** or
**excluding** switchers, or treating switching as a simple time-varying covariate — are
biased because switching is informative (it depends on prognosis). NICE expects a recognised
adjustment.

## The main adjustment methods
- **RPSFT / RPSFTM (rank-preserving structural failure time).** Estimates a common
  acceleration factor for time spent on treatment, using randomisation as an instrument.
  Key assumption: a **common treatment effect** regardless of when treatment is received
  (the switcher gets the same multiplicative benefit as a randomised-arm patient). Preserves
  the randomisation test. Can struggle when the effect differs by timing.
- **IPCW (inverse-probability-of-censoring weighting).** Censors at switch and reweights the
  remaining patients by their probability of not switching, modelled from measured
  covariates. Key assumption: **no unmeasured confounding** of the switch decision — needs
  rich covariate data. Sensitive to small numbers / extreme weights.
- **Two-stage estimation (with re-censoring).** Models the effect of the active treatment
  received after a secondary baseline (e.g. progression) and adjusts switchers' survival.
  Suits switching that happens at a well-defined disease milestone; requires that milestone.

## Choosing, and what a committee / EAG checks
- The choice must match the **switching mechanism and data**: covariate richness (IPCW),
  a clean secondary baseline like progression (two-stage), plausibility of a common effect
  (RPSFT).
- State and defend the **key assumption** of the chosen method; ideally present **more than
  one** method as sensitivity, plus **ITT as a scenario** (a bound), and the naive approaches
  only to show robustness — never as the base case.
- Report the **proportion switching, timing, and destination** (to active vs to a later
  therapy), and re-censoring where used.
- Common errors: censoring/excluding switchers in the base case; using RPSFT when the
  common-effect assumption is clearly violated; IPCW with sparse covariates or unstable
  weights; not propagating the adjustment's extra uncertainty into the PSA.

## Reporting
Switching summary; method chosen with its assumption justified; adjusted vs ITT vs naive
results side by side; and how the adjusted estimate feeds the model's relative effect and
its uncertainty.
