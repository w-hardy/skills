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

- Funnel geometry (Neal's funnel) is the classic source of divergences in multilevel models: the group-level SD and the individual group-level effects are correlated in a way centred parameterisations struggle with.
- **Non-centred parameterisation** is the standard fix when divergences persist after raising `adapt_delta`. In brms this is largely handled automatically for standard `(1 | group)` terms, but if divergences remain in a more complex random-effects structure, consider whether brms's default parameterisation is the issue and check the `stancode(fit)` output for funnel-prone structures.
- Check ESS specifically for the group-level SD parameters (`sd_group__Intercept` etc.), not just population-level effects — these are often the slowest-mixing parameters in the model.

## Posterior predictive checks

- Check fit *within* groups (`pp_check(fit, type = "intervals_grouped", group = "...")` or manual per-group checks), not only the marginal/population-level check. A model can look fine marginally while badly misfitting specific groups (especially groups with unusual sample sizes).

## Model comparison

- If the scientific question is about generalising to *new* groups (e.g. a new clinical site, a new cluster), use group-level k-fold cross-validation (`kfold(fit, folds = "group", group = "...")`) rather than standard `loo()`, which leaves out individual observations and will be optimistic about between-group generalisation.
