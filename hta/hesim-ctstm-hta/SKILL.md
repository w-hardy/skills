---
name: hesim-ctstm-hta
description: "Build, debug, run, and validate an individual-level continuous-time CTSTM (hesim IndivCtstm) for a health economic evaluation — implementation depth, not concepts. Use when writing or fixing hesim engine code: assembling create_IndivCtstmTrans() from flexsurvreg_list()/params_surv_list(); mixing clock-reset and clock-forward transitions (clock=\"mix\" vs \"mixt\"); wiring age-varying background mortality as a pwexp death transition with state-specific SMRs; PSA via define_rng()/create_params(); running sim_disease()/sim_qalys()/sim_costs() and the native CEA (cea()/cea_pw() for CEAC/CEAF/EVPI/ICER); or diagnosing a run that errors, returns NA life-years, double-counts arms, or silently uses background mortality. Triggers: hesim, IndivCtstm, params_surv_list, pwexp mortality, clock mixt, stateval_tbl, define_rng, cea_pw, CTSTM CEA. Defer concepts to multistate-models-hta, transition fitting to survival-analysis-hta, reference case to nice-economic-evaluation, EVPPI/EVSI to bayesian-cea-r-hta."
---

# hesim CTSTM implementation (EXPO extension)

The implementation-depth companion for building the EXPO individual-level continuous-time state-transition model (IndivCtstm) in hesim. This skill is about *writing and trusting the engine code*: the two parameterisation routes and how to mix their clocks, mortality as an in-matrix pwexp transition with SMRs, probabilistic analysis, and the validation ladder that lets you believe a run.

> **Sources & provenance.** hesim **0.5.8** (the installed EXPO version). API confirmed against **full-text reads** of five vignettes dated 2026-01-16 (`intro`, `mstate`, `markov-inhomogeneous-indiv`, `markov-inhomogeneous-cohort`, `cost-effectiveness-analysis`) plus the `params_surv`/`cea` reference pages on <https://hesim-dev.github.io/hesim/> (accessed 2026-07-09). Two provenance tiers are used throughout, and every code claim is tagged one way or the other:
> - **[vignette]** — confirmed in the hesim 0.5.8 docs/vignettes. Stable across the API.
> - **[EXPO 0.5.8]** — a wall hit and resolved *in the EXPO build* on this hesim version (from the migration record and the Stage-1 register). Re-verify on any hesim upgrade; these are the ones most likely to drift.
>
> **hesim is THE production engine.** heemod has been retired; do not treat a heemod result as a live parity target. Where the validation ladder mentions heemod it is a *migration-phase* check that retires with it. `decision-modelling-hta` is retained only for the discrete-time *conceptual* contrast, not as a runnable reference.
>
> This skill is the sibling of `multistate-models-hta`. That skill owns the **concepts and structure** (transition intensities, clock semantics, flexsurv-vs-msm estimation fork, multistate-vs-PSM-vs-cohort choice). This skill owns the **implementation** for one specific target: the EXPO IndivCtstm. When both are in context, read the concept in the sibling and the code here.

## Where this skill sits — read first

Do not restate multistate theory here. Before touching engine code, the conceptual decisions (which structure; which clock *per transition* on disease logic; whether the data supports the transition at all) should already be settled — that is `multistate-models-hta` plus the Stage-1 register. This skill starts from *"the structure is decided; now build it correctly in hesim 0.5.8."*

The EXPO engine is **one IndivCtstm, candidates as configurations** (c3 / c3b-recommended / awttc-anchor / c6). Build and validate the engine once; select the candidate by configuration. Do not fork an engine per candidate.

## The pipeline spine

The IndivCtstm build order (each step links to a reference for the fiddly parts):

