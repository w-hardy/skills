# Simulating and analysing a multistate CEA with hesim

The individual-level continuous-time simulation pipeline, from a fitted transition model through to a `BCEA` cost-effectiveness analysis. hesim objects are R6 classes; the pipeline is the same whether transitions came from flexsurv (fully-observed) or msm/NMA (external parameters) — only the transition-model construction differs.

> Sources: R-HTA Ch. 11 (hesim simulation pipeline); `hesim` pkgdown docs — `hesim_data()`, `expand()`, `flexsurvreg_list()`/`params_surv_list()` → `create_IndivCtstmTrans()` (with `uncertainty = "normal"`, `n = `), `stateval_tbl()` → `create_StateVals()`, `IndivCtstm$new()`, `$sim_disease()`, `$sim_stateprobs()`, `$sim_qalys()`, `$sim_costs()` all confirmed current. Accessed 2026-07-03.

Same 4-state colon example: Recurrence-free (1), Recurrence (2), Dead-cancer (3), Dead-other (4).

## 1. Model skeleton

```r
library(data.table); library(flexsurv); library(hesim); library(BCEA)

state_names     <- c("Recurrence-free","Recurrence","Dead (Cancer)","Dead (Other cause)")
treatment_names <- c("Observation","Lev","Lev+5FU")
n_patients <- 1000; n_samples <- 1000

# Transition matrix: consecutive transition IDs in permitted cells, NA elsewhere
# (incl. the diagonal and disallowed transitions)
transition_matrix <- rbind(
  c(NA, 1, NA, 2),   # RF -> R (1), RF -> OCD (2)
  c(NA, NA, 3, 4),   # R -> CD (3), R -> OCD (4)
  c(NA, NA, NA, NA),
  c(NA, NA, NA, NA)
)
colnames(transition_matrix) <- rownames(transition_matrix) <- state_names

strategies <- data.table(strategy_id = 1:3, strategy_name = treatment_names)
patients   <- data.table(patient_id = 1:n_patients,
                         age = msm_colon$age[sample(n_patients, n_patients, TRUE)],
                         sex = msm_colon$sex[sample(n_patients, n_patients, TRUE)])
# IMPORTANT: only NON-absorbing states go here; hesim adds death states from
# the transition matrix. Listing death states here misaligns the indexing.
states <- data.table(state_id = 1:2, state_name = state_names[1:2])

hesim_dat <- hesim_data(strategies = strategies, patients = patients, states = states)
transmod_data <- expand(hesim_dat, by = c("strategies", "patients"))
labels <- get_labels(hesim_dat)
```

## 2a. Transition model — fully-observed route (flexsurv)

Bundle the chosen per-transition fits (in transition-ID order) into a `flexsurvreg_list`, then build the transition model. `clock = "reset"` for semi-Markov.

```r
transition_fits <- flexsurvreg_list(
  survival_models[["RF to R"]][["gompertz"]],   # transition 1
  survival_models[["RF to OCD"]][["gompertz"]], # transition 2
  survival_models[["R to CD"]][["llogis"]],     # transition 3
  survival_models[["R to OCD"]][["exp"]]        # transition 4
)

transmod_cr <- create_IndivCtstmTrans(
  transition_fits, transmod_data,
  trans_mat = transition_matrix,
  n = n_samples,
  clock = "reset",            # "forward" / "mix" / "mixt" also available
  start_age = patients$age,
  uncertainty = "normal"      # draws params from the fits' MVN; "none" for point est
)
```

## 2b. Transition model — external-parameter route (msm or NMA)

`msm` gives constant log-rates and log-HRs in `fit$estimates` with covariance `fit$covmat`. Sample them jointly, then wrap each transition's coefficients in a `params_surv` (exponential, since msm rates are constant), bundle into a `params_surv_list`, and build the transition model with **`clock = "forward"`** (msm is Markov).

```r
library(MASS)
samples <- mvrnorm(n_samples, mu = msm_fit$estimates, Sigma = msm_fit$covmat)
samples <- as.data.frame(samples)
# name columns to your transition/treatment scheme, then per transition:

transition_params <- params_surv_list(
  params_surv(coefs = list(data.frame(
                intercept = samples[["RF to R Intercept"]],
                Lev       = samples[["RF to R Lev"]],
                `Lev+5FU` = samples[["RF to R Lev+5FU"]])),
              dist = "exp"),
  # ... one params_surv() per transition ...
)

# input_data must carry covariates matching the coef names (intercept, Lev, Lev+5FU)
transmod_data[, intercept := 1]
transmod_data[, Lev := strategy_name == "Lev"]
transmod_data[, `Lev+5FU` := strategy_name == "Lev+5FU"]

transmod_panel <- create_IndivCtstmTrans(
  transition_params, input_data = transmod_data,
  trans_mat = transition_matrix,
  clock = "forward",          # <- msm is clock-forward; mismatching corrupts results
  start_age = patients$age
)
```

