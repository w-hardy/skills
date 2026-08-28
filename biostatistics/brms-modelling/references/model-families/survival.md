# Survival / time-to-event models

What changes relative to `core-workflow.md` when modelling time-to-event outcomes with censoring.

## Specification

brms supports several parameterisations — choose based on the question and the shape of the hazard, not by default:

- `family = brmsfamily("cox")` — proportional-hazards model in which brms models the baseline hazard with M-splines (via the `splines2` package) and covariates act proportionally on it. Note this is *not* the partial-likelihood Cox model of `survival::coxph()`: brms estimates a smooth spline baseline jointly with the coefficients in one full likelihood, so the baseline hazard and its uncertainty come straight out of the posterior. `coxph()` estimates the coefficients from the partial likelihood without specifying the baseline, but a baseline and predicted survival curves are then routinely recovered as a non-parametric step function (Breslow-type — `survival::basehaz()` / `survfit()` on the fitted model, flat beyond the last observed event time) — so the difference is smooth-and-jointly-estimated versus step-function-and-post-hoc, *not* that `coxph()` cannot produce survival curves. Closest in spirit to `coxph()` for the regression coefficients, but don't describe the two as identical.
- Parametric accelerated failure time (AFT) models via `family = weibull()`, `lognormal()`, `exponential()`, `Gamma()`, or `frechet()`, modelling (typically log) time directly. These let you model the full survival/hazard function explicitly and extrapolate, which matters in health economic modelling (e.g. lifetime horizon extrapolation) — but check the hazard shape assumption is plausible, the same way you would in a non-Bayesian parametric survival model. brms has no generalised-gamma, Gompertz, or log-logistic family — three of the six standard HTA parametric distributions (verified against brms 2.20.4 and unchanged in 2.23.0, the current CRAN release at the time of writing). For a NICE-style batch comparison across the full standard set, use `flexsurv`/`survHE` instead (see the `survival-analysis-hta` and `nice-economic-evaluation` skills); survHE's `method = "hmc"` (via the `survHEhmc` add-on) gives Bayesian fits of the full standard set if a Bayesian analysis is specifically wanted.
- Censoring is specified with `y | cens(censoring_indicator) ~ ...` in the formula. brms's `cens()` coding is `1`/`'right'` = right-censored, `0`/`'none'` = observed event (also `-1`/`'left'`, `2`/`'interval'`) — the **opposite** of `survival::Surv()`, whose `status` is `1` = event, `0` = censored. So a `Surv()`-style `status` column must be flipped: `time | cens(1 - status) ~ ...`. Feeding `status` straight into `cens()` unflipped silently swaps events and censoring — a common silent error.

## Priors

- For AFT models, priors are most naturally specified on the log-time scale — sense-check that a prior which looks weakly-informative in raw units isn't wildly informative (or wildly diffuse) once exponentiated back to the time scale. A prior predictive check showing implied survival curves is particularly worthwhile here, more so than for most other families, because the time scale makes priors easy to misjudge by eye.
- For the shape/scale auxiliary parameters (e.g. Weibull shape), check the default prior isn't implausibly flat for the context — extreme shape values can imply implausible hazard shapes (sharply increasing or decreasing) that wouldn't survive a sense-check against clinical knowledge.

## Diagnostics & PPC

- Same Rhat/ESS/divergence thresholds as `core-workflow.md` apply unchanged.
- Posterior predictive checks for survival models should compare predicted vs. observed survival/hazard curves (e.g. via `tidybayes`-extracted draws plotted against a Kaplan-Meier estimate), not just `pp_check()`'s default density overlay, which is less informative for censored time-to-event outcomes.

## Reporting / health-economic context

- If this model feeds into an extrapolation for a cost-effectiveness model (lifetime horizon beyond trial follow-up), flag explicitly which parametric family was used for extrapolation and why, since the choice materially affects extrapolated survival — this is exactly the kind of structural assumption NICE-style reference-case scrutiny expects to see justified, not just stated.
- Report the censoring proportion and pattern (administrative censoring vs. competing risk) alongside the model, since it affects how the priors and resulting fit should be interpreted.