1. **Skeleton** — `hesim_data(strategies, patients, states)`, then `expand(hesim_dat, by = c("strategies","patients"))`. Only **non-absorbing** states go in `states`; hesim infers Death/absorbing from the transition matrix. Listing Death explicitly misaligns the indexing. **[vignette]**
2. **Transition model** — `create_IndivCtstmTrans()` from a `flexsurvreg_list()` (trial-fitted transitions) **or** a `params_surv_list()` of `params_surv()` objects (externally-parameterised transitions, incl. the pwexp mortality) — one object per call; to mix routes, convert fits via `create_params()` into a single `params_surv_list` (see below) — plus `trans_mat`, `clock`, `n`, `start_age`. For fitted objects, `uncertainty = "normal"` (MVN of the MLE) is the default. **[vignette]**
3. **State values** — `stateval_tbl(..., dist = "beta"/"gamma"/"fixed")` → `create_StateVals(tbl, n =, hesim_data =)` — the `hesim_data` argument is required when the table doesn't carry full ID columns — one for utilities and one per cost category. In individual-level models a StateVals can itself be clock-reset (`time_reset = TRUE`), and one-off costs use `method = "starting"` vs ongoing `method = "wlos"`. **[vignette]**
4. **Simulate** — `IndivCtstm$new(trans_model, utility_model, cost_models)` → `$sim_disease(max_t=, max_age=)` → `$sim_stateprobs(t=)` / `$sim_qalys(dr=)` / `$sim_costs(dr=)`. Two defaults that bite: **`max_age` defaults to 100** (patients are killed at 100 unless raised — interacts with any attained-age mortality axis), and the discount rate is set **here** (`dr=`), not at the CEA step. **[vignette]**
5. **Analyse** — `$summarize()` returns a `ce` object that hesim's own `cea()` / `cea_pw()` consume directly, no reshape. This is the decision layer — see below.

Full worked pipeline with the `stateval_tbl` index construction: `references/parameterisation-and-clocks.md`.

## Decisive choice 1 — which parameterisation route, per transition

Each transition is parameterised by exactly one of two routes, and EXPO uses **both in one engine**:

- **`flexsurvreg_list()`** — transitions fitted from trial/linked person-time (treatment-status retention, discontinuation). Clock-**reset** is `Surv(years, status) ~ ...`; clock-**forward** is `Surv(Tstart, Tstop, status) ~ ...`. The distinction is baked into the fit, not just the `clock=` string. **[vignette]**
- **`params_surv_list()`** of `params_surv(coefs, dist, aux)` — transitions parameterised *outside* a flexsurv fit: msm-derived use-transition intensities (exponential/piecewise), and the background mortality pwexp. `coefs` is a list (one matrix per distribution parameter); **PSA uncertainty lives in those matrices' rows, there is no `uncertainty=` argument on `params_surv`.** **[vignette]**

**Mixing the routes — the part the vignettes don't spell out:** `create_IndivCtstmTrans()` takes **one** object, not both. To combine fitted and hand-built transitions in one engine (EXPO does), convert each flexsurv fit with `create_params(fit, n, uncertainty = "normal")` and assemble everything into a **single `params_surv_list`**. **[EXPO 0.5.8]** This is precisely where the coef-name and no-`uncertainty`-arg gotchas bite (see below). The reference walks the assembly, the `vec_to_dt()`/`as_dt_list()` coefficient shaping, and the helper patterns (`prob_to_rate()` for probability→rate conversion; rates **add on the natural scale** before logging, e.g. operative + background mortality). **[vignette]**

## Decisive choice 2 — clocks, and the coexisting-death-edges question (the crux)

EXPO needs *different clocks on different transitions in one model*: retention/discontinuation are clock-**reset** (risk depends on time-in-state), background mortality is clock-**forward** on **attained age**. That forces a per-transition clock, and the string matters:

- `clock = "mix"` — mixes **per origin state** (all transitions out of a state share a clock).
- `clock = "mixt"` — mixes **per transition** (each transition carries its own clock). **EXPO requires `"mixt"`** because reset-retention and forward-mortality leave the *same* origin state. **[EXPO 0.5.8]** — this was the D4 resolution; the model must be spiked, not assumed, because the earlier attempt used per-state `"mix"` and silently mis-clocked mortality.

