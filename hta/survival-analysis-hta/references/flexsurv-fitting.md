# Fitting parametric survival models with flexsurv

> Sources: R-HTA Ch. 7 (colon-cancer example; `flexsurvreg`, `hr_flexsurvreg`, distribution
> menu, batch fitting via `survHE::fit.models()`); `flexsurv` 2.3.2 and `survHE` 2.0.51
> CRAN/pkgdown docs, re-verified 2026-08-27 incl. empirical fitting and survivor/hazard-function
> derivation. Accessed 2026-07-03; re-verified 2026-08-27.

Patterns for `flexsurvreg()`, the distribution menu, the AFT-vs-PH distinction, and putting covariates on location vs. ancillary parameters. Illustrative data: a single time-to-event outcome `Surv(years, status)` with a treatment covariate `rx`, mirroring the book's colon-cancer recurrence-free survival example.

## The distribution menu and hazard shapes

`flexsurvreg(..., dist = )` accepts these built-ins. **Pick based on the empirical hazard shape you saw in exploration, not by fitting all of them blindly.**

| `dist` | Hazard shape | Notes |
|---|---|---|
| `"exp"` | Constant (λ) | Memoryless; rarely plausible for extrapolation but a useful baseline |
| `"weibull"` | Monotonic increasing/decreasing/constant, h(t) ∝ t^(shape−1) | AFT parameterisation in flexsurv; `dist = "weibullPH"` gives the PH parameterisation of the same distribution instead; `"weibull"` is the default workhorse |
| `"gamma"` | Monotonic, complex form | |
| `"gompertz"` | Exponentially increasing/decreasing | PH form; used for human mortality at older ages; negative shape ⇒ a **defective** distribution — S(∞) > 0 and mean survival is infinite, so this should be a deliberate cure-like choice, not an accidental fit |
| `"lnorm"` | Unimodal (rises then falls) | AFT; good when hazard peaks early then declines |
| `"llogis"` | Decreasing, or unimodal like log-normal | AFT |
| `"gengamma"` | Includes Weibull, gamma, log-normal as special cases | 3-parameter; flexible; the book's best fit for colon data. Needs enough data to identify 3 params |

`flexsurv`'s parameterisations match the base R `d*` functions (`dweibull`, `dgompertz`, etc.), **not** `survreg`'s. The "Distributions reference" vignette in flexsurv is the authority on exact survivor functions and covariate-effect interpretations. For delayed entry / left-truncated data (e.g. registry patients entering follow-up at diagnosis age), use counting-process notation — `Surv(start, stop, status)` — which `flexsurvreg` supports.

## Basic fit, single arm

```r
library(flexsurv)
fit_gg <- flexsurvreg(Surv(years, status) ~ 1, data = RFS_lev, dist = "gengamma")
fit_gg                      # prints estimates with 95% CIs and SEs
plot(fit_gg)                # fitted S(t) over KM
plot(fit_gg, type = "hazard", ylim = c(0, 0.5))   # fitted hazard over muhaz estimate
```

The parameter estimates (mu, sigma, Q for gengamma) are mostly not directly interpretable — read the model through the survivor/hazard plots and the survival quantities (`summary()`), not the raw coefficients.

## Treatment effect: PH vs AFT, and where the covariate goes

