# Parameterisation routes and clocks (hesim 0.5.8)

Provenance tags: **[vignette]** = confirmed in the hesim 0.5.8 vignettes (2026-01-16 builds); **[EXPO 0.5.8]** = observed/resolved in the EXPO build on hesim 0.5.8 — re-verify on upgrade.

## 1. Skeleton

```r
strategies <- data.table(strategy_id = 1:2, strategy_name = c("SoC", "BUP-XR"))
patients   <- data.table(patient_id = 1:n, age = ..., female = ...)   # simulate enough
                                                                      # patients that MC noise
                                                                      # << parameter uncertainty
patients[, grp_id := ...]                    # optional subgroups -> per-group CEA later
states     <- data.table(state_id = ..., state_name = ...)            # NON-absorbing only!
tmat       <- rbind(...)                     # consecutive integer transition IDs, NA elsewhere
transitions <- create_trans_dt(tmat)         # tidy transition table from tmat  [vignette]
hesim_dat  <- hesim_data(strategies = strategies, patients = patients,
                         states = states, transitions = transitions)
labs <- get_labels(hesim_dat)                # presentation labels for plots/tables [vignette]
```

- Death/absorbing states are inferred from `tmat`; listing them in `states` misaligns indexing. **[vignette]**
- `expand()` builds the input data. **Which `by` depends on how the multistate model was fitted**: transition-specific fits → `expand(hesim_dat, by = c("strategies","patients"))` (one row per strategy×patient); a **joint** model (single fit, transition as covariate) → add `"transitions"` (one row per strategy×patient×transition). Getting this wrong misaligns covariates. **[vignette]**

## 2. Route A — fitted transitions (`flexsurvreg_list`)

Fit one survival model per transition (see `survival-analysis-hta` for distribution choice):

```r
# clock-RESET fit: time since entering the current state
fit_i <- flexsurvreg(Surv(years, status) ~ factor(strategy_id),
                     data = transitions_data, subset = (trans == i), dist = "weibull")
# clock-FORWARD fit: time since model start (counting-process form)
fit_i <- flexsurvreg(Surv(Tstart, Tstop, status) ~ factor(strategy_id),
                     data = transitions_data, subset = (trans == i), dist = "weibull")
fits <- flexsurvreg_list(fit_1, ..., fit_K)
```

The reset/forward distinction is **baked into the `Surv()` form of the fit** — the `clock=` argument at build time must match how the models were estimated. **[vignette]**

```r
transmod <- create_IndivCtstmTrans(fits, transmod_data,
                                   trans_mat = tmat, n = n_samples,
                                   clock = "reset",              # match the fits
                                   start_age = patients$age,
                                   uncertainty = "normal")       # MVN of MLE; the default
```

`uncertainty = "normal"` is the default for fitted objects; `"none"` gives a point-estimate model (useful for diagnostics, never for the base case). **[vignette]**

## 3. Route B — externally-parameterised transitions (`params_surv_list`)

For transitions whose parameters come from outside a flexsurv fit (lifetable mortality, literature rates, msm intensities). Each `params_surv(coefs, dist, aux)`:

- `coefs` — a **list, one element per distribution parameter**, each a matrix/data.table with **rows = PSA samples**, columns = covariates. Uncertainty lives *here*; there is **no `uncertainty=` argument on `params_surv`**, and `create_IndivCtstmTrans()` on a `params_surv_list` takes none either. **[vignette; EXPO 0.5.8]**
- `dist` — `"exp"`, `"weibullPH"`, `"pwexp"` (with `aux = list(time = breakpoints)`), `"fixed"` (deterministic times, `coefs = list(est = ...)`), and the other `params_surv()` distributions.
- Rates are on the **log scale** in `coefs` for rate-parameterised dists.

The vignette's helper patterns — reuse them verbatim: **[vignette]**

```r
prob_to_rate <- function(p, t = 1) (-log(1 - p)) / t     # probability over t -> rate

vec_to_dt <- function(v, n = NULL) {                     # scalar/vector -> 1-col coef table
  if (length(v) == 1) v <- rep(v, n_samples)
  dt <- data.table(v); colnames(dt) <- "cons"; dt
}
as_dt_list <- function(x) lapply(as.list(x), vec_to_dt)  # pwexp: one coef table per period
```

Composite rates **add on the natural scale, then log** — e.g. operative + background mortality: `log(omr + mr)`, never `log(omr) + log(mr)` (that multiplies). SMRs, by contrast, *are* multiplicative → log-additive. **[vignette]**

```r
transmod_params <- params_surv_list(
  params_surv(coefs = list(rate = vec_to_dt(log(ttr_rate))), dist = "exp"),          # 1
  params_surv(coefs = list(shape = rr_shape, scale = rr_scale), dist = "weibullPH"), # 2
  params_surv(coefs = as_dt_list(log_mr),
              aux = list(time = c(0, 5, 15, 25)), dist = "pwexp"),                   # 3: death
  params_surv(coefs = list(est = vec_to_dt(1)), dist = "fixed")                      # 4
)
transmod <- create_IndivCtstmTrans(transmod_params, transmod_data,
                                   trans_mat = tmat, n = n_samples,
                                   clock = "forward", start_age = patients$age)
```

## 4. Mixing the routes — one list, via `create_params()`