The same `params_surv_list` route accepts NMA output (proportional-hazards log-HRs, or `dist = "fracpoly"`/`"survspline"` coefficients for non-PH NMA), and population-adjusted HRs from MAIC/ML-NMR — see the `network-meta-analysis-hta` and `population-adjusted-comparisons` skills for producing those.

## 3. State values (utilities and costs)

`stateval_tbl()` builds a table of values per (strategy, state, sample, time period), then `create_StateVals()` makes the model object. The table construction is the fiddliest part of hesim — values are typically sampled separately and slotted in.

```r
# Utilities, with a first-year toxicity disutility (two time periods)
utility_recurrence_free <- rnorm(n_samples, 0.8, 0.1 * 0.8)
utility_recurrence      <- rnorm(n_samples, 0.6, 0.1 * 0.6)
p_tox_lev    <- rnorm(n_samples, 0.20, 0.1 * 0.20)
disutility   <- rnorm(n_samples, -0.1, 0.1 * 0.1)

# Build a blank stateval_tbl with dist = "custom" spanning strategy x state x
# sample x {year-1, year-2+}, then fill $value (see the book for the full
# index-construction; the key is matching the row order hesim expects).
utility_model <- create_StateVals(utility_table, hesim_data = hesim_dat, n = n_samples)

# Costs: usually two StateVals -- one-off treatment ("Drug") and ongoing state
# ("Medical") costs -- combined in a named list.
cost_models <- list(Drug = treatment_cost_model, Medical = state_cost_model)
```

For `stateval_tbl`, simpler cases can pass a `dist` shortcut (`"beta"` for utilities with mean+se, `"gamma"` for costs, `"fixed"` for constants) instead of hand-building `"custom"` values — prefer that when the values aren't a bespoke combination.

## 4. Combine, simulate, analyse

```r
econ <- IndivCtstm$new(trans_model = transmod_cr,
                       utility_model = utility_model,
                       cost_models = cost_models)

econ$sim_disease()                      # individual trajectories -> $disprog_
econ$sim_stateprobs(t = seq(0, 20, 1/12))
econ$sim_qalys(dr = 0.03)               # discount rate -- see nice-economic-evaluation
econ$sim_costs(dr = 0.03)

autoplot(econ$stateprobs_, labels = labels)   # state-occupancy plot

# Reshape to BCEA's expected n_samples x n_strategies matrices
s <- econ$summarize()
costs_mat <- effects_mat <- matrix(NA, n_samples, length(treatment_names),
                                   dimnames = list(NULL, treatment_names))
for (k in seq_along(treatment_names)) {
  costs_mat[, k]   <- with(s$costs,  costs[category == "total" & strategy_id == k & dr == 0.03])
  effects_mat[, k] <- with(s$qalys,  qalys[strategy_id == k & dr == 0.03])
}

ce <- bcea(eff = effects_mat, cost = costs_mat, ref = 1,
           interventions = treatment_names, Kmax = 200000)
summary(ce, wtp = 100000)
ceplane.plot(ce, wtp = 100000, graph = "ggplot2")
ceac.plot(multi.ce(ce), graph = "ggplot2")
```

## Notes that save debugging time

- **`uncertainty = "normal"`** is what makes the run probabilistic (draws transition parameters from the fits' covariance). The older `point_estimate`/`bootstrap` arguments are deprecated — use `uncertainty`. For a deterministic check use `uncertainty = "none"`, but the base case should be probabilistic.
- **Clock must match the estimation.** flexsurv-on-time-in-state → `"reset"`; msm → `"forward"`. This is the most common silent error.
- **State-probability computation differs by clock.** Clock-forward state probabilities can be computed analytically (Aalen-Johansen); clock-reset can only come from the individual simulation — so `$sim_disease()` must run before `$sim_stateprobs()` for semi-Markov models.
- **`sim_disease()` runs to an absorbing state by default**, up to `max_age` (default 100) / `max_t`. Set these if you want a fixed horizon rather than simulating every patient to death.
- The hesim `mstate` and `markov-inhomogeneous-indiv` vignettes are the authoritative worked examples; check function signatures against the installed version, as hesim's API has evolved (e.g. the `uncertainty` argument, `transition_id` renamed from `trans`).
