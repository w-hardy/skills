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
  select(id, u0_c) |>                      # every covariate in the submodel — all baseline
  tidyr::expand_grid(arm = c(0, 1)) |>     # counterfactually set the arm
  add_epred_draws(fit, resp = "qaly") |>   # conditional mean per patient per draw
  group_by(.draw, arm) |>
  summarise(mu = mean(.epred), .groups = "drop") |>   # average over patients
  tidyr::pivot_wider(names_from = arm, values_from = mu)
```

Every covariate carried into that frame must be **measured before randomisation**. A submodel with a
post-randomisation predictor — the effect, on an MCF cost equation — cannot be standardised this way:
the counterfactual arm and the retained value then belong to different worlds. That case has its own
section below, and it is the one most often got wrong.

`add_epred_draws()` returns the *expectation* of the outcome (`posterior_epred()` under the hood),
which is what a mean cost or effect needs. Three neighbouring functions are not interchangeable:

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
the arm's mean cost. The cost side needs both the covariate average and an integral over the arm's
effect distribution — see the next section.

Note also what the predictive route as coded does *not* fix: it draws `e*` at `mustar.e`, the fitted
mean at centred baseline utility zero, so it marginalises over the outcome distribution but not over
the covariate distribution. Under a non-identity link you need both — draw over the observed
covariate values as well, as in the standardisation recipe above. What forces that is the link, not
the covariate's type: centring delivers the population average for a binary and a continuous
covariate alike under an identity link, and for neither under a log one. The source gives the
discrete case explicitly (Eq 5.9) — average `g^-1(.)` over the covariate's levels weighted by their
population frequencies — which is a convenient finite sum, not something centring achieved.

## When the effect is on the cost equation's right-hand side

An MCF cost model (`joint-cost-effect-models.md`) carries the **effect** as a predictor, and the
effect is post-randomisation. The estimand is

```
mu_c(t) = E_X[ E_{e | T=t, X} { E[c | e, T=t, X] } ]
```

— the cost mean integrated over the effect distribution **the simulated arm implies**, then averaged
over the covariates. Setting `arm = t` in `newdata` while leaving each patient's observed `qaly_c` in
place does not do that: it crosses a counterfactual arm with a factual effect, so the cost mean is
averaged over the allocation-weighted mixture of *both* arms' effect distributions — the same mixture
for every `t`. The arm means then differ only by `exp(beta1)`, and the reported mean cost is averaged
over a different effect distribution from the reported mean effect.

That mixture equals each arm's own law only when the centred effect is identically distributed in
both arms — common effect dispersion, no arm-by-covariate term, effect centred within arm — and under
an identity-link cost model linear in the effect it does not matter at all. The operative condition
is that `ebar` be **each arm's own** mean: centring on the pooled mean instead leaves the treatment
shift in the term, and measured at the true parameters that is as wrong as not centring at all —
+52% either way, against +0.1% for within-arm centring. Those are the source's Normal/Normal
conditions, which is why the
error stays hidden there. It bites under what this skill recommends elsewhere: arm-specific
dispersion, an arm-by-baseline interaction, a non-Normal effect family, or `mi(qaly)`, which puts the
**uncentred** effect on the right-hand side. In a Gamma-log check with `sigma_e` of 0.10 and 0.20 the
incremental cost came out 6% low; with the uncentred effect, 53% high.

**Closed form**, when the effect submodel is Gaussian and the effect enters the cost linear predictor
linearly. The inner integral is then the Normal moment generating function, so nothing is simulated:

```r
ebar    <- tapply(trial$qaly, trial$arm, mean)   # one centring constant per arm, named "0"/"1"
b2      <- as_draws_df(fit)$b_costk_qaly_c       # length S, recycles down an S x N matrix
mu_cost <- matrix(NA_real_, brms::ndraws(fit), 2)

