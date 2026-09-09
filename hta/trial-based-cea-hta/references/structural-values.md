# Structural values: zero costs and QALYs at the maximum

> Source: BMHTA Ch. 10 (missing data and structural values in HTA), worked on the MenSS pilot trial
> in `10-missing-data/` (bmhta-examples @ `d2a6298`), which compares a Normal-Normal MCF, a
> Beta-Gamma MCF with the spike shifted away, and a Beta-Gamma hurdle model.

## What a structural value is

A **structural value** is an outcome that arises from a different process than the rest of the
distribution, and therefore piles up exactly on a boundary rather than being drawn from a continuous
density near it. Two are endemic in trial-based economic data:

- **Structural zeros in costs.** A patient who used no services has a cost of exactly £0. That is
  not "a small cost"; it is the outcome of a distinct decision (use any service at all?) that a
  continuous positive-support density cannot generate.
- **Structural ones in QALYs.** A patient in full health at every visit has a utility of exactly 1
  throughout, so their QALY is exactly the horizon length. On a 0–1 rescaled QALY that is a spike at
  1. Again a different process — "no health decrement at all" — not a draw from a density that
  happens to land near the top.

Both are common enough to matter. In the MenSS trial the spike at the maximum is visible in both
arms, and it is a substantial fraction of the sample.

## Why the obvious fixes fail

**Fit an unconstrained Normal.** The model has support on the whole real line, so posterior
predictions for a patient near the boundary spill past it — predicted QALYs above the maximum
achievable. Those impossible values are not cosmetic: they inflate the estimated arm mean, and the
inflation is not the same in both arms if the spike is not the same size in both. The incremental
effect is biased by an artefact of the support.

**Shift the spike away and use a bounded family.** Subtract a small `eps` (0.01, say) from every
QALY so nothing sits exactly at 1, then fit a Beta. Now the support is right, but two problems
remain. The shift biases every patient's outcome downward by `eps` — small, but systematic, and it
does not cancel in the increment if the arms have different spike sizes. More importantly it
**models the structural subgroup as though they were ordinary patients who happened to score
high**, which is exactly the claim the spike contradicts. It is a workaround, not a model.

## The hurdle / mixture model

Model the two processes separately and recombine. For structural ones in a bounded effect:

- an indicator `d_i ~ Bernoulli(gamma_i)` for "in the structural group", with `gamma_i` given its own
  logistic regression on treatment (and any covariates);
- for `d_i = 0`, a `Beta` model on the remainder — no shifting needed, because the spike has been
  removed by the first component;
- the population average for arm `t` is then the **mixture**:

```
mu_e[t] = (1 − gamma_bar[t]) * mu_e_lt1[t] + gamma_bar[t] * 1
```

where `gamma_bar[t]` is the arm's structural probability and `mu_e_lt1[t]` the mean among the
non-structural. This is the formula that must reach the draws — it is not enough to fit the mixture
and then report the Beta component's mean, which describes only part of the arm.

Note that the treatment effect can now act through **two channels**: it can change the probability
of being in full health (`gamma`), and it can change the outcome among those who are not. Reporting
only one is a partial answer. If the intervention works mainly by moving people into the structural
group, a model without the hurdle will attribute that to a shift in the continuous part and get the
magnitude wrong.

## In brms

brms has these families natively; there is no need to hand-roll the mixture:

| Data feature | Family |
|---|---|
| Costs with a spike at 0 | `hurdle_gamma()` or `hurdle_lognormal()` |
| Bounded effect with a spike at the maximum only | `zero_one_inflated_beta()` (rescale so the spike is at 1) |
| Bounded effect with spikes at both ends | `zero_one_inflated_beta()` |
| Bounded effect with a spike at 0 only | `zero_inflated_beta()` |

```r
f_e <- bf(
  qaly_01 ~ arm + u0_c,      # the Beta part, for the non-structural
  zoi     ~ arm,             # P(at a boundary at all)
  coi     ~ arm,             # P(that boundary is 1 | at a boundary)
  family  = zero_one_inflated_beta()
)
f_c <- bf(
  cost_k ~ arm + qaly_c,
  hu     ~ arm,              # P(structurally zero cost)
  family = hurdle_gamma()
)
fit <- brm(f_e + f_c + set_rescor(FALSE), data = trial, prior = priors, seed = 1234)
```

Two things to get right, both of which `brms-modelling`'s
`references/model-families/distributional.md` covers in general terms:

- **Put treatment in the boundary component's formula** (`zoi ~ arm`, `hu ~ arm`), not just the
  continuous part. Leaving it out assumes the intervention cannot change how many patients are in
  full health or use no services — usually the opposite of the hypothesis.
- **Give the boundary parameters their own priors.** They are on a logit scale, where a prior that
  looks flat can be strongly informative about a proportion near 0 or 1. Prior-predictive check the
  *implied proportion at the boundary*, not the coefficient.

Also note that **hurdle and zero-inflated are different models**, and for costs the hurdle is
usually right: a patient either used services or did not, and there is no second process generating
zeros among users. Zero-inflation would claim some zero-cost patients are "users who happened to
cost nothing", which is not a thing.

## Getting the arm mean out

Do not read the arm mean off the continuous component. `posterior_epred()` on a hurdle or
zero-one-inflated brms fit returns the **overall** expectation, mixture included — which is exactly
`mu_e[t]` above — so the standardisation recipe in `population-average-summaries.md` works
unchanged. That is the main practical reason to use the built-in families rather than fitting the
two components as separate models and combining them by hand.

Check it: the posterior mean effect should sit between the non-structural mean and the boundary
value, and the fitted proportion at the boundary should match the observed spike. A posterior
predictive check on *the proportion at the boundary* is the check that matters here:

```r
pp_check(fit, resp = "qaly01", type = "stat", stat = function(y) mean(y == 1))
```

A model that reproduces the density's shape but not the size of the spike has not solved the
problem it was introduced for.
