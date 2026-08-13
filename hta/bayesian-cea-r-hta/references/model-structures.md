# Decision-model structures in R: trees, Markov models, patient-level simulation, calibration

> Sources: *R for Health Technology Assessment* (Baio et al., online at
> <https://gianluca.statistica.it/books/online/r-hta/>) — Ch. 8 (decision trees) and Ch. 9
> (cohort Markov models); `heemod` package documentation (CRAN). Accessed 2026-07-03; anchors
> are section-level. **Note on implementation:** R-HTA Chs. 8–9 build trees and Markov models
> **by hand in base R** (forward/fold-back for trees; array-based transition matrices for
> Markov), using `heemod` only for the state-transition *diagram* (`define_transition` +
> `plot`). The `heemod`-native build is this repository's / the `decision-modelling-hta` skill's
> choice, not the book's — the correctness principles below are shared, the API is heemod's.
> **Build mechanics live in the dedicated skills** — `decision-modelling-hta` (heemod trees and
> cohort Markov, R-HTA Chs. 8–9), `multistate-models-hta` (continuous-time/individual-level,
> Ch. 11), `discrete-event-simulation-hta` (simmer, Ch. 12), `survival-analysis-hta`
> (time-to-event inputs, Ch. 7). This file is the PSA-facing summary: what each structure must
> get right for its draws to mean what they claim.

The PSA machinery in the other references is structure-agnostic: any of the model types below
just needs to emit paired cost/effect draws per strategy.

## Decision trees

For short-horizon, no-recurrence decisions: strategies → chance nodes → terminal payoffs.
Correctness checklist: branch probabilities sum to 1 at every chance node (enforce by
construction, e.g. `1 - sum(others)`); payoffs include downstream costs, not just the event;
probabilities and payoffs enter as *distributions* (PSA) not point values, with correlated
parameters drawn jointly. Trees embedded as the entry period of a Markov model must hand over a
full state distribution, not a collapsed expectation.

## Markov (state-transition) cohort models

The workhorse for chronic conditions (and this project's extrapolation layer, notebook 05, via
`heemod`):

- **States and cycle length** — states must be exhaustive and mutually exclusive; cycle length
  short enough that multiple transitions per cycle are implausible. Time horizon = enough cycles
  that the decision quantities have converged (lifetime for mortality-bearing models).
- **Transition matrices** — rows sum to 1 per cycle; convert *rates* to per-cycle
  *probabilities* via p = 1 − exp(−r·t) (inverse r = −log(1 − p)/t), never by dividing an
  annual probability by the number of cycles (R-HTA §9.3.2). Time-dependence comes in two flavours heemod distinguishes: `model_time` (time
  since model start — e.g. age-dependent mortality) and `state_time` (time in state — e.g.
  tunnel-state effects); using the wrong one biases long-run occupancy.
- **Half-cycle / within-cycle correction** — costs and QALYs accrue continuously but the cohort
  moves at cycle boundaries; apply a correction (heemod's `method = "life-table"` or
  equivalent) rather than start- or end-of-cycle counting.
- **Discounting** — per cycle, at the policy rate (the rate itself is
  nice-economic-evaluation's territory), applied to both costs and effects.
- **PSA** — every uncertain input gets a distribution (beta for probabilities, gamma/lognormal
  for costs, Dirichlet for full transition rows, logit/log-normal for relative effects);
  parameters estimated together are drawn together (e.g. multivariate normal on the survival
  model's coefficient scale, drawn on the log scale for correlated parameters). One parameter
  draw drives one full model run = one PSA row. R-HTA §9.6 argues the **probabilistic** result
  should be the base case (not a deterministic point estimate), because deterministic evaluation
  is biased for non-linear models (Thom 2022; Wilson 2021).

## Patient-level (microsimulation) models

When history matters beyond what tractable states can carry (e.g. accumulated events, continuous
risk scores). Two uncertainty layers must not be conflated: **first-order** (Monte Carlo noise
across simulated individuals — reduce by simulating more patients; it is *not* decision
uncertainty) and **second-order** (parameter uncertainty — the PSA layer). The PSA loop wraps
the individual loop; reporting first-order noise as if it were a CEAC is a classic error. Check
convergence in the number of simulated patients per parameter draw before trusting the draws.

## Calibration

When some model parameters are not directly estimable but the model must reproduce observed
targets (prevalence, survival at t, registry counts):

- State targets, their uncertainty, and the distance metric explicitly.
- Bayesian calibration treats targets as likelihood terms over the model's inputs — the clean
  version of "tweak until it fits"; accept/reject (ABC-style) or SIR re-weighting of the PSA
  draws are the common practical routes in R.
- Calibrated parameters carry their post-calibration *joint* distribution into the PSA —
  re-drawing them independently after calibration throws the calibration away.
- Report pre- vs post-calibration fit to every target, including targets *not* used to
  calibrate (out-of-sample checks).

## Structural uncertainty

Parameter PSA conditions on the structure being right. Where structure is genuinely contested
(state definitions, extrapolation family, waning assumptions), run the alternatives and present
them as scenarios — or model-average with explicit weights (BCEA's `struct.psa()`). Do not bury
a structural choice inside a parameter distribution.

## In this repository

Notebook 05's extrapolation engine (`extrapolation_funs.R`, `heemod`) is the Markov layer;
its PSA input distributions are pre-specified in the HEAP (deliberately outside the regression
prior catalogue). The within-trial notebooks are draws-native without BCEA; if BCEA is ever
introduced for cross-checking, follow `bcea-package.md`.
