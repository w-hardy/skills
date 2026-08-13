# PSA, the native CEA layer, and validation (hesim 0.5.8)

Provenance: **[vignette]** confirmed in the 0.5.8 vignettes; **[EXPO 0.5.8]** observed in the EXPO build.

## 1. PSA — uncertainty is assembled upstream of `params_surv`

Because `params_surv` carries no `uncertainty=` argument, PSA parameters are drawn first and fed in as sampled coefficient tables.

```r
rng_def <- define_rng({
  list(
    smr_block  = multi_normal_rng(mu = smr_logmu, Sigma = smr_logvcov),  # correlated SMRs
    u          = beta_rng(mean = u_mean, sd = u_se),                     # utilities
    c_med      = gamma_rng(mean = c_med_mean, sd = c_med_se),            # costs
    mr_female  = fixed(mr$female, names = mr$age_lower),                 # lifetable: known
    rr_coef    = multi_normal_rng(mu = rr_coef, Sigma = rr_vcov)         # a fitted block
  )
}, n = n_samples)
params_rng <- eval_rng(rng_def, params = params)   # draws; or define_rng evaluates inline
```

- **`multi_normal_rng(mu, Sigma)`** is the mechanism for **correlated blocks** — the EXPO SMR correlation blocks and any jointly-estimated coefficients go through it. Draw independent quantities separately and **document the independence** (per-block correlation spec is a pre-specified decision, not a default). **[vignette]**
- **`fixed(values, names = age_lower)`** pins age-indexed lifetable rates (no uncertainty). **[vignette]**
- **`prob_to_rate(beta_rng(...))`** converts a sampled probability to a rate before it enters an `exp`/`pwexp` transition. **[vignette]**
- The **flexsurv-fitted half** is drawn *not* here but by `create_params(fit, n, uncertainty = "normal")` (MVN of the MLE) during the mixed-list assembly — the two PSA sources (define_rng for external params, create_params for fits) must share the **same `n`** and be aligned by sample index. **[EXPO 0.5.8]**

### Deterministic runs are biased

Cost/QALY functions are non-linear, so a point-estimate run is biased — **probabilistic is the base case** (`nice-economic-evaluation`). Use `uncertainty = "none"` only for hazard-shape diagnostics and analytic-equivalence checks, never for reported results.

## 2. Common random numbers (CRN)

Incremental NMB is a **difference of two arms**. If the arms consume independent randomness, the difference carries the sum of both variances and INMB converges slowly. Pairing the randomness across arms collapses the incremental variance toward true parameter uncertainty. **[EXPO 0.5.8]**

**Be honest about the mechanism: hesim 0.5.8 documents no CRN guarantee across strategies within a single `$sim_disease()` call.** Both strategies are simulated in one call over the expanded input data from one RNG stream, and whether draws end up paired across strategies is an internal detail — do not assume it. The working pattern (verify locally before relying on it — this is `[EXPO 0.5.8]` territory, not `[vignette]`):

```r
# generic pattern: fix the RNG state identically per PSA draw, per strategy
seed_for_draw <- function(s, base = 20260709L) base + s
for (s in seq_len(n_samples)) {
  for (strat in strategy_ids) {
    set.seed(seed_for_draw(s))          # SAME seed across strategies within a draw
    # ... simulate this (draw, strategy) slice ...
  }
}
```

The EXPO helpers (`ctstm_seed_for_draw`, `ctstm_inmb`, `ctstm_inmb_convergence`, `ctstm_ce_incremental`) implement exactly this and wrap `$summarize()` + `cea_pw()` around it — if you have them, use them rather than re-deriving the loop.

**Always verify the pairing empirically**: plot cumulative-mean INMB vs `n` with and without the seeding — paired runs should stabilise visibly faster, and per-draw incremental variance should shrink. If it doesn't, the pairing isn't taking effect.