Two ways a covariate can act, with different interpretations:
- **Proportional hazards (PH)**: covariate multiplies the hazard; effect is a constant hazard ratio `exp(β)`. Exponential, Gompertz, the Weibull-PH form (`dist = "weibullPH"`), and the hazard-scale spline are PH.
- **Accelerated failure time (AFT)**: covariate speeds/slows the time axis. Exponential, Weibull (flexsurv's default form), gamma, log-normal, log-logistic, and generalised gamma are AFT.

Exponential and Weibull are the only two families that are simultaneously PH and AFT, so only they let you convert a fitted coefficient into a constant hazard ratio. But check **which parameter the covariate sits on** (`fit$dlist$location`) before converting: for `dist = "weibull"` the covariate acts on log *scale* (a log-time effect), and log HR = −shape × the coefficient; for `dist = "exp"` (and `"gamma"`) the covariate acts on log *rate*, so for the exponential the coefficient already **is** the log HR — no negation, no shape multiplier (negating it reverses the treatment effect). The PH families above (Gompertz, `weibullPH`, hazard-scale spline) give a constant HR `exp(β)` by construction; the remaining AFT families (log-normal, log-logistic, generalised gamma) yield no constant HR at all (see the pitfalls in the main `SKILL.md`).

By default a covariate added to the formula goes on the **location parameter**:

```r
# Treatment on location parameter only (an AFT model for gengamma)
ggt_aft <- flexsurvreg(Surv(years, status) ~ rx, data = RFS_data, dist = "gengamma")
```

To relax the PH/AFT assumption, put the covariate on **ancillary** parameters too, via `anc`:

```r
# rx also affects sigma (a compromise between AFT and fully-stratified)
ggt2 <- flexsurvreg(Surv(years, status) ~ rx, anc = list(sigma = ~rx),
                    data = RFS_data, dist = "gengamma")

# rx on all parameters == fitting the distribution separately per arm (stratified)
ggt3 <- flexsurvreg(Surv(years, status) ~ rx, anc = list(sigma = ~rx, Q = ~rx),
                    data = RFS_data, dist = "gengamma")

AIC(ggt_aft, ggt2, ggt3)    # compare; the book's middle model wins on AIC
```

Putting the treatment covariate on *all* parameters is equivalent to a fully stratified analysis (separate model per arm) — useful when you don't want to assume any particular functional form for the relative effect, at the cost of more parameters.

## Whether to model arms jointly or separately

- **Independent per arm**: maximum flexibility, no assumption on the relative-effect form. Good when hazards cross or converge (PH clearly violated), as in the book's Lev vs Lev+5FU comparison.
- **Shared baseline + relative effect (PH or AFT)**: more intuitive to modify extrapolations and easier to inform the relative effect from external data, but imposes a functional form on the treatment effect that should be checked.

Check the assumption graphically: plot log-cumulative-hazard vs log-time (parallel curves ⇒ PH plausible) or the time-varying hazard ratio:

```r
# Time-varying HR with CIs (flexsurv >= 2.2)
hrs <- hr_flexsurvreg(ggt_aft, t = seq(0.2, 15, 0.1),
                      newdata = data.frame(rx = c("Obs", "Lev+5FU")))
```

A HR that drifts systematically away from a horizontal line is evidence against PH. The converse doesn't hold: a non-significant `cox.zph` test or a plausibly-parallel log-cumulative-hazard plot is an *absence of evidence against* PH, not confirmation of it — power is low with few events, so don't treat a clean-looking check as licence to skip the sensitivity of your conclusions to the PH assumption.

## Model choice quantities

```r
AIC(fit1, fit2, fit3)               # lower is better; penalises parameters
BIC(fit1, fit2, fit3)               # more conservative, esp. large n
# Restricted mean survival to a horizon -- the economically relevant summary
summary(fit_gg, type = "rmst", t = 15, tidy = TRUE)
# Mean survival (full extrapolation to infinity); use with care -- depends
# entirely on the extrapolated tail
summary(fit_gg, type = "mean", tidy = TRUE)
```

RMST to a finite horizon is usually safer to report and compare than the mean-to-infinity, because the mean is dominated by the (unobservable) extrapolated tail.

## Batch-fitting with survHE

To fit several distributions at once and compare, `survHE::fit.models()` wraps repeated `flexsurvreg` calls:

```r
library(survHE)
mods <- c("exp", "weibull", "gompertz", "lnorm", "llogis", "gengamma")
fits <- fit.models(Surv(years, status) ~ rx, data = RFS_data,
                   distr = mods, method = "mle")
print(fits)                 # AIC/BIC table across all distributions
plot(fits)                  # overlaid fitted survival curves
model.fit.plot(fits)        # AIC/BIC comparison plot
```

`method = "mle"` uses flexsurv under the hood; `survHE` can also fit Bayesian versions via `"inla"` or `"hmc"` if those back-ends are installed, which gives full posterior uncertainty rather than asymptotic SEs — worth it when the extrapolation uncertainty needs to be characterised properly.
