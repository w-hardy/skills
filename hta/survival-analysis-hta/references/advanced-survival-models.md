# Advanced survival models: splines, cure, relative survival

> Sources: R-HTA Ch. 7 (spline/Royston–Parmar via `flexsurvspline`, cure models, relative
> survival); `flexsurv` (incl. `bhazard`, `standsurv`) and `flexsurvcure` CRAN/pkgdown docs.
> Accessed 2026-07-03.

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

Knot locations are chosen automatically from quantiles of observed log event times; manual override is rarely needed. Key caveat: **flexibility improves fit to observed data, not extrapolation.** A spline with several knots can track the trial hazard beautifully and still extrapolate implausibly, because beyond the last knot it reverts to a linear (in log-time) tail whose slope is set by the final segment. Always plot the extrapolated hazard. Splines are most defensible when the trial is mature and the decision turns on short-term shape.

Alternative flexible approaches if the Royston-Parmar form doesn't fit well: log-hazard splines (`rstpm2`), penalised splines with many knots, fractional polynomials (no dedicated time-to-event R package; build as a custom `flexsurv` distribution or via Bayesian software).

## Cure models

When to use: a fraction θ of patients are plausibly "cured" and will never have the event (disease recurrence, cause-specific death). Requires `flexsurvcure`.

```r
library(flexsurvcure)

# Mixture cure: S(t) = 1 - (1 - theta) * S0(t); converges to theta as t -> inf
# By default the covariate goes on the cure fraction theta (via logistic regression)
cur1 <- flexsurvcure(Surv(years, status) ~ rx, data = RFS_data, dist = "gengamma")

# Put covariates on the uncured distribution's parameters instead/as well
cur2 <- flexsurvcure(Surv(years, status) ~ rx, data = RFS_data, dist = "gengamma",
                     anc = list(sigma = ~rx, mu = ~rx))

# Non-mixture cure: S(t) = theta^{F0(t)}
cur1_nm <- flexsurvcure(Surv(years, status) ~ rx, data = RFS_data,
                        dist = "gengamma", mixture = FALSE)

AIC(cur1, cur2, cur1_nm)
```

**Two identifiability traps, both worth stating explicitly to the user every time a cure model comes up:**
1. To estimate the cure fraction θ you must actually observe enough people surviving past the cure point — a curve that looks flat at the end of a *short* trial is not evidence of cure, it may just be sparse data. You need genuine long-term follow-up.
2. θ is often sensitive to the choice of uncured distribution S₀(t), because different distributions imply different hazards and hence different points where the modelled hazard converges with background. Report θ under more than one uncured distribution and treat the spread as structural uncertainty.

Important scope caveat: a cure model fitted to *trial-period* recurrence-free survival describes only the trial period and does not distinguish causes of death. For long-term extrapolation, all-cause mortality should rise even for "cured" patients, so combine the cure model with background mortality — typically via a relative-survival framework (below), per Latimer & Rutherford's guidance.

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

`bhazard` is only used for individuals who have the event; values for censored individuals are ignored. After fitting, `standsurv()` produces marginal all-cause or relative survival/hazard, combining the estimated relative survival with expected survival for predictions.

This is the most principled route for long-horizon extrapolation when population mortality is non-negligible, and it pairs naturally with the cure assumption ("cured patients revert to population mortality"). For the full external-data approaches (registry data, expert-elicited long-term survival, curve blending), see the `survextrap` and `blendR` packages, which jointly model short- and long-term evidence in a Bayesian framework.