**MEASURED on the EXPO build, hesim 0.5.8 (2026-07-09, `scripts/diag-crn-pairing.R`): the within-call pairing does NOT take effect.** Across 24 replicate simulations, arm-noise correlation (QALY) = **0.034** and the paired/unpaired incremental-INMB SD ratio = **0.895** (≈ no variance reduction) — simulating both strategies in one seeded `$sim_disease()` call does not pair individual-level draws across arms. Consequence: the seeding convention buys **reproducibility only**; incremental precision is bought with `n_individuals` (`mc_individuals`, sized via `ctstm_inmb_convergence()`). A true-CRN design (per-strategy simulation calls re-seeded identically) is the registered future option if variance reduction is ever needed. Re-measure on any hesim upgrade. **[EXPO 0.5.8]**

## 3. The native CEA layer — hesim does most of it

`$summarize(by_grp =)` → a `ce` object; `cea()`/`cea_pw()` consume it directly. **[vignette]**

```r
ce  <- ictstm$summarize(by_grp = TRUE)
wtp <- seq(0, 200000, 500)                       # WTP grid; use the PMG36 range for EXPO

cea_out    <- cea(ce,    dr_qalys = 0.035, dr_costs = 0.035, k = wtp)   # all strategies + frontier
cea_pw_out <- cea_pw(ce, comparator = "SoC",     dr_qalys = 0.035, dr_costs = 0.035, k = wtp)

icer(cea_pw_out, k = 30000, labels = labs) |> format()   # incr QALYs / costs / INMB / ICER
plot_ceplane(cea_pw_out, k = 30000)
plot_ceac(cea_out)      # simultaneous CEAC (mce element)   |  plot_ceac(cea_pw_out) pairwise (ceac)
plot_ceaf(cea_out)      # frontier: strategy with highest E[NMB]
plot_evpi(cea_out)      # cea_out$evpi
```

On a `ce` object, discounting is selected with **`dr_qalys=`/`dr_costs=`** (the run may hold multiple `dr` values); on a raw `data.table`, name columns instead (`sample=`,`strategy=`,`grp=`,`e=`,`c=`). **[vignette]**

Outputs available directly: `cea_pw_out$delta` (incremental cost/effect draws → CE plane), `cea_out$evpi`, the `ceac`/`mce`/`ceaf`/`best` elements. `grp` gives **per-subgroup (individualised) CEA** — EXPO's severity / episode-≥28d / polysubstance subgroups need no bespoke code. **[vignette]**

### What hesim does NOT do → hand to BCEA

hesim gives **INMB, CEAC, CEAF, EVPI, ICER, CE-plane, EVIC** (value of individualised care, `plot`/manual). It does **not** compute **EVPPI or EVSI**. For the partial/sample value-of-information the register (F8) wants, reshape the `ce`/`delta` draws to BCEA's matrix form and use `bayesian-cea-r-hta` (`BCEA::evppi()` / `evsi`). Total EVPI across subgroups is a weight-weighted mean of `cea_out$evpi` by group. **[vignette]**

## 4. The validation ladder (in order)

1. **Hazard-shape diagnostics** — point-estimate (`uncertainty="none"`) transition model; inspect `$hazard(t=)`/`$cumhazard()`/`$stateprobs()` per transition for a representative patient. Catches mis-wired transitions before any economic output. **[vignette]**
2. **Analytic background equivalence** — pwexp mortality vs closed-form background survival, RMST-relative tolerance shrinking with `n`. The mortality error-detector. **[EXPO 0.5.8]**
3. **Within-trial reproduction** — reproduce the 24-week within-trial incrementals before trusting extrapolation. **[EXPO 0.5.8]**
4. **Horizon sanity** — ≤1% of the cohort alive at the lifetime horizon. **[EXPO 0.5.8]**
5. **External structural targets** — national-statistic denominators (exit-reason proportions, mean successful-episode duration, retention) reproduced as structural validation, with the partial-dependence caveat (same-system aggregates ≠ fully independent). **[EXPO 0.5.8]**

Run `scripts/check_ctstm_build.R` for the **structural** pre-flight before any of the above — it is cheap and catches the silent-but-wrong class (misordered list, short age axis, unresolved key).
