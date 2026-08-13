# Methods, predictors, and derived variables

> Sources: van Buuren, *Flexible Imputation of Missing Data*, 2nd ed. (2018): Chapter 3
> ("Univariate missing data": pmm §3.4, cart §3.5, categorical §3.6 with perfect prediction
> §3.6.2, other data types §3.7 — count §3.7.1, semi-continuous §3.7.2, censored §3.7.3),
> Chapter 4 ("Multivariate missing data": influx/outflux §4.1.3, monotone imputation §4.3),
> and Chapter 6 ("Imputation in practice": predictor selection §6.3.2, derived variables
> §6.4 — ratios §6.4.1, interactions §6.4.2, quadratics §6.4.3, compositional §6.4.4, sum
> scores §6.4.5 — and visit sequence §6.5.1). `quickpred()` usage per FIMD §9.1 and the mice
> CRAN reference manual. <https://stefvanbuuren.name/fimd/>, verified against the online
> edition 3 July 2026.

## Method table, in more detail (FIMD §3.4–3.7)

`make.method(dat)` returns mice's type-based defaults. Override individual entries rather than
replacing the whole vector:

```r
meth <- make.method(dat)
meth["income"] <- "cart"
```

| Method | Use for | Notes |
|---|---|---|
| `pmm` | Continuous, default | Predicts a regression value, then draws the imputed value from one of the `donors` (default 5) observed cases with the closest predicted value. Always returns a value that was actually observed somewhere, so it can't produce impossible values and naturally respects skew, bounds, and multimodality without you having to model them. The donor pool size trades bias (more donors → more regression-like, more bias if the model is wrong) against variance (fewer donors → noisier); 3–10 is the usual range, default 5 is fine for most cases. |
| `norm` | Continuous, when you specifically want draws from a fitted normal model rather than real donors | Can produce out-of-range values (negative ages, etc.); usually `pmm` is preferable. |
| `cart` | Any type, especially when relationships are non-linear, involve interactions you don't want to hand-specify, or there are many candidate predictors | Classification/regression tree per variable; handles mixed predictor types and interactions automatically. Mild risk of overfitting with very small samples. |
| `logreg` | Binary factor | Logistic regression; watch for "perfect prediction" (a predictor perfectly separates the classes within the observed data), which inflates coefficients and imputation variance — `mice` handles it by augmenting the data with a few weighted pseudo-observations (the White, Daniel & Royston fix, FIMD §3.6.2), but if it's happening a lot, consider `cart` instead. |
| `polyreg` | Unordered categorical, >2 levels | Multinomial logit. Gets slow and unstable with many levels or many predictors — `cart` is often more practical. |
| `polr` | Ordered categorical, >2 levels | Proportional-odds logistic regression. |
| `rf` | Same situations as `cart` but averaging over many trees (Doove et al., FIMD §3.5) | In mice itself (uses a random-forest backend such as `ranger`/`randomForest`); slower — only reach for it if `cart` is clearly underperforming. |
| `2l.pmm`, `2l.norm`, `2lonly.pmm`, `2lonly.norm`, `2l.groupmean` | Clustered / multilevel data | See `multilevel-imputation.md`. |

For semi-continuous data (a point mass at zero plus a continuous part, e.g. alcohol consumption,
medical costs), count data, or censored/rounded data, a two-step approach is often best: impute
whether the value is zero/positive (or above/below the censoring point) with `logreg`, then impute
the continuous part conditional on that with `pmm`. `mice`'s `squeeze()` is useful for keeping
imputed values within known bounds after the fact (e.g. a 0–100 percentage scale).

## `quickpred()` for datasets with many columns (mice manual; applied in FIMD §9.1)

When a dataset has dozens or hundreds of columns, letting every variable predict every other one
gets slow and the predictor matrix gets impossible to reason about by hand. `quickpred()` builds a
predictor matrix automatically based on a minimum correlation threshold:

```r
pred <- quickpred(dat, mincor = 0.1, minpuc = 0)
imp <- mice(dat, predictorMatrix = pred, m = 30, maxit = 20, seed = 1)
```

`mincor` keeps a predictor only if its correlation with the target (or with the target's
missingness indicator) exceeds the threshold; `minpuc` does the same using the proportion of
usable cases statistic. After running this, check `flux(dat)`/`fluxplot(dat)` — variables with low
influx *and* low outflux that aren't part of the analysis model are good candidates to drop
entirely before imputing, since they add modeling burden without adding information.

## Passive imputation for derived variables (FIMD §6.4)

If the analysis model needs a transformation, ratio, sum score, or interaction term, don't compute
it after separately imputing the components — that throws away the constraint that the derived
variable must be consistent with its inputs in every single imputed dataset. Instead, add the
derived variable to the data (as `NA`), give it a passive method (a formula starting with `~`), and
let `mice` recompute it every time its inputs are imputed:

```r
dat$bmi <- NA   # placeholder; will be recomputed
meth["bmi"] <- "~ I(weight / (height/100)^2)"

# interaction term example
dat$age_x_sex <- NA
meth["age_x_sex"] <- "~ I(age * sex)"
```

Passive imputation isn't a perfect solution — the joint distribution implied by separately imputing
the raw variables and then a passive function of them can be subtly incompatible — but it's the
standard, practical way to keep derived variables in sync, and it's far better than computing them
once on a single completed dataset.

## Visit sequence (FIMD §6.5.1)

By default `mice` imputes variables in the order they appear in the data, cycling through them
`maxit` times. This is usually fine. Two situations where it matters:

- **Derived/passive variables must be visited *after* the variables they depend on**, within each
  iteration, so they're recomputed from up-to-date imputations rather than stale ones. Pass an
  explicit order via `visit = c(...)` listing dependents right after their inputs.
- **Monotone missing-data patterns** (e.g. drop-out, where once a variable is missing everything
  after it is too) can be imputed faster and more stably by visiting variables in order of
  increasing missingness — `mice` can detect and exploit this automatically in many cases, but for
  hand-tuned models, ordering the visit sequence by missingness rate is good practice.

## Model form and predictor selection (FIMD §6.3)

A few practical defaults that make imputation models behave well:

- **Prefer inclusive over restrictive.** Including a predictor that turns out not to matter costs
  little; omitting one that does causes bias. Default to including everything that's plausibly
  related, then prune only if there's a concrete problem (collinearity, instability, runtime).
- **Don't impute a variable using a deterministic function of itself.** If `bmi` is derived from
  `weight` and `height`, exclude `bmi` from predicting `weight` or `height`'s imputation (and vice
  versa for any interaction term involving the target) — otherwise the imputation model becomes
  circular.
- **Quadratic and other non-linear terms**: if the analysis model includes `age + age^2`, either add
  `age^2` as its own passively-imputed variable, or impute with a method (`cart`) that can capture
  the curvature implicitly without needing the squared term spelled out.
- **Compositional data** (parts of a whole that must sum to a fixed total) need either a
  transformation (e.g. log-ratios) before imputing, or constraints enforced afterward — flag this to
  the person rather than imputing the parts independently and hoping they sum correctly.
