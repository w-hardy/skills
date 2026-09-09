# From a fitted model to arm-level posterior means

> Source: BMHTA Ch. 5 §"posterior predictive g-computation", worked in `05-ild/ild.R`
> §5.2.3 and Example 5.5, verified against the online edition 2026-09-09 (companion code
> `05-ild/ild.R`, bmhta-examples @ `d2a6298`).

The deliverable of this skill is two matrices of posterior draws — `S × T` for mean effect and
`S × T` for mean cost, `S` draws by `T` arms. Getting from a fitted model to those matrices is a
step in its own right, and it is where non-linear links quietly go wrong.

## The estimand

For each arm `t`, the quantity a cost-effectiveness analysis needs is the **population average
outcome if everyone were given treatment `t`**:

```
mu_t = E_X[ E[Y | treatment = t, X] ]
```

— the conditional mean averaged over the covariate distribution of the trial population. Not the
mean for a patient at average covariates, and not the average of the individuals actually assigned
to arm `t`.

The distinction is invisible under an identity link and material under any other. Under a linear
model, `E[Y | t, X̄] = E_X[E[Y | t, X]]`, so plugging the mean covariate into the linear predictor
gives the right answer and you can read the arm means straight off the coefficients. Under a log or
logit link, `E[g^{-1}(η)] ≠ g^{-1}(E[η])` — the two differ by a Jensen term — and reading the mean
off the coefficients is a bias, not a rounding error.

## The general recipe: standardise over the sample

Compute the conditional mean for **every patient in the trial** with the treatment set to `t`,
then average — once per posterior draw. This preserves the posterior; nothing is collapsed.

```r
library(tidybayes)

arm_means <- trial |>
  select(id, u0_c, qaly_c) |>              # every covariate in the model
  tidyr::expand_grid(arm = c(0, 1)) |>     # counterfactually set the arm
  add_epred_draws(fit, resp = "costk") |>  # conditional mean per patient per draw
  group_by(.draw, arm) |>
  summarise(mu = mean(.epred), .groups = "drop") |>   # average over patients
  tidyr::pivot_wider(names_from = arm, values_from = mu)
```

`add_epred_draws()` returns the *expectation* of the outcome (`posterior_epred()` under the hood),
which is what a mean cost needs. Three neighbouring functions are not interchangeable:

- `posterior_epred()` / `add_epred_draws()` — the conditional **mean**. This is the one you want.
  One exception bites in economic data: `cens()` and `trunc()` change the *likelihood* but not the
  family's mean function, so on a censored (Tobit) or truncated fit `posterior_epred()` returns the
  **latent** mean — the mean of the underlying uncensored variable — not the mean on the observed
  scale. Pricing an incremental cost or QALY at a threshold from a latent mean values a quantity the
  threshold does not apply to. Either construct the observed-scale mean explicitly from the draws,
  or state plainly that the reported estimand is latent.
- `posterior_predict()` / `add_predicted_draws()` — draws of a **new observation**, including
  residual noise. Its mean converges to the same place, but it adds Monte Carlo noise for nothing
  when you only want the mean. Use it for posterior predictive *checks*, not for the estimand.
- `posterior_linpred()` — the **linear predictor**, on the link scale. Averaging these and then
  inverting the link is exactly the mistake this section is about.

The `expand_grid(arm = ...)` step is what makes it a standardisation: every patient contributes to
both arms' means, so the two are averaged over the *same* covariate distribution and their
difference is a like-for-like contrast.

## Random effects: `re_formula` is the estimand

If the model has any group-level term — a site or centre intercept in a multi-centre trial, a
shared latent term linking cost to effect (`joint-cost-effect-models.md`) — then one argument
decides which population average you computed. brms offers three behaviours:

| Argument | What it computes | When that is the estimand |
|---|---|---|
| `re_formula = NULL` (default) | conditional mean **including** each row's own group-level effects | the trial population, when you average over the trial's own rows: every patient carries their site, so the sites enter in their realised proportions |
| `re_formula = NA` | group-level effects set to **zero** | a hypothetical group at the centre of the random-effect distribution — almost never what a CEA reports |
| `re_formula = NULL`, `allow_new_levels = TRUE`, `sample_new_levels = "gaussian"` | marginalises over the fitted random-effect **distribution** | a decision population of *new*, unobserved sites — wider, and defensible if the decision is about roll-out beyond the trial's centres |

The trap is `re_formula = NA` under a non-identity link. With a site random intercept `u ~ N(0,
sigma_u)` and a log link, the mean at `u = 0` is not the mean over sites: the population average is
larger by `E[exp(u)] = exp(sigma_u^2 / 2)`. At `sigma_u = 0.3` that is 4.6%, and because the factor
multiplies each arm's mean it **scales the incremental cost too** rather than cancelling out of it.
So a site random intercept plus a log link plus `re_formula = NA` is a real finding, and its size is
computable from `sd_site__Intercept` — quote it.

Under an identity link the two coincide in expectation, because `E[u] = 0`. Do not report
`re_formula = NA` as a defect in a Gaussian identity-link model; there it is a presentational
choice, not a bias.

Two practical consequences for the recipe above. The `newdata` frame must keep the **grouping
column** — expanding a grid of covariates without it either errors or, with `allow_new_levels`,
silently switches you to the new-sites estimand. And whichever behaviour you choose, say which in
the write-up: "means standardised over the trial's participants and centres" and "means for a new
average centre" are different numbers and different claims.

## The predictive route, and when it is needed

Where the link is non-linear, the same correction can be done by simulating from the fitted outcome
distribution per draw and averaging. The source does exactly this (Ex 5.5) for the Gamma model,
whose effects equation carries arm **and** centred baseline utility:

```r
d <- as_draws_df(fit)
n_mc <- 4000
mu <- matrix(NA_real_, nrow = nrow(d), ncol = 2)
for (s in seq_len(nrow(d))) {
  for (t in 1:2) {
    estar <- rgamma(n_mc, shape = d$shape[s, t], rate = d$shape[s, t] / d$phi[s, t])
    mu[s, t] <- mean(3 - estar)      # back-transform, then average
  }
}
```

The order is the whole point: **transform each simulated value, then average.** Averaging first and
transforming the average is the error being avoided.

When the back-transformation is **linear** — as `3 − e*` is — this is exactly equal to the direct
calculation `mu_e = 3 − mu_estar`, and the simulation is a demonstration rather than a necessity.
The source uses it that way, on the effects equation, and its results duly match the model's own
`mu.e` to three decimal places.

**The place it is actually needed in that same model is the cost equation**, whose log link makes
`mu.c[t] = exp(beta0 + beta1·arm)` the conditional mean cost at the arm-average effect rather than
the arm's mean cost. Standardise the cost side.

Note also what the predictive route as coded does *not* fix: it draws `e*` at `mustar.e`, the fitted
mean at centred baseline utility zero, so it marginalises over the outcome distribution but not over
the covariate distribution. Under a non-identity link you need both — draw over the observed
covariate values as well, as in the standardisation recipe above. The source gives the discrete-
covariate case explicitly (Eq 5.9): average `g^-1(.)` over the covariate's levels weighted by their
population frequencies, since centring only marginalises *continuous* covariates automatically.

## Preserving the pairing

Whatever route you take, all of it must run **per posterior draw**, and the effect and cost matrices
must be indexed by the same draws in the same order.

```r
stopifnot(nrow(mu_effect) == nrow(mu_cost))   # same S
stopifnot(ncol(mu_effect) == ncol(mu_cost))   # same T, same arm order
```

Three ways the pairing gets broken in practice, all silent:

- Fitting the effect and cost models as **separate `brm()` calls**. Even with the same seed the
  draws are not the same posterior; row `i` of one is unrelated to row `i` of the other. If you must
  fit separately, you have asserted independence — say so, and do not present a correlation.
