# Joint models for cost and effect

> Source: BMHTA §5.2 (Examples 5.2-5.4) and §5.2.3, verified against the online edition 2026-09-09.
> The book fits three models to the 10TT trial (n = 167 after complete-case exclusion):
> Normal/Normal
> independent (§5.2.1, Ex 5.2), Normal/Normal MCF (§5.2.2, Ex 5.3) and Gamma/Gamma MCF (Ex 5.4).
> The book codes these in JAGS; the brms translations below are this repository's stack. The brms
> claims here were checked against brms 2.23.0 on 2026-09-09.

## Why joint, and what "joint" means

Cost and effect are correlated within a patient. Two separate regressions, with their draws paired
afterwards, impose zero correlation on the CE plane. That is a modelling assumption, and almost
always a false one — so make it a parameter instead of an accident.

There are three ways to build the joint model in brms. The first two are algebraically related
under joint Normality. The third carries the dependence through a shared latent term instead, and
is set out at the end of this section; it is the route that generalises to any pair of families
without making one outcome a predictor of the other.

**Bivariate (SUR).** Model `(e, c)` as jointly distributed with a residual correlation:

```r
f_e <- bf(qaly   ~ arm + u0_c)
f_c <- bf(cost_k ~ arm)
fit <- brm(f_e + f_c + set_rescor(TRUE), data = trial,
           prior = priors, chains = 4, seed = 1234)
```

`set_rescor(TRUE)` estimates the residual correlation directly (`rescor__qaly__costk` in the draws
— brms strips non-alphanumeric characters from response names when it forms parameter names, so
`cost_k` becomes the `costk` prefix here and in `b_costk_*` too). This is the most transparent
specification when both outcomes are Gaussian — and it is the one to prefer in brms, because brms
supports it natively. **It is only available when every submodel shares one
family, and that family is `gaussian()` or `student()`** — a gaussian/student pair is refused too
(verified in brms 2.23.0). The book makes the same point from the other
direction: under joint Normality the MCF model *is* the seemingly-unrelated-regression model
(Zellner 1962; Willan and Briggs 2006), because every marginal and conditional of a multivariate
Normal stays Normal.

**Marginal-conditional factorisation (MCF).** Factor the joint density as
`p(e, c) = p(e) × p(c | e)`: model the effect marginally, then the cost *conditional on* the effect.

```r
f_e <- bf(qaly   ~ arm + u0_c)
f_c <- bf(cost_k ~ arm + qaly_c)          # qaly_c = effect, centred within arm
fit <- brm(f_e + f_c + set_rescor(FALSE), data = trial, ...)
```

One construction detail does not translate exactly. The source centres the effect on the
**model-implied** arm mean (a parameter, updated at every iteration); brms has no way to reference
another submodel's parameter inside a formula, so `qaly_c` above must be centred on the **observed**
arm mean, computed once as a data step. The difference is that the centring constant is treated as
known rather than estimated. For a trial of any reasonable size this is negligible, but it is an
approximation, so say so — and note that it makes the centring cosmetic rather than load-bearing:
what actually recovers the arm means is the standardisation in `population-average-summaries.md`,
not the centring.

Under joint Normality these two are **the same model**, reparameterised. The correlation and the
marginal cost SD are recoverable from the conditional ones:

```
sigma_c[t]^2 = lambda_c[t]^2 + beta2^2 * sigma_e[t]^2
rho[t]       = beta2 * sigma_e[t] / sigma_c[t]
```

where `lambda_c` is the *conditional* residual SD for costs given effects, `beta2` the coefficient
on the effect in the cost equation, and `sigma_c` the implied *marginal* cost SD. Compute these from
the draws so their uncertainty is carried:

```r
d <- as_draws_df(fit)
sigma_e  <- d$sd_qaly            # or the relevant sigma parameter
lambda_c <- d$sigma_cost_k
beta2    <- d$b_costk_qaly_c
sigma_c  <- sqrt(lambda_c^2 + beta2^2 * sigma_e^2)
rho      <- beta2 * sigma_e / sigma_c
```

