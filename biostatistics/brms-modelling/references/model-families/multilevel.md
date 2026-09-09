# Multilevel / hierarchical models

What changes relative to `core-workflow.md` when the model has group-level (random) effects — `(1 | group)`, `(1 + x | group)`, nested or crossed grouping.

## Specification

- Be deliberate about nested vs. crossed grouping syntax: `(1 | site/clinician)` for nesting (clinician only meaningful within site) vs. `(1 | site) + (1 | clinician)` for genuinely crossed groups. Getting this wrong silently fits the wrong dependence structure — brms won't error.
- Random slopes `(1 + x | group)` require enough observations per group to estimate the slope variance; with very few groups or very few observations per group, prefer a simpler random-intercept-only model and say why in a comment.
- By default brms estimates the correlation between random intercepts and slopes. Use `(1 + x || group)` (double bar) to force independence only when there's a specific reason (e.g. estimation instability with few groups) — note the reason in a comment, since this is a modelling assumption, not just syntax.

## Priors

- Group-level SD parameters (`sd(...)`) get their own prior class in `get_prior()` output — these are usually the priors most worth setting deliberately, since with few groups the data alone won't strongly identify between-group variance. A half-normal or exponential prior with a scale plausible for the outcome is a reasonable default.
- With very few groups (roughly <5), be explicit in review/reporting that the group-level variance is weakly identified and the prior is doing real work — this is a defensibility point, not just a technical one.

## Fitting & diagnostics

- Funnel geometry (Neal's funnel) is the classic source of divergences in multilevel models: the group-level SD and the individual group-level effects are correlated in a way centred parameterisations struggle with. brms uses the non-centred form throughout (next bullet), which removes most of that geometry — so persistent divergences in a brms multilevel fit mean either that the remaining curvature bites anyway (few groups, little data per group, a group-level SD whose posterior runs into zero) or that the trouble is the ridge below, not the funnel.
- **Non-centred parameterisation is not an available fix here — brms already uses it.** brms generates group-level effects in the non-centred form and offers no switch to a centred one: `stancode(fit)` shows `r_1_1 = (sd_1[1] * (z_1[1]));` built from a standard-normal `z_1` (verified against brms 2.23.0). "Try non-centring" is therefore a dead end on any real brms model, and a review that recommends it is recommending a no-op. (`brmsformula(..., center = ...)` is a different thing: it centres the population-level design matrix about its column means, not the group-level effects.) When divergences survive a raised `adapt_delta`, the remaining levers are on the model rather than the parameterisation: tighten the prior on the group-level SD (the calibrated exponential/PC recipe in `core-workflow.md` §1), drop the intercept–slope correlation with `||` or remove a group-varying term the data can't support, or — at three or four groups — model the grouping as a population-level factor instead of a hierarchy and say why.
- Check ESS specifically for the group-level SD parameters (`sd_group__Intercept` etc.), not just population-level effects — these are often the slowest-mixing parameters in the model.

## Few groups: the grand-intercept / group-mean ridge

This is the other few-group pathology, distinct from the funnel and more often what a slow-mixing brms multilevel fit actually has. In `y ~ 1 + (1 | g)` the likelihood only ever sees the sum `Intercept + r_g[j]`: add a constant to the intercept, subtract it from every group effect, and the likelihood is unchanged. What separates the two is only the priors — the `normal(0, sd_g)` prior pulling the group effects toward zero, and whatever prior the intercept carries (brms's default is a wide, data-scaled `student_t(3, median(y), 2.5)`). With a handful of groups, a weak prior on `sd_g` and that default on the intercept, the pull is feeble from both ends, so the posterior has a long ridge running along `(Intercept + c, r_g - c)`.

Symptoms, which look like a sampler problem and are really an identification problem: `b_Intercept` and every `r_g[...]` mixing slowly *together* while the rest of the model is fine (low bulk ESS and Rhat creeping over 1.01 on exactly those parameters), a strong negative correlation between draws of the intercept and the mean of the group effects, sometimes divergences. Raising `adapt_delta` doesn't help, because a ridge is not a funnel.

**It is a decomposition problem, not an estimation problem.** The group mean `Intercept + r_g[j]` is identified by the data even when neither term is on its own, so the ridge is harmless for anything that reads the sum: predictions and fitted values at `re_formula = NULL` (the default for `posterior_epred()`, `fitted()` and `predict()`, which include the group-level effects), within-group contrasts, arm means evaluated at observed groups. It bites only quantities that read the two apart — the reported grand intercept, a population-level prediction at `re_formula = NA`, a "baseline" that a downstream model consumes. Establish which of those the pipeline actually uses before grading it: if only group-level predictions are consumed, note the ridge and the poor intercept ESS and move on.

The standard menu, roughly in order:

- **Tighten the prior on the group-level SD.** The prior is what identifies the split, so making it a defensible one is the fix rather than a patch — use the calibrated exponential recipe in `core-workflow.md` §1 and state the tail statement it encodes. brms's default `student_t(3, 0, 2.5)` on `sd` is wide enough to leave the ridge nearly flat at four groups.
- **Give the intercept a real prior.** It is the other half of what identifies the split, and brms's default is deliberately weak. Where the outcome scale supports a defensible statement about the grand mean, an informative intercept prior pins the ridge without giving up any partial pooling — how much the group means shrink toward each other is set by the prior on `sd_g`, which this leaves alone. State the statement the prior encodes, not just the numbers, and note that `class = "Intercept"` is the intercept at *mean-centred* predictors, so in a model with covariates it is not the `b_Intercept` that ends up reported.
- **Soft sum-to-zero constraint** on the group effects: `stanvar(scode = "target += normal_lpdf(sum(r_1_1) | 0, 0.001 * N_1);", block = "model")` pins the ridge at its centre while leaving the group means alone. Check the internal names against `stancode(fit)` first (`r_1_1` and `N_1` belong to the first grouping term), and note that this is a stanvar-injected prior: invisible to `default_prior()` and `prior_summary()`, so it has to be reported separately — see `review-checklist.md`.
- **Hard sum-to-zero.** brms has no built-in sum-to-zero constraint on group-level effects, so the exact version means giving up the hierarchy: enter the grouping as a population-level factor with sum-to-zero contrasts (`contr.sum`). That identifies the split exactly at the cost of partial pooling, which is a fair trade at three or four groups, where there was little pooling to be had.
- **More groups.** The ridge is a small-J phenomenon; as the number of groups grows, the prior on the group effects identifies the split increasingly well and it goes away on its own.

One interpretation point either way: under a sum-to-zero constraint the intercept is the mean of the group means, not the population mean the unconstrained hierarchy implies. With unbalanced groups those differ, so say which one a reported "intercept" is.

## Posterior predictive checks

- Check fit *within* groups (`pp_check(fit, type = "intervals_grouped", group = "...")` or manual per-group checks), not only the marginal/population-level check. A model can look fine marginally while badly misfitting specific groups (especially groups with unusual sample sizes).

## Model comparison

- If the scientific question is about generalising to *new* groups (e.g. a new clinical site, a new cluster), use group-level k-fold cross-validation (`kfold(fit, folds = "group", group = "...")`) rather than standard `loo()`, which leaves out individual observations and will be optimistic about between-group generalisation.
