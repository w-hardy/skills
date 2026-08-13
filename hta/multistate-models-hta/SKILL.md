---
name: multistate-models-hta
description: "Build, estimate, simulate, and review continuous-time and individual-level multistate models for health economic evaluation in R, using flexsurv (fully-observed transition data), msm (panel/intermittent data), and hesim (individual-level simulation and CEA). Use whenever the person works with a multistate / state-transition model beyond a discrete-time cohort Markov model: several competing transitions, clock-forward vs clock-reset (Markov vs semi-Markov) timing, transition intensities, or continuous-time disease progression. Trigger on phrases like \"multistate model\", \"state-transition model\", \"transition intensities\", \"clock-reset\", \"clock-forward\", \"semi-Markov\", \"competing risks transitions\", \"illness-death model\", \"hesim\", \"msm package\", or \"IndivCtstm\". For a simple discrete-time cohort Markov model use decision-modelling-hta; for full event-history simulation with queueing/resources use discrete-event-simulation-hta; this skill is the continuous-time / individual-level generalisation in between."
---

# Multistate models for HTA (continuous-time & individual-level)

Continuous-time and individual-level multistate modelling for economic evaluation, in R, following R-HTA chapter 11.

> Sources: *R for Health Technology Assessment* (Baio et al., online at <https://gianluca.statistica.it/books/online/r-hta/>) — chapter mapping verified against the live ToC (Ch. 11 = multistate models; authors include Incerti and Jackson), accessed 2026-07-03; the chapter's hesim/msm/flexsurv toolchain confirmed. Package signatures (`msm`: `statetable.msm()`, `msm()`, `pmatrix.msm()`; `hesim`: `hesim_data()`, `expand()`, `create_IndivCtstmTrans()`, `stateval_tbl()`, `create_StateVals()`, `IndivCtstm$new()` and its `$sim_*` methods; `flexsurv` multistate) cross-checked against CRAN/pkgdown docs, accessed 2026-07-03. This generalises the discrete-time cohort Markov model (the `decision-modelling-hta` skill) along three axes: discrete→continuous time, cohort→individual-level simulation, and Markov→semi-Markov. It reuses the parametric survival fitting from the `survival-analysis-hta` skill — each transition is a time-to-event model — so read that skill's flexsurv guidance for the fitting details and keep this skill for the multistate structure, estimation routes, and simulation.

## The core concepts (get these right before any code)

A continuous-time multistate model is defined by **transition intensities** `q_rs(t)` — the instantaneous rate of moving from state r to state s — collected in a **transition intensity matrix Q** (off-diagonals are the rates; each row sums to zero, so the diagonal is the negative row-sum). An intensity is a rate, not a probability: it can exceed 1, and only over a time interval does it become a transition *probability* (`P(u) = Exp(uQ)`, the matrix exponential — not the elementwise exponential).

Two timing choices, and they change the model fundamentally:
- **Clock-forward** (time = time since model start): the model is **Markov** — future progression depends only on current state and time-in-model.
- **Clock-reset** (time resets to zero on entering each state): the model is **semi-Markov** — the intensity depends on time-in-*state* (sojourn time).

The single most consequential modelling decision in this chapter is clock-forward vs clock-reset, because it changes what the fitted time-to-event models mean and how `hesim` simulates. Pick it on disease logic: does the risk of the next event depend on how long the patient has been in their *current* state (→ clock-reset/semi-Markov, e.g. time since recurrence drives cancer death) or on total time since the start (→ clock-forward/Markov, e.g. age-driven background mortality)? A `clock = "mix"` option lets different transitions use different clocks.

## Which estimation route — the decisive question is your data

This is the fork that determines everything downstream:

- **Fully-observed (continuously-observed) transition data** — you know each patient's state at all times, so every r→s transition time is known (or right-censored). → Fit a **separate survival model per transition** with `flexsurv` (the `survival-analysis-hta` skill's fitting applies directly). This is the more flexible route: any parametric or spline distribution, and clock-reset is natural. Use this when you have it.
- **Panel / intermittently-observed data** — you only know state occupancy at scattered observation times, so you *don't* know exactly when transitions happened (a patient seen in state 1 then later in state 3 must have passed through state 2 at some unknown time). → Use `msm`, which assumes **time-homogeneous (constant) intensities** — i.e. exponential sojourn times, or piecewise-exponential with time-dependent covariates. Stronger assumptions, less flexibility, because there's less information in the data.

See `references/estimating-multistate.md` for the data layout each route needs (the per-transition long format with competing-risk censoring and left-truncation for flexsurv; the state/time/subject panel format for msm) and worked fitting code for both.

## Simulation and CEA with hesim