for (a in c(0, 1)) {
  nd  <- transform(trial, arm = a, qaly_c = 0)               # effect term at a finite reference
  m   <- posterior_epred(fit, newdata = nd, resp = "qaly")   # S x N: E[e | a, X_i]
  s   <- posterior_epred(fit, newdata = nd, resp = "qaly", dpar = "sigma")  # S x N: sd(e | a, X_i)
  eta <- posterior_linpred(fit, newdata = nd, resp = "costk")               # S x N, log scale
  mu_cost[, a + 1] <- rowMeans(exp(eta + b2 * (m - ebar[[as.character(a)]]) + 0.5 * b2^2 * s^2))
}
```

Subtract **arm `a`'s own** centring constant, not the one belonging to the patient's observed arm,
and look it up by name: `ebar` is a named length-2 vector, so `ebar[a]` with the 0/1 arm code is a
silent indexing bug (`ebar[0]` is `numeric(0)`; `ebar[1]` is arm 0's constant). `dpar = "sigma"`
returns the effect SD on the response scale for each row, so a distributional `sigma ~ arm` is
handled. The exponentiated variance term does not cancel out of the increment even when dispersion
is common — it is a multiplier on both arm means — so dropping `0.5 * b2^2 * s^2` and plugging the
mean effect into the exponent is a *separate* error, the Jensen one, worth about 1.6% in the check
above with a common dispersion and 6.7% with an arm-specific one.

**Nested Monte Carlo**, when the effect family is not Gaussian and you do not want to do the
integral. Check first whether it is elementary: a Gamma effect has one too, since
`E[exp(b·e)] = (1 − b/rate)^(−shape)` for `b < rate`, and Gamma is the family this skill reaches for
on a flipped QALY. That closed form also exposes something the simulation hides — for `b ≥ rate` the
marginal mean cost is **infinite**, and nested Monte Carlo returns a plausible finite number anyway
(at `b/rate = 1.125`, truth `Inf` against a simulated 1.6e7). Raising `R` will not reveal it,
because the estimator's own variance is infinite there; only the algebra will. For a Beta or
`zero_one_inflated_beta` effect the integral is not elementary, but it is one-dimensional, so
`integrate()` over the effect density is exact to tolerance and carries no inner Monte Carlo noise.

Where you do simulate, draw the effect from its arm-`a` predictive distribution and push each draw
through the cost mean:

```r
R  <- 200                                                    # inner draws per patient
i  <- rep(seq_len(nrow(nd)), R)                              # (1..N, 1..N, ...) — not `each`
es <- posterior_predict(fit, newdata = nd[i, ], resp = "qaly")
mu_cost[, a + 1] <- rowMeans(exp(eta[, i] + b2 * (es - ebar[[as.character(a)]])))
```

That goes inside the same `for (a in ...)` loop and reuses its `nd`, `eta` and `b2`. The `rep()`
without `each` is load-bearing: it makes column `j` of `es` the effect drawn for patient `i[j]` at
the same posterior draw as `eta[, i][, j]`, so `rowMeans()` averages over patients and inner draws
in one pass.

The linear predictor is linear in the effect term whatever the families are, so
`eta[, i] + b2 * (es - ebar[[as.character(a)]])` rebuilds it per draw and you then apply the cost
family's own mean function: `exp()` above for `Gamma(link = "log")`, the identity for `gaussian()`,
and `(1 - hu) * exp(.)` for `hurdle_gamma()` with the arm-`a` hurdle probability from
`dpar = "hu"` — which is a constant factor only while `hu` itself does not carry the effect; if it
does, it goes inside the average with the rest.
Putting the drawn effects into `newdata` instead does not work — `newdata` is shared by every draw,
so it cannot carry a per-draw effect. `posterior_predict()` is right here and `posterior_epred()` is
not: the integral is over the effect *distribution*, not its mean. The inner draws leave Monte Carlo
noise inside each posterior draw and inflate the posterior SD, so raise `R` until the SD stops
moving, and chunk over patients rather than materialising `S x N x R`.

One thing that looks like the error and is not: averaging the fitted conditional mean over the
patients **actually in arm `a`**, observed effects and all, is consistent for `mu_c(a)` under
randomisation. It is simply not standardised, so the two arms rest on different covariate samples.

**Under `mi()`, two things change.** On a `qaly | mi()` plus `mi(qaly)` fit the cost equation's
predictor is the raw `qaly` column, not `qaly_c`, so zeroing `qaly_c` zeroes a column the model does
not contain. Set `nd$qaly <- 0` instead, take `ebar` as **0** because `mi()` puts the *uncentred*
effect on the right-hand side, and read the coefficient from `bsp_costk_miqaly` — `mi()` terms get
the special-effects `bsp_` prefix, not `b_`. The rest of the closed form is unchanged.

The second change is a trap. `posterior_epred()` and `posterior_linpred()` with `newdata` return
`NA` for every row whose `qaly` is `NA` in `newdata`, without a warning, where the same call with no
`newdata` uses the imputed latent value (verified on brms 2.23.0). `mean()` over that frame is `NA`,
and `na.rm = TRUE` quietly turns the standardisation into a complete-case one. Replacing the effect
column as above avoids it; leaving the observed column in place does not.

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
   participants — the recipe above, unchanged, including the arm-`t` integration wherever the cost
   model carries the effect. That yields one `S_m × T` matrix per imputation, per outcome.
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
