# Structural values: zero costs and QALYs at the maximum

> Source: BMHTA Ch. 10 (missing data and structural values in HTA), worked on the MenSS pilot trial
> §10.4.1, Example 10.2, verified against the online edition 2026-09-09 (companion code
> `10-missing-data/`, bmhta-examples @ `d2a6298`), which compares a Normal-Normal MCF, a
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

**A value on the boundary is not by itself a structural value.** The source's criterion is *excess*
frequency, and a mass at 1 has innocent sources: rounding, a capped or censored follow-up, and the
measurement convention itself — an EQ-5D index takes only the values its value set defines, and 1 is
the value of state 11111, with the next value down 0.883 on the UK 3L tariff and 0.950 on the
England 5L value set. A continuous distribution can also simply pile up near a bound. The diagnostic
is the gap: compare the count at the boundary with what a fitted continuous model puts in an equally
wide interval just below it, and check that the QALY spike really is full health at *every* visit
rather than one carried-forward or imputed utility.

## Why the obvious fixes fail

**Fit an unconstrained Normal.** The model has support on the whole real line, so posterior
predictions for a patient near the boundary spill past it — predicted QALYs above the maximum
achievable. Be precise about where that does damage, because the answer is not "everywhere":

- Under an **identity link on complete data**, the fitted arm mean is a linear projection and is
  **not** biased by the support violation. The Normal likelihood is doing quasi-likelihood work; the
  mean function is what you estimated, and it does not know or care that the assumed error
  distribution has impossible tails. Reporting a support violation as bias in the arm mean of a
  Gaussian base case is a false finding.
- Where it does bite is wherever an out-of-range **prediction** becomes a number you use. The
  source's own case is exactly this: the missing QALYs are imputed from the posterior predictive,
  the Normal model's imputations run past 1, and the overall mean effectiveness is inflated as a
  result — and not equally in both arms if the spike differs in size between them. The same applies
  if you report a predictive summary as though it were the estimand.
- It also bites under a **non-identity link**, where the mean is a function of the whole
  distribution rather than a projection of it.

So the test is not "does the model respect the bound" but "does any out-of-range value reach a
reported quantity". With complete data and an identity link the answer can legitimately be no.

**Shift the spike away and use a bounded family.** Subtract a small `eps` (0.01, say) from every
QALY so nothing sits exactly at 1, then fit a Beta. Note this only works at all when the observed
minimum is comfortably above `eps` — in the source's data the range was [0.61, 1], so nothing was
pushed below 0. Now the support is right, but two problems remain. Be exact about the first,
because the obvious complaint is wrong: a shift applied to *every* observation cancels out of a
difference in raw arm means — `(ybar_1 − eps) − (ybar_0 − eps) = ybar_1 − ybar_0` — whatever the
arms' spike sizes. It is moving only the observations *at* the boundary that fails to cancel,
displacing the raw increment by `−eps × (p_1 − p_0)` for spike fractions `p_t`. What the common
shift costs is sensitivity rather than bias: the Beta likelihood is non-linear in the data, so the
*model-implied* increment is not invariant to `eps` even though the raw difference is. That is the
source's own objection — the device is "potentially sensitive to the choice of the rescaling
factor" — so refit at two or three values of `eps` and report the spread. More importantly it
**models the structural subgroup as though they were ordinary patients who happened to score
high**, which is exactly the claim the spike contradicts. It is a workaround, not a model.

## The hurdle / mixture model

Model the two processes separately and recombine. For structural ones in a bounded effect:

- an indicator `d_i ~ Bernoulli(gamma_i)` for "in the structural group", with `gamma_i` given its own
  logistic regression. Predict it from real covariates, not just the arm — the source uses age,
  ethnicity, employment status and treatment, because who is in perfect health is a substantive
  question, not a treatment effect;
- for `d_i = 0`, a `Beta` model on the remainder — no shifting needed, because the spike has been
  removed by the first component;
- the population average for arm `t` is then the **mixture**:

```
mu_e[t] = (1 − gamma_bar[t]) * mu_e_lt1[t] + gamma_bar[t] * 1
```

where `gamma_bar[t]` is the arm's structural probability and `mu_e_lt1[t]` the mean among the
non-structural. (This is the source's own formula, §10.4.1; patients observed at exactly 1 are
treated as fixed members of the structural group, and only the rest are modelled.) This is the
formula that must reach the draws — it is not enough to fit the mixture and then report the Beta
component's mean, which describes only part of the arm.

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
  coi     = 1,               # P(that boundary is 1 | at a boundary): fixed, no structural zeros
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
zero-one-inflated brms fit returns the **overall** expectation, mixture included — `(1 − hu) · mu`
for `hurdle_gamma`, `zoi · coi + (1 − zoi) · mu` for `zero_one_inflated_beta` (brms 2.23.0) — so the
standardisation recipe in `population-average-summaries.md` works unchanged **for the effects
model**. That is the main practical reason to use the built-in families rather than fitting the two
components as separate models and combining them by hand. The cost model above is a different case:
it carries `qaly_c` on its right-hand side, so it needs the arm-`t` integration from that file's
"When the effect is on the cost equation's right-hand side" section, with the hurdle probability
carried as the `(1 − hu)` factor that section describes.

Check the correspondence with `mu_e[t]` rather than assuming it. `gamma_bar[t]` is the probability
of a structural **one**, which is `zoi × coi`, not `zoi`, and the two-component formula is the
model's own mean only when there is no mass at the other boundary — which is why `coi` is fixed
above. Leave `coi` free on data with no zeros and its posterior settles just below 1, putting
phantom mass at zero and pulling both arm means down. Where there really are spikes at both ends,
`mu_e[t]` as written does not apply and the mean is `zoi · coi + (1 − zoi) · mu`.

Check it: the posterior mean effect should sit between the non-structural mean and the boundary
value, and the fitted proportion at the boundary should match the observed spike. A posterior
predictive check on *the proportion at the boundary* is the check that matters here:

```r
pp_check(fit, resp = "qaly01", type = "stat", stat = function(y) mean(y == 1))
```

A model that reproduces the density's shape but not the size of the spike has not solved the
problem it was introduced for.