MCF earns its place when the outcomes are **not** Gaussian, because then `set_rescor()` is
unavailable and the conditional route links them inside a single model without one. That is the
usual case for real economic data, so MCF is the workhorse. It carries two costs. One is a subtlety
about population averages — see below and `population-average-summaries.md`. The other is missing
data, in two layers. A missing **response** drops the row from *every* submodel of any brms
multivariate model, with only a warning ("Rows containing NAs were excluded from the model"):
20 rows with 5 missing effects give `N = 15` whether or not the effect is on the cost equation's
right-hand side, and under `set_rescor(TRUE)` as well as `FALSE` (verified on brms 2.23.0). That
complete-case collapse is general, not MCF's doing, and a bivariate model is not immune to it. What
*is* MCF-specific is the second layer: the cost equation's predictor is the effect, so a centred
column computed as a data step is `NA` for exactly the patients whose effect is missing, and brms
drops rows on a missing predictor too — `qaly | mi()` on its own still left `N = 48` of 60 there. So
the fix is a pair: `qaly | mi()` on the effect submodel and `mi(qaly)`, not the derived column, on
the cost equation's right-hand side, so the cost model conditions on the modelled (partly imputed)
effect. `mi(qaly)` without the addition term errors ("Response models of variables in 'mi' terms
require specification of the addition argument 'mi'"); with both, every randomised row survives.
Check `nobs(fit)` against the randomised sample either way. See `missing-economic-outcomes.md`.

> **A slip in the source, worth knowing before you copy it.** In §5.2.2 the JAGS model computes
> these
> correctly from `beta2`, but the R code immediately after — offered as an equivalent way to do the
> same algebra outside JAGS — extracts `beta1` and computes `sigma.c = sqrt(lambda.c^2 +
> sigma.e^2*beta1^2)`, `rho = beta1*sigma.e/sigma.c`. The book states the two give identical
> results;
> its own printed output shows otherwise, with `rho` changing sign (JAGS: −0.186, −0.099; R: +0.157,
> +0.083). Use the coefficient on the *effect* in the cost equation (`beta2`), not the treatment
> coefficient — and treat a sign flip between two routes to the same quantity as a bug signal.

**Shared or correlated random effect.** Neither route above links two *different* families
symmetrically: `set_rescor()` needs one shared family, and MCF makes one outcome a predictor of the
other.
The third construction puts a latent term in both linear predictors and lets the two be correlated.

```r
f_e <- bf(qaly   ~ arm + u0_c + (1 | p | id), family = gaussian())
f_c <- bf(cost_k ~ arm        + (1 | p | id), family = Gamma(link = "log"))
fit <- brm(f_e + f_c + set_rescor(FALSE), data = trial, prior = priors, seed = 1234)
```

The `p` between the bars is an arbitrary label telling brms that these two group-level terms share
one covariance matrix, so it estimates their correlation
(`cor_id__qaly_Intercept__costk_Intercept`) instead of fitting them independently. That correlation
is the cost-effect dependence, carried across a pair of families `set_rescor()` cannot span, and
`set_rescor(FALSE)` here is a requirement of the construction, not a dropped correlation. It is the
route available when the families differ and making one outcome a predictor of the other is
unwanted. It is also a skill addition rather than a translation: §5.2 covers the bivariate and
conditional constructions, not this one. Three things to get right:

- **What is identified.** With one cost and one effect per patient, a patient-level latent term is
  not separable from the Gaussian submodel's residual SD — only their sum is — so the split between
  `sd_id__qaly_Intercept` and `sigma_qaly` is driven by the prior. What the data do inform, through
  the cross-product of the two outcomes, is the implied **covariance** of cost and effect, and that
  is all the CE plane needs. So report the implied correlation of arm-level cost and effect computed
  from the draws on the natural scale, not the raw `cor_id__…` parameter, and give both latent SDs
  informative priors on the data's scale with a prior predictive check.
- **Which level the term sits at.** A latent term at the *patient* level carries the within-patient
  correlation, which is the one the CE plane needs. A term at the *site* or *centre* level carries
  only the between-cluster correlation and leaves the within-patient correlation at zero. In a
  cluster-randomised trial you generally need both terms; a site-level term alone is not a
  substitute, and reporting it as though it were is a real finding.
- **The arm means still need standardising.** Under a non-identity link the latent term sits inside
  the inverse link, so which random effects you condition on *is* the estimand — see
  `population-average-summaries.md`.

Under joint Normality this is a third parameterisation of the same model. With mixed families it is
not equivalent to MCF, and the two answer slightly different questions: MCF conditions the cost on
the realised effect, the shared term conditions both on a common latent frailty. Fit whichever the
data and the write-up can support, and state which.

## Choosing distributions

Look at the histograms by arm before choosing. The shapes are predictable:

| Outcome | Typical shape | Family | Why |
|---|---|---|---|
| Total costs | Strictly positive, right-skewed, long tail | `Gamma(link = "log")` | Positive support, multiplicative covariate effects, lighter tail than log-normal |
| Costs with a spike at zero | As above plus structural zeros | `hurdle_gamma()` | See `structural-values.md` |
| QALYs over a short horizon | Bounded above, left-skewed | `Beta()` on the 0–1 scale, or Gamma on a flipped scale | Respects the bound |
| QALYs with a spike at the maximum | As above plus structural ones | `zero_one_inflated_beta()` | See `structural-values.md` |
| Either, as a first pass | — | `gaussian()` | Fine as a baseline comparator; not usually the final model |

**Gamma rather than log-normal for costs.** At matched mean and SD the log-normal puts noticeably
more mass in the extreme right tail (the source shows this at mu = 8, sigma = 5, and cites Thompson
and Nixon 2005 for preferring the Gamma for costs). For a cost model whose whole purpose is to
estimate a *mean*, that tail does real work, and the Gamma is the more conservative default. Fit
both and compare if the tail is where the action is, but do not reach for log-normal by habit.

**Flipping a left-skewed outcome.** The book models QALYs with a Gamma by transforming
`e* = 3 − e` (a device it credits to Gabrio et al. 2025), which turns left skew into right skew,
fits the Gamma to `e*`, and back-transforms. Its reason for the flip is not only the skew: a few
patients had **negative** QALYs ("worse than death"), which a Gamma on the natural scale cannot
represent at all.
Because the transformation is **linear**, `E[e] = 3 − E[e*]` exactly, so arm means come back
without approximation. Two conditions: the constant must exceed the maximum possible outcome (3 for
a 2-year trial whose QALYs cannot exceed 2), and it must be **fixed a priori**, not read off the
data's maximum — a data-dependent constant is a hidden parameter. Prefer `Beta()` on the natural
0–1 scale where the outcome genuinely lives there; the flip is a workaround for when you want
Gamma's tail behaviour on a bounded outcome.

**Arm-specific dispersion.** The source gives each arm its own SD/shape, and so should you:
treatment can change the *spread* of costs, not just their level. But be precise about what a
**common** dispersion actually costs, because the obvious charge — a biased increment — is the
wrong one, and it is the wrong one in **both** families.

Dispersion enters the estimating equation for the mean coefficients as a precision weight, and the
two families differ only in what the weight is made of: `sum_i alpha_i * x_i (y_i − mu_i) / mu_i`
for `Gamma(link = "log")`, where `alpha_i` is the shape for patient `i`'s arm, and
`sum_i x_i (y_i − mu_i) / sigma_i^2` for `gaussian()` with an identity link, where `sigma_i` is
that arm's SD. A **common** dispersion is then a constant factor on the whole equation and drops
straight out, in either family, so it does not bias the arm means. Against an arm-specific fit the
means move only through the changed weighting, and only once the mean model carries a covariate
beyond arm (baseline utility, say). Under a correctly specified mean model both fits are consistent,
so the difference between them is sampling variability rather than bias: over 300 replicates at a
16:1 precision ratio with n = 400 the median shift was under 1% of the standardised increment but the
upper decile was several times that, in both families, and both shrank as `n` grew. Quote it as a
spread, not as a bound. Under a misspecified mean model the two converge to different answers, again
in either family.

What a common dispersion does get wrong, in either family, is the dispersion parameters and
everything downstream of them: the posterior SD of the incremental cost, the width of the CE-plane
cloud, and the CEAC. Report a shared dispersion as an **efficiency and interval-width** defect, not
as a biased increment. Do not grade a homoscedastic cost or effect model — the brms default — as
though the increment itself were suspect.

One consequence is genuinely Gaussian-specific. The Normal's out-of-range spill scales with `sigma`,
so a common `sigma` mis-sizes it arm by arm wherever a prediction is used as a number — imputation
especially (`structural-values.md`).

In brms, arm-specific dispersion is a distributional formula:

```r
f_c <- bf(cost_k ~ arm + qaly_c, shape ~ 0 + arm, family = Gamma(link = "log"))
```

Give the auxiliary formula its own prior — brms will not do it for you, and `get_prior()` shows a
separate row. See `brms-modelling`'s `references/model-families/distributional.md`.

## The log-link trap in an MCF cost model

With `family = Gamma(link = "log")`, the cost equation is

```
log(phi_c_i) = beta0 + beta1 * arm_i + beta2 * (e_i − ebar_t)
```

It is tempting to read the arm-level mean cost off as `exp(beta0 + beta1 * arm)` — setting the
centred effect term to zero. That is the mean cost **conditional on a patient at the arm-average
effect**, which is not the same thing as the arm's average cost, because `E[exp(X)] ≠ exp(E[X])`.
The gap is a Jensen term and it grows with `beta2^2 * var(e)`.

Under an identity link the two coincide, which is why the Normal/Normal models can read means off
the coefficients directly. Under a log link they do not. Standardise instead — integrate the
conditional mean over the effect distribution the arm *implies*, which is not the same as averaging
over the effects patients were observed to have — as set out in
`population-average-summaries.md`. This is the step most likely to be skipped, and it biases the
incremental cost.

**The same applies to the effects equation, and it is easier to miss there.** With
`log(phi_e_i) = alpha0 + alpha1 * arm_i + alpha2 * u0_c_i`, the quantity `exp(alpha0 + alpha1 * arm)`
is the mean at `u0_c = 0` — a patient at average baseline utility — and the arm's mean effect is
that multiplied by `E[exp(alpha2 * u0_c)]`, which is not 1. Mean-centring a covariate delivers the
population average **only under an identity link**. Under any other link, centring buys
interpretability and better sampler geometry, not the estimand. Standardise on both sides.

## Priors

The book uses **penalised complexity (PC) priors** on scale parameters: an Exponential prior on the
SD (not on the precision), with the rate chosen so that a stated tail probability holds. Solve for
the rate from a pair `(U, alpha)` meaning `Pr(sigma > U) = alpha`:

```
lambda = −log(alpha) / U
```

So `Pr(sigma_e > 0.8) = 0.01` gives `lambda = −log(0.01)/0.8 ≈ 5.75`, and `Pr(sigma_c > 2) = 0.5`
on the £1,000 scale gives `lambda = −log(0.5)/2 ≈ 0.35`. Both are the source's own values (Ex 5.2).
A shape or dispersion parameter needs one too, and is harder to reason about: for the Gamma/Gamma
model the source sets `Pr(nu > 30) = 0.01`, i.e. `Exponential(0.15)`, on both shapes.

The virtue is that the prior is stated as a *sentence about the data scale* — "an SD above 0.8 QALYs
is a 1-in-100 surprise" — which a reviewer can argue with. In brms:

```r
prior(exponential(5.75), class = "sigma", resp = "qaly")
```

Do **not** use `Gamma(0.001, 0.001)` on a precision. It is the old BUGS default, it is not
uninformative, and on hierarchical scale parameters it concentrates mass near zero precision and so
pushes the SD upward. The book demonstrates this directly in Ch. 6 (§6.2.5 and Note 6.3): the
implied prior on the SD has a very heavy right tail, and forward-sampling `rgamma(10000, 0.001,
0.001)` puts only 1.4% of the mass above 0.001, so the model infers large heterogeneity whatever the
data say. It discourages `Uniform(0, K)` for the same reason — the posterior piles up against `K`.

Regression coefficients on a sensibly-scaled outcome take weakly-informative Normals. State them
in the rescaled units (see `qaly-construction.md`) and run a prior predictive check — for a cost
model, check the implied mean costs are in the right order of magnitude, not merely finite.

## Model set

Fit a small ladder, not one model:

1. **Independent Normal/Normal** — the baseline that most published within-trial CEAs implicitly use.
2. **Joint Normal/Normal** (bivariate or MCF) — adds the correlation.
3. **Appropriate families with the correlation** (Gamma/Gamma or Beta/Gamma MCF) — adds the shapes.

Comparing them shows how much the correlation and the distributional assumptions each move the
answer, which is exactly the structural uncertainty a reviewer will ask about. Carry the comparison
through to the decision quantities rather than stopping at a fit statistic — see
`model-comparison-and-handoff.md`.
