---
name: decision-modelling-hta
description: "Build, review, or debug decision-analytic models for health economic evaluation (decision trees and cohort Markov models) in R using the heemod package. Use whenever the person is structuring a cost-effectiveness model, comparing strategies over a decision tree or Markov state structure, calculating ICERs/INMB, setting up transition probabilities (including from survival models), or running probabilistic sensitivity analysis (PSA). Trigger on phrases like \"decision tree\", \"Markov model\", \"transition matrix\", \"transition probabilities\", \"cohort model\", \"heemod\", \"state-transition model\", or \"cost-effectiveness model\", even if heemod is not named, since most of this work goes through it. Also trigger when reviewing or extending an existing heemod model, or deciding whether a decision tree or Markov structure fits a pathway. Not for continuous-time multistate models or discrete event simulation (see multistate-models-hta and discrete-event-simulation-hta); heemod here is cohort-level, discrete-time only."
---

# Decision modelling for HTA (decision trees & cohort Markov models)

This skill covers the two foundational decision-analytic model types in HTA — decision trees and cohort Markov models — built in R with the `heemod` package. Based on R-HTA chapters 8 and 9 (decision trees; cohort Markov models), reworked to use `heemod`'s declarative workflow rather than hand-rolled base-R arrays/recursion, since that's faster to build and less error-prone for routine modelling work.