- **Thinning, reordering or filtering** one matrix and not the other.
- Summarising to means or quantiles at any intermediate stage, then re-expanding.

Everything downstream — the CE plane's tilt, the CEAC, INB — is a functional of the joint
distribution. Pairing is the joint distribution.

## Standardising across multiple imputations

If missingness was handled by multiple imputation rather than in-model `mi()`
(`missing-economic-outcomes.md`), the standardisation runs **inside** each imputation. For
`m = 1 … M` completed datasets:

1. Fit the model to imputation `m`, or take imputation `m`'s block of draws.
2. For each posterior draw of that fit, compute the conditional mean for every participant **in
   imputation `m`'s own completed frame**, with the arm set counterfactually, and average over
   participants — the recipe above, unchanged. That yields one `S_m × T` matrix per imputation, per
   outcome.
3. **Stack** the `M` matrices row-wise into one `(M · S_m) × T` matrix, for cost and effect alike
   and in the same row order, so the pairing survives the stacking.

Do not pool with Rubin's rules. The stacked draws already carry both the within-imputation posterior
uncertainty and the between-imputation uncertainty, and the quantities downstream — CEAC, INB, EVPI
— are not means and cannot be rebuilt from a pooled mean and variance.

Two ways this goes wrong; the second is the silent one:

- **One set of draws applied to every frame.** `brm_multiple()` stacks the draws across imputations
  for you, but the returned object's `data` slot holds only the *first* completed dataset —
  `combine_models()` returns model 1 with the combined `stanfit` swapped in — so a bare
  `posterior_epred(fit)` standardises all `M · S` draws over imputation 1's participants, including
  its imputed values, used `M` times over. brms says so out loud: any post-processing of a
  `brmsfit_multiple` without `newdata` warns "Using only the first imputed data set. Please
  interpret the results with caution…". Treat that warning as the finding — it is greppable in a
  log — and spot-check an imputed cell against `fit$data`. `nrow(fit$data)` proves nothing here:
  every completed frame has the same `N`. Imputation `m`'s draws must meet imputation `m`'s frame,
  so keep the list of completed frames beside the fit and index the two together. (Its combined
  `Rhat` is inflated by genuine between-imputation variation for the same reason. There is no
  per-imputation diagnostic on the combined object — `fit$rhats` does not exist in brms 2.23.0. The
  documented route in `?brm_multiple` is to subset the combined draws by chain and diagnose each
  block — the chains are blocked by imputation, so with `chains = 1` chain `i` is imputation `i`:
  `posterior::subset_draws(posterior::as_draws_array(fit), chain = i)`. Fitting with
  `combine = FALSE`, to keep the `M` individual `brmsfit` objects, does the same job.)
- **Crossing draws with imputations.** Averaging one set of draws over all `M` frames, or forming
  the full draw × imputation product, inflates `S` without adding information and double-counts the
  imputation uncertainty.

Watch the size. The intermediate long frame is `M × S × N × T` rows — at `M = 50`, `S = 4,000`,
`N = 500` and two arms, 2 × 10^8 rows, which no tidybayes pipeline will survive. Take the average
over participants *inside* each imputation and discard the per-participant frame before stacking, or
work with `posterior_epred()`'s draws × observations matrix directly and `rowMeans()` over the
columns belonging to each arm.

## Sense checks before handing off

- Arm means are on the **natural scale**: costs in the currency the threshold uses, effects in
  QALYs. Undo any rescaling first (see `qaly-construction.md`).
- The **incremental** effect and cost have the sign and magnitude the raw arm summaries suggest. A
  large divergence from the crude difference in means is not automatically wrong — adjustment and
  the distributional assumptions should move it — but it needs an explanation, not a shrug.
- The arm-level means sit inside the range of the observed data. A mean QALY above the maximum
  achievable over the trial horizon means the model is unconstrained; see `structural-values.md`.
- `S` is large enough for what comes next. A thousand draws is enough for a CEAC; value-of-information
  wants more (`bayesian-cea-r-hta`'s `references/value-of-information.md`).