`create_IndivCtstmTrans()` accepts **one** transition object. To combine fitted retention models with hand-built mortality/tunnel transitions (the EXPO pattern), convert each fit and assemble a single list: **[EXPO 0.5.8]**

```r
retention_params <- lapply(retention_fits, create_params, n = n_samples,
                           uncertainty = "normal")   # MVN draws happen HERE
all_params <- do.call(params_surv_list, c(retention_params, list(
  death_ontx  = params_surv(coefs = ..., aux = list(time = age_breaks), dist = "pwexp"),
  death_offtx = params_surv(coefs = ..., aux = list(time = age_breaks), dist = "pwexp")
)))  # order must follow transition IDs in tmat
```

Consequences of the single-list assembly (all **[EXPO 0.5.8]**):

- **Coefficient names must be consistent with the input data.** `create_params()` on a flexsurv fit emits the fit's own names — `(Intercept)`, `armsoc` — so hand-built entries sharing covariates must use *those* names, not a generic `cons`. (Standalone intercept-only tables can be `cons`, per the vignette helper — the trap is *mixed* assemblies.)
- **This is where a non-positive-definite vcov surfaces** — `create_params(fit, uncertainty="normal")` draws from the fit's MVN; a non-PD vcov errors here. Have a fallback route (nearest-PD repair or bootstrap) wired at this point, not downstream.
- The list order must match the transition-ID numbering in `tmat` exactly; a misordering runs and is silently wrong (pre-flight check in `scripts/check_ctstm_build.R`).

## 5. Clocks — `"reset"`, `"forward"`, `"mix"`, `"mixt"`

- `"reset"` — all transitions on time-since-state-entry (semi-Markov).
- `"forward"` — all on time-since-model-start (Markov).
- `"mix"` — **per origin state**: all transitions out of a state share a clock.
- `"mixt"` — **per transition**: each transition carries its own clock.

**EXPO requires `"mixt"`**: clock-reset retention/discontinuation and clock-forward (attained-age) mortality leave the *same* origin state, so per-state mixing cannot express it. The original attempt with `"mix"` silently mis-clocked mortality; the D4 spike established `"mixt"` as the working mechanism (survival vs analytic background 0.008; reset-retention check 0.0002). **[EXPO 0.5.8]**

### The coexisting-death-edges spike (D4/P2b — run before committing structure)

Open question: can a **reset-clock death edge** (peri-discontinuation elevation, weeks 1–4 in-state) and a **forward-clock age death edge** coexist on **one origin state** under `"mixt"`? Do not assume — spike it:

1. Build a minimal 2-state + Death model: origin state with **two death transitions** in `tmat` — one pwexp on the age axis (forward), one exp/pwexp on sojourn time (reset) — under `clock = "mixt"`.
2. Simulate at large `n` patients with `uncertainty = "none"`; compare simulated survival against the closed-form combined hazard (the two rates add).
3. **If it matches** → model peri-exit mortality as a native reset death edge, no sub-state. **If hesim rejects the structure or the survival is wrong** → the *evidenced* fallback is an early-exit sub-state (`OffTx_early`, two 2-week tunnel cycles) carrying the elevated rate — "the framework forced it" is a stronger justification than "we chose it".

Generalise the habit: whenever two transitions from one origin need different time-scales, test coexistence empirically against an analytic target before building the full structure.

## 6. State values

```r
utility_tbl  <- stateval_tbl(data.table(state_id = ..., mean = ..., se = ...), dist = "beta")
drugcost_tbl <- stateval_tbl(data.table(strategy_id = ..., est = ...),          dist = "fixed")
medcost_tbl  <- stateval_tbl(data.table(state_id = ..., mean = ..., se = ...),  dist = "gamma")

utilitymod <- create_StateVals(utility_tbl,  n = n_samples, hesim_data = hesim_dat)
costmods   <- list(drug    = create_StateVals(drugcost_tbl, n = n_samples,
                                              hesim_data = hesim_dat,
                                              method = "starting"),   # one-off at state entry
                   medical = create_StateVals(medcost_tbl,  n = n_samples,
                                              hesim_data = hesim_dat,
                                              method = "wlos"))       # ongoing, time-weighted
```

- The `hesim_data=` argument is required so the table expands over the missing ID dimensions. **[vignette]**
- `stateval_tbl` rows can also vary by `sample` (pre-simulated values, e.g. posterior draws from the TOP→EQ-5D mapping — the route for mapping uncertainty entering the PSA), by `strategy_id`, `patient_id`, or `time_id` (time intervals, e.g. a first-year disutility).
- In individual-level models StateVals can be **clock-reset** (`time_reset = TRUE`) — state values depending on time since *state entry* (tunnel costs, re-presentation cost bands). **[vignette]**

## 7. Simulate

```r
ictstm <- IndivCtstm$new(trans_model = transmod, utility_model = utilitymod,
                         cost_models = costmods)
ictstm$sim_disease(max_t = 60, max_age = 110)   # max_age DEFAULT IS 100 — raise it
ictstm$sim_stateprobs(t = seq(0, 60, 1/26))     # 2-week grid if needed for reporting
ictstm$sim_qalys(dr = 0.035)                    # discounting happens HERE
ictstm$sim_costs(dr = 0.035)
ce <- ictstm$summarize(by_grp = TRUE)           # -> decision layer
```

`$disprog_` holds the individual trajectories (sample, strategy, patient, from, to, time_start, time_stop) — the raw material for trajectory-level validation. **[vignette]**
