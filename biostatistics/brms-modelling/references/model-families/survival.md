# Survival / time-to-event models

What changes relative to `core-workflow.md` when modelling time-to-event outcomes with censoring.

## Specification

brms supports several parameterisations — choose based on the question and the shape of the hazard, not by default:

- `family = brmsfamily("cox")` — proportional-hazards model in which brms models the baseline hazard with M-splines (via the `splines2` package) and covariates act proportionally on it. Note this is *not* the partial-likelihood Cox model of `survival::coxph()`: it's a full-likelihood spline-baseline model that assumes proportional hazards, so a full baseline survival/hazard curve *is* recoverable from it (unlike the partial-likelihood version, which leaves the baseline unspecified). Closest in spirit to `coxph()` for the regression coefficients, but don't describe the two as identical.
- Parametric accelerated failure time (AFT) models via `family = weibull()`, `lognormal()`, or `gengamma()`, modelling (typically log) time directly. These let you model the full survival/hazard function explicitly and extrapolate, which matters in health economic modelling (e.g. lifetime horizon extrapolation) — but check the hazard shape assumption is plausible, the same way you would in a non-Bayesian parametric survival model.
- Censoring is specified with `y | cens(censoring_indicator) ~ ...` in the formula — confirm the censoring indicator is coded the way brms expects (check `?brmsformula` / `cens()` for the exact coding: typically `'right'`, `'left'`, `'interval'`, or a 0/1 indicator for right-censoring) rather than assuming it matches whatever convention the data arrived in (e.g. `survival::Surv()` uses the opposite 0/1 convention in some setups — this is a common silent error).

## Priors

- For AFT models, priors are most naturally specified on the log-time scale — sense-check that a prior which looks weakly-informative in raw units isn't wildly informative (or wildly diffuse) once exponentiated back to the time scale. A prior predictive check showing implied survival curves is particularly worthwhile here, more so than for most other families, because the time scale makes priors easy to misjudge by eye.
- For the shape/scale auxiliary parameters (e.g. Weibull shape), check the default prior isn't implausibly flat for the context — extreme shape values can imply implausible hazard shapes (sharply increasing or decreasing) that wouldn't survive a sense-check against clinical knowledge.

## Diagnostics & PPC

- Same Rhat/ESS/divergence thresholds as `core-workflow.md` apply unchanged.
- Posterior predictive checks for survival models should compare predicted vs. observed survival/hazard curves (e.g. via `tidybayes`-extracted draws plotted against a Kaplan-Meier estimate), not just `pp_check()`'s default density overlay, which is less informative for censored time-to-event outcomes.

## Reporting / health-economic context

- If this model feeds into an extrapolation for a cost-effectiveness model (lifetime horizon beyond trial follow-up), flag explicitly which parametric family was used for extrapolation and why, since the choice materially affects extrapolated survival — this is exactly the kind of structural assumption NICE-style reference-case scrutiny expects to see justified, not just stated.
- Report the censoring proportion and pattern (administrative censoring vs. competing risk) alongside the model, since it affects how the priors and resulting fit should be interpreted.