> Sources: *R for Health Technology Assessment* (Baio et al., online at <https://gianluca.statistica.it/books/online/r-hta/>) — chapter mapping verified against the live ToC (Ch. 8 = decision trees, Ch. 9 = cohort Markov models), accessed 2026-07-03. The book itself builds both model types **by hand in base R** (forward/fold-back tree evaluation; array-based transition matrices), using `heemod` only to draw the state-transition diagram (`define_transition()` + `plot()`) — this skill's heemod-native workflow is a deliberate deviation, as stated above. Method claims (rate↔probability conversion, probabilistic base case, matrix constraints) verified against Ch. 9 §9.3.2 and §9.6. heemod function signatures cross-checked against the CRAN reference manual, accessed 2026-07-03.

> **Version note.** heemod's actively maintained development happens on the aphp fork (`aphp/heemod`, currently ~1.1.0), which is ahead of the CRAN release. Function signatures here follow the current docs, but verify against the installed version's `?function` help before relying on an exact argument — heemod has renamed arguments across versions (e.g. `transition_matrix` → `transition`), and the survival/PSA functions in particular have evolved. When in doubt, run the relevant package vignette (`vignette("e_probabilistic", "heemod")`, `vignette("j_survival", "heemod")`) against the installed version first.

## Why heemod, and when it's the wrong tool

`heemod` represents a model as four pieces — parameters, a transition matrix, state values, and a strategy — and evaluates them together with `run_model()`. A decision tree is just a one-cycle Markov model in this framework, so the same machinery covers both. This buys PSA, discounting, deterministic sensitivity analysis (DSA), and CE-plane/CEAC plotting almost for free once the model is specified, rather than writing all of that by hand.

It is the wrong tool when:
- The model needs to track *individual* heterogeneity or time-since-state-entry beyond what `state_time`/`model_time` tunnel states can express cleanly — that's `hesim`'s territory (continuous-time, individual-level; see the multistate-models-hta skill).
- Events, not states, are the natural unit of the model, or queueing/resource constraints matter — that's discrete event simulation.
- The decision is genuinely a one-off, short-horizon choice with no repeating events — a plain decision tree (still doable in heemod as a 1-cycle model) may be all that's needed; don't reach for a 50-cycle Markov model just because it's available.

## Choosing tree vs. Markov

Ask: **does anything repeat, and does time-since-decision matter?**
- No repeat events, short horizon (e.g. a single diagnostic pathway, a single treat/don't-treat decision with an immediate outcome) → **decision tree**.
- Possible recurrence, ongoing risk each period (disease progression, relapse/remission, ongoing mortality risk) → **Markov model**.
- A common real pattern: a decision tree for the *immediate* decision (e.g. test result → treatment choice) feeding into a Markov model for the *long-term* consequences. These can be chained — a tree's terminal node becomes the starting distribution for a Markov model.

If recurrence is possible and you're tempted to model it by duplicating tree branches, stop — that's the "bushy tree" anti-pattern; use a Markov state with a self-loop instead.

## The heemod workflow

Four building blocks, always in this order:

1. **`define_parameters()`** — anything you want to vary in PSA/DSA, or that depends on `model_time` (cycle number) or `state_time` (time since entering current state), goes here. Point estimates that will never be varied can be hard-coded directly into the transition matrix or state definitions instead, but if in doubt, parameterise it.
2. **`define_transition()`** — the transition probability matrix, row = state at cycle start, column = state at cycle end. Rows must sum to 1. Use `C` as shorthand for "1 minus everything else in this row" (heemod's complement operator) rather than writing it out — it's clearer and self-checking.
3. **`define_state()`** (one per state) — costs, utilities, and any other per-cycle values attached to that state, in the same units as one cycle.
4. **`define_strategy()`** then **`run_model()`** — combine a transition matrix with its states into a strategy per treatment arm, then run all strategies together with shared `parameters`, `cycles`, `cost`, and `effect` arguments.

See `references/heemod-markov-models.md` for a full worked Markov example (time-homogeneous → time-inhomogeneous with survival-derived transitions) and `references/heemod-decision-trees.md` for the decision-tree-as-1-cycle-model pattern. Read whichever matches the task before writing code — the worked examples show the exact argument shapes that are easy to get subtly wrong (e.g. row/column order, `C` placement, state value naming consistency across strategies).

## Survival-derived transition probabilities

This is the part of decision modelling most likely to come up given W's EXPO survival work. Two ways to feed survival-model output into a transition matrix:

- **Manual conversion**: fit the survival model however you normally would (`flexsurv`, `survival`), extract the cumulative hazard at cycle boundaries, and convert to a conditional transition probability: `p_t = 1 - exp(-(H(t) - H(t-1)))`. This is what the book does by hand and gives full control — necessary when a transition's probability depends on a *cure* fraction, a *mixture*, or anything `heemod`'s built-in survival objects don't cover directly.
- **`compute_surv()` from a fitted model**: heemod's `compute_surv(fit, time = model_time, type = "prob")` takes a fitted survival model (e.g. from `flexsurv::flexsurvreg()`) or a parametric form built with `define_surv_dist()`, and returns the conditional cycle-to-cycle transition probability — the packaged equivalent of the manual conversion above. Prefer this when the survival model is a standard parametric form, since it removes the hand-rolled hazard-to-probability step where off-by-one errors hide.

Either way, transition probabilities that depend on `model_time` make the model time-inhomogeneous automatically in heemod — no separate "mode" to switch on, you just reference `model_time` inside `define_parameters()` or directly in the transition matrix cell.

For fitting the survival models themselves and propagating their parameter uncertainty into these transition probabilities, see the `survival-analysis-hta` skill.

## Cost-effectiveness outputs, discounting, and thresholds

`run_model()` with `cost` and `effect` arguments gives total discounted cost and effect per strategy directly. For ICER, INMB, discount rates, and willingness-to-pay thresholds — **use the conventions in the `nice-economic-evaluation` skill** rather than picking values ad hoc here; that skill has the current PMG36 discount rate and threshold ranges. heemod's `discount()` function applies a rate but doesn't choose one for you.

## Probabilistic sensitivity analysis

PSA in heemod means: re-specify the relevant parameters via `define_psa()` with a resampling distribution attached to each as a **formula** (`param ~ distribution(...)`), then call `run_psa(model, psa, N)`. Use heemod's built-in density functions — but **watch the parameterisations, which differ by distribution**: `gamma(mean, sd)` and `normal(mean, sd)` take mean/sd directly, `lognormal()` accepts natural- or log-scale, `binomial(prob, size)` takes a point probability plus effective sample size, and `beta(shape1, shape2)` takes **shape parameters, not mean/sd** (a common error). For a probability where you only have a mean and sd, `binomial(prob, size)` is the easier idiomatic choice. `define_distribution()` is only for *user-supplied* density functions (e.g. an MCMC posterior) — it is not the normal path. The reference files give the full table and worked calls.

For distribution *choice* (which family for which parameter type) — **defer to the `nice-economic-evaluation` skill's conventions** if there's any conflict, rather than re-deriving them here. The one structural rule worth stating up front: the several outgoing probabilities from a single state share a simplex constraint (must sum to ≤1), so model them jointly with `multinomial(...)` rather than as independent draws. Correlated parameters from the same regression (e.g. a survival model's joint parameter uncertainty, or cause-specific log-rates) need a correlation structure passed as the `correlation =` argument of `define_psa()`. That argument accepts **either** the output of `define_correlation(par1, par2, rho, ...)` **or** a plain correlation matrix directly (`correlation = matrix(...)`) — both are supported (heemod CRAN docs; Antoine Filipović-Pierucci et al., *heemod* JSS/arXiv §4.1, verified 2026-07-03). Only the correlated pairs need specifying; independence is the default and is often wrong for parameters that came out of the same fit.

After `run_psa()`, `summary()` and `plot(psa_res, type = "ce")` give the CE-plane/CEAC from heemod directly, or hand the costs/effects to `BCEA::bcea()` if W wants BCEA's specific plots — both read from the same underlying samples.

## Common pitfalls (check these before trusting output)

- **Rows must sum to exactly 1.** A matrix that's off by floating-point error (e.g. `1 - sum(other probs)` going slightly negative) will error or silently misbehave — use `C` instead of computing the complement by hand wherever possible.
- **Absorbing states need a self-transition of 1** (or `C` in the corresponding cell with everything else in that row set to 0) — don't leave a dead/cured state with an undefined row.
- **State names and state-value names must match exactly across all strategies being compared in `run_model()`** — heemod requires this to compute incremental results; a typo here fails loudly, but a near-typo (extra space, different case) can fail confusingly.
- **`model_time` starts at 1, not 0**, and the cycle in which a `model_time`-dependent transition first applies depends on `method = "beginning"` vs `"end"` in `run_model()` — check which convention matches how the source probabilities were derived (the book's hand-rolled examples are typically "beginning of cycle").
- **Half-cycle / within-cycle correction**: heemod's `method` argument (`"life-table"`, `"beginning"`, `"end"`) handles this — pick one and say which, rather than leaving it at the default unconsidered, since "beginning" overestimates and "end" underestimates costs.

## Validating a transition matrix before running the model

`scripts/check_transition_matrix.R` takes a heemod transition object (or a plain square numeric matrix) and checks: square, rows sum to 1 (within tolerance), no negative entries, absorbing states correctly self-looped. Run this on any newly-specified or edited matrix before calling `run_model()` — catching a row-sum error here is much faster than debugging it from a nonsensical ICER.
