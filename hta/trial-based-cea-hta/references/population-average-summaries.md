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
- `posterior_predict()` / `add_predicted_draws()` — draws of a **new observation**, including
  residual noise. Its mean converges to the same place, but it adds Monte Carlo noise for nothing
  when you only want the mean. Use it for posterior predictive *checks*, not for the estimand.
- `posterior_linpred()` — the **linear predictor**, on the link scale. Averaging these and then
  inverting the link is exactly the mistake this section is about.

The `expand_grid(arm = ...)` step is what makes it a standardisation: every patient contributes to
both arms' means, so the two are averaged over the *same* covariate distribution and their
difference is a like-for-like contrast.

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