**The open design question this skill exists to answer** (D4 / P2b, same question): can a **reset-clock death edge** and a **forward-clock (age) death edge** coexist on **one origin state** under `clock = "mixt"`? If yes, model peri-discontinuation mortality as a native reset death edge (no sub-state). If no, the *evidenced* fallback is an early-exit sub-state (e.g. `OffTx_early`) carrying the elevated first-4-weeks-off rate — "the framework forced it" beats "we chose it". **Do not assume either way — spike it against the installed 0.5.8 first.** This generalises: whenever two transitions on one origin need different time-scales, test coexistence empirically before committing a structure. See `references/parameterisation-and-clocks.md`.

## Decisive choice 3 — mortality is a transition, not an overlay

Background mortality is a **pwexp death transition inside the intensity matrix**, not a post-hoc survival multiplier. The recipe:

- `params_surv(coefs = as_dt_list(log_mr), aux = list(time = <breakpoints>), dist = "pwexp")`. The `aux$time` breakpoints for an age-based death edge are **absolute attained age**, not model time — so the axis must extend to the oldest attainable age (≈110 for an ONS lifetable) or the simulation under-runs the table and returns **NA** life-years. **[EXPO 0.5.8]** — a real wall; the fixed-axis version failed exactly here.
- **State-specific SMRs** multiply the pwexp death rate, resolved by a `paste0("smr_", mortality_key)` lookup so each state (on-treatment, off-treatment, recovered, peri-exit tunnel, prison, post-release) scales background mortality by its own relative-mortality key. Scaling is log-additive on the rate. **Never fitted from EXPO** — SMR *values* come from the evidence note; this skill covers the *mechanism*.
- **Fail loud on an unresolved key.** An unmatched `mortality_key` must make the production gate object, not silently fall back to `1` (background). A fail-*quiet* resolver is the trap; converting it to fail-*closed* is the fix. **[EXPO 0.5.8]**

Full recipe, the tunnel/prison keys, and calibrating the in-treatment mortality *level* against external targets: `references/pwexp-mortality-smr.md`.

## Probabilistic analysis — uncertainty is in the coefficients

Because `params_surv` has no `uncertainty=` arg, PSA is assembled upstream:

- **`define_rng({ ... }, n = N)`** draws the sampled parameters — `beta_rng()`, `gamma_rng()`, `multi_normal_rng(mu, Sigma)` for correlated blocks, `fixed(values, names = age_lower)` for age-indexed background rates. Correlated SMR/parameter draws go through `multi_normal_rng`; document independence where blocks are drawn separately. **[vignette]**
- **`create_params(fit, n, uncertainty = "normal")`** draws the flexsurv-fitted retention half from each fit's MVN. This is the one place a non-positive-definite vcov surfaces; the non-PD fallback route lives here. **[EXPO 0.5.8]**
- **Common random numbers** — pair the randomness across arms so incremental NMB is a difference of *correlated* runs; this is what makes INMB converge in a sane number of samples. hesim documents **no CRN guarantee across strategies** within one `$sim_disease()` call — the working per-draw seeding pattern (and how to verify it's taking effect) is in the reference. **[EXPO 0.5.8]**

Correlated-block spec, CRN seeding, and INMB-convergence checking: `references/psa-cea-and-validation.md`.

## The decision layer — hesim computes most of the CEA natively

`$summarize(by_grp =)` returns a `ce` object (draws of cost and effect by `sample` × `strategy` × `grp`); hesim's own functions turn it into decision outputs **without leaving the framework or reshaping to BCEA**. `cea()`/`cea_pw()` are generics: on a `ce` object select the discount rates with `dr_qalys =`/`dr_costs =`; on a raw `data.table` name the columns (`sample=`, `strategy=`, `grp=`, `e=`, `c=`). **[vignette]**

- **`cea(ce, k = seq(0, ktop, 500), sample = "sample", strategy = "strategy", grp = ...)`** — all-strategy summary + the cost-effectiveness frontier over the WTP grid `k`.
- **`cea_pw(ce, k = ..., comparator = "<reference strategy>", ...)`** — pairwise vs a reference; `cea_pw_out$delta` holds the incremental cost/effect draws, `cea_out$evpi` the EVPI.
- **`icer(cea_pw_out, k = 50000)`** — the ICER / incremental-QALY / incremental-cost / INMB table at a threshold.
- **`plot_ceplane()`, `plot_ceac()`, `plot_ceaf()`, `plot_evpi()`** — the standard four, straight off the `cea`/`cea_pw` output.
- **`grp`** gives per-subgroup (individualised) CEA — EXPO's severity / episode-≥28d / opioid-vs-polysubstance subgroups drop in here, no bespoke code.

The boundary with `bayesian-cea-r-hta`: hesim gives you **INMB, CEAC, CEAF, EVPI, ICER, CE-plane** natively. It does **not** compute **EVPPI or EVSI** — for the partial/sample value-of-information the register asks for (F8), reshape the `ce` draws and hand to **BCEA**. EXPO's `ctstm_inmb` / `ctstm_ce_incremental` helpers wrap this native layer with CRN and convergence rather than replacing it. Worked calls in `references/psa-cea-and-validation.md`.

## Validate before you trust a run

Non-linear cost/QALY functions mean a deterministic point run is biased — probabilistic is the base case (defer to `nice-economic-evaluation` for that principle). Beyond that, EXPO uses a **validation ladder**, in order:

1. **Hazard-shape diagnostics** — before any economic output, build a point-estimate transition model (`uncertainty = "none"`) for a representative patient and inspect `$hazard(t=)` / `$cumhazard()` / `$stateprobs()` per transition: right shapes, right ordering, reset-vs-forward differences where expected. Cheap, catches mis-wired transitions early. **[vignette]**
2. **Analytic equivalence** — the pwexp background mortality must reproduce the closed-form background survival (RMST-relative tolerance, shrinking with sample size). This is the error-detector for the mortality spine. **[EXPO 0.5.8]**
3. **Within-trial reproduction** — reproduce the 24-week within-trial incrementals before trusting any extrapolation.
4. **Horizon sanity** — ≤1% of the cohort alive at the lifetime horizon.
5. **External targets** — reproduce national-statistic denominators (exit-reason proportions, mean successful-episode duration, retention) as structural validation, with the partial-dependence caveat.

`scripts/check_ctstm_build.R` runs the *structural* pre-flight (clock string valid, `aux` age axis covers the lifetable, coefficient names align, every `mortality_key` resolves, transition count matches permitted transitions) **before** the expensive simulation — a misnumbered matrix or a short age axis runs but is silently wrong. It complements (does not duplicate) the sibling skill's `check_multistate_setup.R`, which handles transition-matrix/Q consistency; run that first.

## The gotchas that cost real time

Catalogued with fixes in `references/api-gotchas.md`. The recurring ones **[EXPO 0.5.8]**:

- **Coefficient names must match the fitted model.** A hand-built intercept coef must use the fit's own names (`(Intercept)`, `armsoc`), not a generic `cons` — a name mismatch mis-maps silently.
- **Average the survival metric over arms.** Summing across arms double-counts and produces a spurious `max|Δ| = 1.0` — a red herring, not a real discrepancy.
- **`params_surv` takes no `uncertainty` arg** (see PSA above) — putting it there is a silent no-op.
- **`max_age` defaults to 100** — individuals are truncated at age 100 unless `$sim_disease(max_age=)` is raised; must be consistent with the mortality age axis. **[vignette]**
- **Fail-quiet resolver gaps** — an unresolved key that defaults to background mortality is a fail-*quiet* hole; make it fail-closed.
- **Load-order fragility** — a stale build stub shadowed only by source order is harmless until it isn't; remove shadowed stubs when convenient.

## Cross-references

- `multistate-models-hta` — **up**: concepts, clock semantics, estimation-route fork, structure choice, `check_multistate_setup.R`.
- `survival-analysis-hta` — fitting each transition (parametric/spline/pwexp choice, extrapolation).
- `nice-economic-evaluation` — reference case, discounting, PSA-as-base-case, severity.
- `bayesian-cea-r-hta` — **only** for what hesim's native `cea()` doesn't do: EVPPI/EVSI partial-VOI and BCEA-specific presentation. INMB, CEAC/CEAF, EVPI, ICER and the CE plane stay here (see the decision layer).
- `ispor-smdm-good-practices` — the validation ladder maps to its verification/technical-validation taxonomy.
