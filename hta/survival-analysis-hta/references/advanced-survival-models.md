# Advanced survival models: splines, cure, relative survival

> Sources: R-HTA Ch. 7 (spline/Royston–Parmar via `flexsurvspline`, cure models, relative
> survival); `flexsurv` 2.3.2 (incl. `bhazard`, `standsurv`) and `flexsurvcure` 1.1.0
> CRAN/pkgdown docs and README, re-verified 2026-08-27, incl. empirical convergence testing;
> NICE DSU TSD 21 (Rutherford, Lambert, Sweeting et al., 23 Jan 2020) and Sweeting et al.
> (2023, Med Decis Making 43(6):737-748) for general-population mortality incorporation —
> both verified against the full documents, 2026-08-28.

Fitting patterns for the three advanced model classes that go beyond standard parametric distributions, with the identifiability and extrapolation caveats that matter for each.

## Spline (Royston-Parmar) models

When to use: enough short-term data to identify a flexible shape, and the conclusions depend on how the short-term hazard is modelled. The model expresses a link-transformed survivor function as a natural cubic spline of log time.

```r
library(flexsurv)

# k = number of internal knots; more knots = more flexible
# Default scale is "hazard" (link = log cumulative hazard) -> a PH model;
#   "odds" -> proportional odds (log-logistic at k=0);
#   "normal" -> probit (log-normal at k=0)
spl1 <- flexsurvspline(Surv(years, status) ~ rx, data = RFS_data, k = 2)

# Covariate on an ancillary spline coefficient (gamma1) -> non-proportional hazards
spl2 <- flexsurvspline(Surv(years, status) ~ rx, anc = list(gamma1 = ~rx),
                       data = RFS_data, k = 1)

AIC(spl1, spl2)
summary(spl1, type = "hazard", t = seq(0, 15, 0.1), tidy = TRUE)
```

Knot locations are chosen automatically from quantiles of observed log event times; manual override is rarely needed *for describing the observed data*. Key caveat: **flexibility improves fit to observed data, not extrapolation.** A spline with several knots can track the trial hazard beautifully and still extrapolate implausibly: beyond the **boundary knots**, the natural cubic spline is linear in log time by construction, so the link-transformed function continues as a straight line — on the default "hazard" scale the extrapolated tail is therefore a **Weibull whose shape is set by the spline's slope beyond the upper boundary knot**; on the "odds" scale it is log-logistic-like, and on the "normal" scale log-normal-like. Always plot the extrapolated hazard, and once the fit is going to be extrapolated (rather than just compared on AIC), treat both the number of internal knots and the **boundary knot placement** as first-order structural choices. Splines are most defensible when the trial is mature and the decision turns on short-term shape.

Alternative flexible approaches if the Royston-Parmar form doesn't fit well: log-hazard splines (`rstpm2`), penalised splines with many knots, fractional polynomials (no dedicated time-to-event R package; build as a custom `flexsurv` distribution or via Bayesian software).

## Cure models

When to use: a fraction θ of patients are plausibly "cured" and will never have the event (disease recurrence, cause-specific death). Requires `flexsurvcure`.

```r
library(flexsurvcure)

# Mixture cure: S(t) = theta + (1 - theta) * S0(t); S(0)=1, converges to theta as t -> inf
# By default the covariate goes on the cure fraction theta (via logistic regression)
cur1 <- flexsurvcure(Surv(years, status) ~ rx, data = RFS_data, dist = "weibull")

# Put covariates on the uncured distribution's parameters instead/as well
cur2 <- flexsurvcure(Surv(years, status) ~ rx, data = RFS_data, dist = "weibull",
                     anc = list(scale = ~rx, shape = ~rx))

# Non-mixture cure: S(t) = theta^{F0(t)}
cur1_nm <- flexsurvcure(Surv(years, status) ~ rx, data = RFS_data,
                        dist = "weibull", mixture = FALSE)

AIC(cur1, cur2, cur1_nm)
```

**Base distribution matters for convergence.** flexsurvcure's own README flags the generalised gamma and Gompertz base distributions as unreliable ("issues with convergence and numerical instability"), and this was reproduced directly: fitting `dist = "gengamma"` or `dist = "gompertz"` cure models on real data gave `Hessian not positive definite` warnings, in one case with a degenerate boundary estimate — meaning the SEs (and anything downstream, like a PSA) would be wrong without any obvious error. Prefer `weibull`, `lnorm`, or `llogis` as the base distribution (as above), and always check for a Hessian warning before trusting a cure model's SEs, whatever the base distribution.

