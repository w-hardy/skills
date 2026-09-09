# Distributional models (zero-inflated, hurdle, ordinal, and auxiliary-parameter models)

What changes relative to `core-workflow.md` when the outcome needs more than a standard family, or when auxiliary parameters (not just the mean) are themselves modelled as a function of predictors.

## Specification

- **Zero-inflated vs. hurdle** — these answer different questions and are not interchangeable:
  - Zero-inflated (`zero_inflated_poisson()`, `zero_inflated_negbinomial()`) assumes zeros can come from two processes: a "structural" zero process and the count process itself (which can also generate zeros). Appropriate when there's a plausible reason some units could never have a non-zero outcome.
  - Hurdle (`hurdle_poisson()`, `hurdle_negbinomial()`, `hurdle_gamma()`) assumes a single threshold process determines zero vs. non-zero, and a separate process determines the value *given* it's non-zero. Appropriate when "crossing the hurdle" is the natural interpretation (e.g. any healthcare use at all, then amount of use).
  - Flag a review where one was used without comment on why it fits the outcome's data-generating story better than the other — this is a substantive modelling choice, not an interchangeable default.
  - **At a boundary of a *continuous* outcome, only the hurdle construction is coherent.** A continuous density assigns probability zero to any single point, so a pile-up at an exact value (costs at 0, a bounded score at 1) cannot be "inflation" of a continuous family — there is nothing to inflate. The atom has to be a separate Bernoulli component with the continuous family covering the rest. brms expresses these as `hurdle_gamma()` / `hurdle_lognormal()` for a spike at zero on a positive outcome, and `zero_inflated_beta()` / `zero_one_inflated_beta()` for spikes at the bounds of a `(0, 1)` outcome (the naming is historical — these are the boundary-atom families for a Beta outcome). Check the family names and their auxiliary parameters against the installed version. Put predictors on the boundary component (`hu ~ ...`, `zoi ~ ...`), not just the continuous part, whenever the proportion at the boundary could plausibly differ across groups — leaving them out asserts it cannot.
- **Ordinal** (`cumulative()`, `sratio()`, `cratio()`, `acat()`) — confirm the outcome is genuinely ordinal (ordered categories, unequal/unknown spacing) rather than a count or continuous variable that's been categorised unnecessarily, which throws away information. If categories are evenly spaced and there are many of them, consider whether a continuous family would be more appropriate.
- **Auxiliary parameter formulas** (e.g. `bf(y ~ x, sigma ~ x)` for a model where the variance itself depends on predictors) — these are easy to add in brms syntax but change what the model is claiming. Confirm there's a substantive reason to model heteroscedasticity (or the zero-inflation probability, or the ordinal threshold structure) as a function of predictors, rather than it being added because it was available.

## Priors

- Auxiliary parameter formulas need their own priors (brms's `get_prior()` output will show a separate row for e.g. `sigma` predictors) — these are easy to miss since they're not the "main" formula. Check they've been set deliberately, same as population-level priors on the mean.
- For zero-inflation/hurdle probability parameters (modelled on a logit scale internally), a prior that looks weak on the logit scale can still be informative about the probability itself near 0 or 1 — sense-check with a prior predictive check focused specifically on the proportion of zeros implied.

## Diagnostics & PPC

- Same Rhat/ESS/divergence thresholds as `core-workflow.md`.
- The PPC that matters most for these families is usually the feature the extra complexity was added to capture — check it explicitly rather than relying on the default density overlay:
  - Zero-inflated/hurdle: proportion at the boundary reproduced — `pp_check(fit, type = "stat", stat = function(y) mean(y == 0))`, or with the relevant boundary value substituted for a non-zero atom (e.g. `mean(y == 1)`). A model that matches the density's shape but not the size of the spike has not done the job the extra component was added for.
  - Ordinal: per-category predicted probabilities vs. observed proportions
  - Auxiliary-parameter (distributional) models: whether the *spread* of predicted values varies across predictor levels the way the data does, not just the central tendency

## Model comparison

- When comparing a distributional model against a simpler one (e.g. zero-inflated Poisson vs. plain Poisson), `loo_compare()` is doing real work here — this is exactly the comparison it's designed for. Still apply the comparability check from `core-workflow.md` (identical data/rows) and check Pareto-k, since zero-inflated/hurdle models can have higher-influence points than simpler families.