`hesim` runs the individual-level continuous-time simulation (it's C++-backed, because individual continuous-time simulation is slow in base R) and feeds `BCEA` for the cost-effectiveness analysis. The pipeline, regardless of estimation route:

1. **Set up the model skeleton**: `hesim_data()` (strategies, patients, states — only *non-absorbing* states go in the `states` table; hesim adds absorbing/death states from the transition matrix), then `expand()` to one row per strategy×patient.
2. **Build the transition model**: `create_IndivCtstmTrans()` from either a `flexsurvreg_list()` (fully-observed route) or a `params_surv_list()` of `params_surv()` objects (externally-estimated parameters, e.g. msm rates or an NMA), plus the `trans_mat`, `clock`, `n` samples, and `start_age`.
3. **Build state values**: `stateval_tbl()` + `create_StateVals()` for utilities and (separately) each cost category.
4. **Combine and simulate**: `IndivCtstm$new(trans_model, utility_model, cost_models)`, then `$sim_disease()` → `$sim_stateprobs()` / `$sim_qalys(dr=)` / `$sim_costs(dr=)`.
5. **Analyse**: `$summarize()` → reshape to cost/effect matrices → `BCEA::bcea()`.

See `references/hesim-simulation.md` for the full worked pipeline including the `stateval_tbl` construction (which is fiddly) and the route for plugging in msm/NMA parameters via `params_surv_list`.

For discount rates, willingness-to-pay thresholds, and the probabilistic-analysis-as-base-case principle (these models are non-linear, so deterministic point estimates are biased — run probabilistic by default, and call it "probabilistic analysis" not "PSA"), defer to the **`nice-economic-evaluation`** skill.

## Choosing the model structure: multistate vs partitioned survival vs cohort Markov

A recurring decision in oncology especially:
- **Cohort Markov (discrete-time)** — simplest; use when a cohort-average over discrete cycles is adequate and you don't need individual history or continuous time. → `decision-modelling-hta`.
- **Multistate (this skill)** — when transitions between several states are the natural description, you have transition-level data, and time-in-state or individual heterogeneity matters. Estimates the *actual transition rates*.
- **Partitioned survival (PSM)** — when you only have OS and PFS curves (no transition-level data), common for published-data comparators. Reads state membership off independently-extrapolated curves (see `survival-analysis-hta`). Its weakness is exactly that independence: nothing constrains extrapolated OS ≥ PFS, and it sidesteps estimating the pre-death progression rate. Recent methods recover transition rates from OS/PFS ties, weakening the case for PSM where multistate is feasible.

The book's bottom line, worth passing on: where fully-observed data on all transitions and strategies exist, a **clock-reset multistate model with flexible survival distributions is the preferred option** — but that ideal data situation is rare, which is why the panel-data (`msm`) and PSM routes exist.

## Common pitfalls

- **Choosing the Q structure from `statetable.msm()` counts.** Jackson's own guidance: the permitted-transition structure must come from *scientific judgement about what's possible in continuous time*, not from which cells of the observed-transition table happen to be non-zero. An observed "1→3" in panel data doesn't mean a direct 1→3 intensity exists — the patient likely passed through state 2 unobserved.
- **Putting covariate effects on transitions the data can't identify.** With sparse panel data, a treatment effect on a rarely-observed transition (e.g. only 2 observed events) gives wildly wide CIs or a fitting failure. Tabulate with `statetable.msm()` first, and exclude implausible parameters using background knowledge (e.g. treatment doesn't affect non-cancer death) rather than estimating everything.
- **Confusing intensities with probabilities.** `q_rs` is a rate; don't drop it into a discrete-time transition matrix as if it were `p_rs`. Convert via the matrix exponential (`pmatrix.msm()` does this for msm fits) over a defined interval.
- **Clock mismatch when importing external parameters.** `msm` produces *clock-forward* (Markov, constant-rate) estimates — when feeding these to `hesim` via `params_surv_list`, set `clock = "forward"`, not `"reset"`. Mismatching the clock to how the rates were estimated silently corrupts the simulation.
- **Forgetting the absorbing-state convention in hesim.** The `states` table lists only non-absorbing states; death/absorbing states are inferred from the transition matrix. Listing them explicitly will misalign the state indexing.
- **Deterministic base case.** Multistate cost/QALY functions are non-linear, so a deterministic run with point estimates is biased — run probabilistic as the base case.

## Validating the model before trusting it

`scripts/check_multistate_setup.R` checks a proposed multistate model's structural pieces *before* the expensive simulation: that the transition matrix is consistent (absorbing states have no outgoing transitions, transition IDs are consecutive, dimensions match the state names), that an intensity matrix Q (if supplied) has rows summing to zero, and that the number of fitted transition models matches the number of permitted transitions. Run it after defining the structure and before `create_IndivCtstmTrans()` — a misnumbered transition matrix produces a simulation that runs but is silently wrong.