**Two identifiability traps, both worth stating explicitly to the user every time a cure model comes up:**
1. To estimate the cure fraction θ you must actually observe enough people surviving past the cure point — a curve that looks flat at the end of a *short* trial is not evidence of cure, it may just be sparse data. You need genuine long-term follow-up.
2. θ is often sensitive to the choice of uncured distribution S₀(t): θ and the tail of S₀ are only weakly separately identified from the observed plateau. A heavier-tailed uncured distribution can attribute the late plateau to slow uncured events rather than to cure, so a smaller θ fits almost as well as a larger θ paired with a lighter-tailed S₀. Report θ under more than one uncured distribution and treat the spread as structural uncertainty.

Important scope caveat: a cure model fitted to *trial-period* recurrence-free survival describes only the trial period and does not distinguish causes of death. For long-term extrapolation, all-cause mortality should rise even for "cured" patients, so combine the cure model with background mortality — typically via a relative-survival framework (below). NICE DSU TSD 21 calls incorporating background mortality "essential for cure models" (p. 89).

## Relative survival

When to use: long-term extrapolation where disease-specific and other-cause mortality trend differently. Partitions all-cause hazard into background (from life tables) + excess (disease-specific):

```
h(t) = h*(t) + lambda(t)     # hazard scale
S(t) = S*(t) * R(t)          # survival scale: all-cause = expected x relative
```

In `flexsurv`, supply the expected background hazard per individual (matched by age/sex from national life tables) in the `bhazard` argument; the parametric model then estimates the *relative* survival / excess hazard:

```r
# dat must contain a column (here exp_haz) giving the expected population
# hazard at each individual's event/censoring time, from a matched life table
fit_rs <- flexsurvreg(Surv(years, status) ~ rx, data = dat,
                      dist = "weibull", bhazard = dat$exp_haz)
```

`bhazard` is only used for individuals who have the event; values for *right*-censored individuals are ignored (left/interval censoring needs a conditional probability instead — see `?flexsurvreg`). Two traps once the model is fitted:

- **Predictions from a `bhazard` fit are on the relative/excess scale.** `summary(fit_rs)` returns *relative* survival R(t) (and excess hazard), not all-cause survival — feeding it into an economic model as S(t) overstates survival. For all-cause predictions combine with expected survival: `standsurv()` produces marginal all-cause (or relative) survival/hazard given the matching expected rates.
- **AIC is not comparable across `bhazard` and all-cause fits.** An excess-hazard fit's log-likelihood omits data-dependent terms present in an all-cause fit's likelihood, so its AIC/BIC cannot be compared against an all-cause model fitted to the same data — compare like with like (relative-survival fits against other relative-survival fits, all-cause against all-cause).

**NICE DSU TSD 21** states that incorporating background mortality into survival models "is recommended … and is essential for cure models" (p. 89), and this internal additive-hazards route — building background mortality into the likelihood via `bhazard` — is the excess-hazard framework TSD 21 describes. A cruder alternative exists: a post-hoc hazard floor applied to an already-fitted all-cause curve (see `nice-economic-evaluation`'s `survival_extrapolation.R`), which only constrains the output where the fitted hazard has already dropped below background, not the likelihood itself — Sweeting et al. (2023, p. 738) note that this switching approach "causes a discontinuity in the all-cause hazard function" and describe excess-hazard modelling as the more statistically coherent route. Apply exactly **one** background-mortality mechanism in a given model — a floor, an additive excess hazard, or an SMR-based adjustment — never stack more than one.

This is the most principled route for long-horizon extrapolation when population mortality is non-negligible, and it pairs naturally with the cure assumption ("cured patients revert to population mortality"). For the full external-data approaches (registry data, expert-elicited long-term survival, curve blending), see the `survextrap` and `blendR` packages, which jointly model short- and long-term evidence in a Bayesian framework. Guyot et al. (2017, *Med Decis Making*) is a worked cancer-trial example of that joint-constraint approach — general-population and registry conditional-survival data enter the likelihood as constraints on a spline model alongside the RCT data, rather than being used only to check or select among already-fitted models, which the paper shows are often too inflexible to be consistent with both the trial data and the long-term constraints at once.
