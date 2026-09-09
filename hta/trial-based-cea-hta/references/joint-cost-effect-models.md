# Joint models for cost and effect

> Source: BMHTA Ch. 5, worked in `05-ild/ild.R` (bmhta-examples @ `d2a6298`), which fits three
> models to the 10TT trial: Normal/Normal independent, Normal/Normal MCF, and Gamma/Gamma MCF.
> The book codes these in JAGS; the brms translations below are this repository's stack. Verify
> argument names against the installed brms before running.

## Why joint, and what "joint" means

Cost and effect are correlated within a patient. Two separate regressions, with their draws paired
afterwards, impose zero correlation on the CE plane. That is a modelling assumption, and almost
always a false one — so make it a parameter instead of an accident.

There are two ways to build the joint model, and they are algebraically related.

**Bivariate (SUR).** Model `(e, c)` as jointly distributed with a residual correlation:

```r
f_e <- bf(qaly   ~ arm + u0_c)
f_c <- bf(cost_k ~ arm)
fit <- brm(f_e + f_c + set_rescor(TRUE), data = trial,
           prior = priors, chains = 4, seed = 1234)
```

`set_rescor(TRUE)` estimates the residual correlation directly (`rescor__qaly__cost_k` in the
draws). This is the most transparent specification when both outcomes are Gaussian — and it is the
one to prefer in brms, because brms supports it natively. **It is only available for `gaussian()`
and `student()` families.**

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
unavailable and the conditional route is the only way to link them inside a single model. That is
the usual case for real economic data, so MCF is the workhorse. Its cost is a subtlety about
population averages — see below and `population-average-summaries.md`.

> The companion script reconstructs `sigma_c`/`rho` post-hoc using `beta1` where the JAGS model uses
> `beta2`. Use the coefficient on the *effect* in the cost equation (`beta2`), not the treatment
> coefficient. Stated here because the slip is easy to inherit by copying.

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
more mass in the extreme right tail. For a cost model whose whole purpose is to estimate a *mean*,
that tail does real work, and the Gamma is the more conservative default. Fit both and compare if
the tail is where the action is, but do not reach for log-normal by habit.

**Flipping a left-skewed outcome.** The book models QALYs with a Gamma by transforming
`e* = 3 − e`, which turns left skew into right skew, fits the Gamma to `e*`, and back-transforms.
Because the transformation is **linear**, `E[e] = 3 − E[e*]` exactly, so arm means come back
without approximation. Two conditions: the constant must exceed the maximum possible outcome (3 for
a 2-year trial whose QALYs cannot exceed 2), and it must be **fixed a priori**, not read off the
data's maximum — a data-dependent constant is a hidden parameter. Prefer `Beta()` on the natural
0–1 scale where the outcome genuinely lives there; the flip is a workaround for when you want
Gamma's tail behaviour on a bounded outcome.

**Arm-specific dispersion.** The source gives each arm its own SD/shape. Treatment can change the
*spread* of costs, not just their level, and forcing a common dispersion pushes that into the mean.
In brms this is a distributional formula:

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
the coefficients directly. Under a log link they do not. Standardise instead — average the
conditional mean over the observed distribution of effects within the arm — as set out in
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
on the £1,000 scale gives `lambda = −log(0.5)/2 ≈ 0.35`. Both appear in `05-ild/ild.R`. The virtue
is that the prior is stated as a *sentence about the data scale* — "an SD above 0.8 QALYs is a 1-in-100
surprise" — which a reviewer can argue with. In brms:

```r
prior(exponential(5.75), class = "sigma", resp = "qaly")
```

Do **not** use `Gamma(0.001, 0.001)` on a precision. It is the old BUGS default, it is not
uninformative, and on hierarchical scale parameters it concentrates mass near zero precision and so
pushes the SD upward. The book demonstrates this directly (Ch. 6).

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
