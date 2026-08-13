# Special predictor terms

These are brms features that cut across model families rather than belonging to one — they can appear in a GLM, a multilevel model, a survival model, or a meta-analysis. Read this when the outcome's *family* is settled but the right-hand side of the formula needs more than plain linear terms. Each of these changes what the model claims, so each is a deliberate modelling choice to confirm (when reviewing) or justify in a comment (when writing).

## Repeated measures and autocorrelation

Longitudinal/repeated-measures data has two distinct sources of within-unit dependence, and they're often conflated:

- **Random effects** `(1 + time | id)` capture *between-unit heterogeneity* — each unit has its own intercept/slope. This is usually the first thing to reach for and is covered in `multilevel.md`.
- **Residual autocorrelation** captures *serial dependence in the residuals within a unit* — observations close in time are more alike than the random-effect structure alone implies. brms specifies this through the formula with terms such as `ar(time, gr = id, p = 1)` (autoregressive), `ma(...)`, `arma(...)`, `cosy(...)` (compound symmetry), or `unstr(time, gr = id)` (unstructured residual covariance over time).

A common error is assuming a random slope soaks up all temporal structure when the residuals are still autocorrelated, or conversely adding an `ar()` term that's redundant with a rich random-effects structure. When writing, decide which source of dependence the science implies and say so; when reviewing, check that a longitudinal model accounts for within-unit dependence *somewhere* (random effects, an autocorrelation term, or both deliberately) rather than treating repeated observations as independent. The posterior predictive check for these models should be done *within unit over time*, not just marginally — a model can fit the marginal distribution while getting the temporal dynamics wrong.

## Monotonic effects: `mo()`

`mo(x)` models an ordinal *predictor* (e.g. an ordered Likert item, a disease stage) as having a monotonic but not necessarily linear effect — the spacing between adjacent categories is estimated rather than assumed equal. Use it instead of either treating an ordinal predictor as continuous (which forces equal spacing and a linear trend) or as an unordered factor (which throws away the ordering). It induces a simplex parameter with a Dirichlet prior (class `simo`); confirm that prior is considered, not just the population-level coefficient. When reviewing, flag an ordered predictor entered as plain numeric without a comment justifying the equal-spacing/linearity assumption.

## Smooth terms: `s()` and `t2()`

`s(x)` fits a penalised spline (GAM-style) for a non-linear continuous effect, `t2(x, z)` a tensor-product smooth for interactions between continuous predictors. Reach for these when a linear or low-order-polynomial term is too rigid for a genuinely curved relationship, rather than fishing with higher polynomials. The wiggliness is controlled by a smoothing SD parameter (class `sds`) with its own prior — set/deliberate it the same way as any other prior. Watch for over-flexible smooths overfitting in small samples; a prior predictive check on the implied function shapes is a good sense-check.

## Measurement error and latent covariates: `me()` and `mi()`

- `me(x, sdx)` models a *predictor* observed with known measurement-error SD `sdx`, propagating that uncertainty into the coefficient rather than treating the noisy measurement as exact (which biases the estimate, classically toward zero). Relevant whenever a covariate is itself an estimate (e.g. an imputed biomarker, a derived index with a known standard error). It introduces `meanme`/`sdme` (and, with several such terms, `corme`) parameter classes — these get flat priors by default, so set them deliberately.
- `mi()` is brms's in-formula route for missing values on a predictor or outcome, modelling the missing entries as parameters jointly with the rest of the model. This is an alternative to the multiple-imputation-then-pool route (`brm_multiple()`); see `coding-conventions.md` for which to prefer and the reporting implications of each. The two are not interchangeable in their assumptions, so the choice should be explicit.
