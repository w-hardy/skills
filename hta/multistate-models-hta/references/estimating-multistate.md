# Estimating multistate models: flexsurv (fully-observed) vs msm (panel)

The two estimation routes need differently-shaped data and make different assumptions. This file gives the data layout and worked fitting code for each. Illustrative structure throughout: a 4-state colon-cancer model — Recurrence-free (1), Recurrence (2), Dead-cancer (3), Dead-other (4) — with 4 permitted transitions (1→2, 1→4, 2→3, 2→4), irreversible.

> Sources: R-HTA Ch. 11 (estimation routes; colon-cancer example); `msm` CRAN manual (Jackson) — `statetable.msm(state, subject, data)`, `msm(state ~ time, subject, data, qmatrix)`, `pmatrix.msm(fit, t = 1, covariates = )` confirmed current, incl. the guidance that the permitted-transition `qmatrix` comes from continuous-time disease logic, not observed-transition counts; `flexsurv` multistate vignette. Accessed 2026-07-03.

## Route A — fully-observed data, fit per-transition survival models with flexsurv

Use when state occupancy is known continuously, so each r→s transition time is observed or right-censored. This is the flexible route: any flexsurv distribution, clock-reset natural.

### Data layout

One row per (individual × at-risk transition). Each row records a transition the person was *at risk of* from their current state, marked observed (`status = 1`) or censored (`status = 0`). Key rules:
- An observed r→s transition is **also a censored** observation for every *competing* transition out of r (the other states reachable directly from r).
- `years` (time-in-state) is the survival time for a **clock-reset** model; using `Tstart`/`Tstop` (time-in-model) instead gives **clock-forward**.
- For clock-forward, the transition time is **left-truncated** at entry to state r.
- A `trans` column numbers the transition (1..n_transitions); a `status` column flags observed vs censored.

```
 id   from to  Tstart  Tstop   years  status trans  strategy_id
  1    1   2   0.00    2.65    2.65    1      1      3     # observed 1->2
  1    1   4   0.00    2.65    2.65    0      2      3     # censored competing 1->4
  1    2   3   2.65    4.16    1.51    1      3      3     # then observed 2->3
  ...
```

### Fitting loop

Fit a separate model per transition, choosing the distribution per transition. Treatment (or other covariates) can go on whichever transitions it plausibly affects — here only 1→2 (recurrence).

```r
library(survival); library(flexsurv)

distribution_names <- c("exp","weibull","gompertz","lognormal","llogis","gamma")
transition_names   <- c("RF to R","RF to OCD","R to CD","R to OCD")

# Treatment affects only the RF->R transition; others are ~1
survival_formula <- list(
  "RF to R"   = Surv(years, status) ~ factor(strategy_id),
  "RF to OCD" = Surv(years, status) ~ 1,
  "R to CD"   = Surv(years, status) ~ 1,
  "R to OCD"  = Surv(years, status) ~ 1
)

survival_models <- list()
aic_table <- matrix(NA, length(distribution_names), length(transition_names),
                    dimnames = list(distribution_names, transition_names))

for (i_trans in seq_along(transition_names)) {
  survival_models[[i_trans]] <- list()
  for (d in distribution_names) {
    fit <- flexsurvreg(survival_formula[[i_trans]],
                       subset = (trans == i_trans),   # <- restrict to this transition
                       data = msm_colon, dist = d)
    survival_models[[i_trans]][[d]] <- fit
    aic_table[d, i_trans] <- fit$AIC
  }
}
# Pick a distribution per transition (AIC here -- but see the warning below)
best <- distribution_names[apply(aic_table, 2, which.min)]
```

Note `Surv(years, status)` uses time-in-state → **clock-reset**. Switch to `Surv(Tstart, Tstop, status)` for time-in-model → clock-forward (with left-truncation handled by the two-time-argument Surv).

**Extrapolation warning carries over from survival-analysis-hta:** selecting each transition's distribution by minimum AIC fits the observed data but ignores extrapolation plausibility. For a decision model you're extrapolating, so compare against long-term/external data and inspect each transition's extrapolated hazard, exactly as in the `survival-analysis-hta` skill. AIC-only selection is a presentation simplification, not best practice.

## Route B — panel / intermittent data, estimate constant intensities with msm

Use when you only observe state at scattered times, so transition *times* are unknown. `msm` assumes time-homogeneous (constant) intensities — exponential sojourns — or piecewise-constant with time-dependent covariates.

### Data layout

One row per (subject × observation time): `id`, `years` (observation time), `state` (occupancy at that time), plus covariates.

```
 id  strategy_id  years     state
  1            3  1.063052      1
  1            3  3.790750      2
  ...
```

### Explore transitions first

```r
library(msm)
statetable.msm(state, id, data = panel_colon)
#       to
# from    1    2    3    4
#    1 4023  383   41  466
#    2    0 1211  367    2
```

This summarises observed transitions *over intervals* — note the "1→3" count (41) does NOT mean a direct 1→3 intensity; those patients passed through state 2 unobserved. Use this to spot sparse transitions (e.g. only 2 observed 2→4) where a covariate effect won't be identifiable.

### Specify permitted transitions (Q structure) and fit

The `qmatrix` has 1 where an instantaneous transition is *allowed in continuous time* (0 otherwise). **Choose this from disease logic, not from the statetable counts** — e.g. RF→Dead(Cancer) is disallowed because cancer death must pass through recurrence.

```r
colon_qmatrix <- rbind(
  c(0, 1, 0, 1),   # RF -> R, RF -> OCD  (no direct RF -> CD)
  c(0, 0, 1, 1),   # R  -> CD, R -> OCD
  c(0, 0, 0, 0),   # Dead (Cancer)  -- absorbing
  c(0, 0, 0, 0)    # Dead (Other)   -- absorbing
)
rownames(colon_qmatrix) <- colnames(colon_qmatrix) <-
  c("Recurrence-free","Recurrence","Dead (Cancer)","Dead (Other cause)")

fit <- msm(state ~ years, subject = id, data = panel_colon,
           qmatrix = colon_qmatrix,
           covariates = list("1-2" = ~ strategy_id),  # treatment only on RF->R
           deathexact = c(3, 4),   # death times known exactly, state-before-death not
           gen.inits = TRUE,       # auto initial values from statetable
           center = FALSE)         # intercepts at covariate = 0, not mean
fit
```

Read the output as baseline log-intensities plus hazard ratios per covariate. Convert intensities to interval transition probabilities with `pmatrix.msm()`:

```r
pmatrix.msm(fit, covariates = list(strategy_id = 1))   # 1-unit-time transition probs
```

### Identifiability cautions specific to panel data

- Place covariate effects only where the data support them — `covariates = list("1-2" = ~strategy_id)` puts treatment on the 1→2 intensity *only*. A covariate on a sparse transition gives extreme CIs or a fitting failure.
- Implausibly wide CIs or non-convergence usually mean a parameter isn't identified — go back to `statetable.msm()` and prune.
- `msm` only gives *constant* rates (or piecewise-constant). If the disease has clearly time-varying hazards and you only have panel data, acknowledge this as a limitation; the fully-observed flexsurv route is preferable when available.

The fitted object stores `fit$estimates` (log-rates and log-HRs) and `fit$covmat` (their covariance) — these feed the hesim simulation via multivariate-normal sampling (see `hesim-simulation.md`).
