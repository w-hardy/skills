# Coding conventions for brms scripts

Style conventions to apply when writing new brms code, and to check for when reviewing.

## Style

- Use the base R pipe `|>`, not `%>%`, unless the surrounding script already commits to magrittr.
- Load only the packages actually used. A typical brms script needs `brms` itself plus a subset of: `tidybayes`, `bayesplot`, `loo`, `marginaleffects`, `posterior`. Don't load all of them reflexively.
- Use tidyverse-style data preparation feeding into `brm(data = ...)`, rather than base-R subsetting scattered through the formula call.

## Reproducibility & structure

- Always set `seed` in `brm()`.
- Separate model-fitting code from post-processing/reporting code into distinct, reusable functions or script sections — a script that fits, diagnoses, checks, and reports all inline in one block is harder to rerun partially when only the reporting step needs to change.
- Save fitted model objects (`saveRDS(fit, "models/fit_<name>.rds")`) rather than only keeping them in the R session — refitting a brms model is expensive, and version-controlling the *code* that produced a fit (not the fit itself, which is typically too large/binary for git) means the fit needs to be reproducible from a clean run. Pair this with the `seed` requirement above.
- Where multiple related models are compared, write a single function that takes a formula/family and returns a fitted-and-diagnosed model, rather than copy-pasting the `brm()` call with small variations — this is the most common source of accidental inconsistency between "comparable" models (e.g. one fit with `cores = 4` and a different `seed` than another, or one missing the explicit prior the others have).

## Missing data

- Be explicit about how missing data is handled before it reaches `brm()`. Silent listwise deletion via an implicit `na.omit` inside the formula call is the same trap as in any other regression — state whether rows were dropped, how many, and why. This is also the hidden cause of the most common model-comparison error (see `core-workflow.md`): complete-case deletion on different predictor sets leaves two models fit to different rows, which invalidates `loo_compare()`.
- brms offers two principled routes when listwise deletion isn't acceptable, and they make different assumptions, so the choice should be explicit:
  - **Multiple imputation then pool** — impute *m* complete datasets externally (e.g. with `mice`), then `brm_multiple(formula, data = imputed_list, ...)`, which fits the model to each and combines the draws. If a `mice`-based imputation workflow is in play, defer to the dedicated missing-data guidance for building the imputation model itself; this skill's concern is the brms side. Two things to get right: combining draws across imputations is only valid if each fit converged (check Rhat *per imputation*, not just pooled — `brm_multiple` warns about between-imputation variability via an `rhat` that conflates the two), and model comparison across multiply-imputed fits is not straightforward — `loo()` on a `brm_multiple` object is not a clean leave-one-out, so don't compare imputed-data models with `loo_compare()` without understanding what's being averaged.
  - **Impute within the model** — `mi()` terms (see `special-terms.md`) model missing values jointly with everything else in a single fit, which sidesteps the cross-imputation pooling problem but ties the imputation model to the brms formula.
- Whichever route, report the missingness mechanism assumed (MCAR/MAR/MNAR) and the proportion missing, not just that imputation was done — the defensibility of the whole analysis rests on the mechanism assumption.

## Comments

- Comment the *why* of modelling choices, not the *what* of brms syntax. `# multilevel logistic model` is much less useful than `# random intercept by clinic: outcomes for patients at the same clinic
# aren't independent, and clinic count (n=42) is enough to estimate this`.
- Any non-default `control` argument (`adapt_delta`, `max_treedepth`) should have a comment saying what problem it was fitted to fix — this is what lets a reviewer (or future you) tell a considered fix apart from a value bumped up until warnings stopped.
