# Survival output → economic model inputs

> Sources: R-HTA Ch. 7 (survival-to-decision-model hand-off) and Ch. 9 §9.3.2
> (rate↔probability conversion); `flexsurv` and `survHE` (`make.transition.probs()`,
> `markov_trace()`) CRAN/pkgdown docs. Accessed 2026-07-03.

Worked patterns for turning a fitted `flexsurv` survival model into the inputs an economic model needs, and propagating the survival model's uncertainty correctly. This is the receiving end's counterpart: the `decision-modelling-hta` skill's `compute_surv()`/manual-conversion guidance consumes what's produced here.

## The conditional transition probability

For a discrete-time state-transition (Markov) model, the per-cycle transition probability for the event is:

```
tp(t, t+1) = 1 - S(t+1) / S(t)
```

the probability of the event during cycle t→t+1 *given* event-free survival to t. Because this varies by cycle, it makes the Markov model **time-inhomogeneous** automatically.

## Manual conversion from a fitted model (full control)

Use this when the transition feeds a cure/mixture structure, or when you want to see every step. The pattern is the same for any distribution — swap the cumulative-hazard function (`Hgompertz`, `Hweibull`, `Hllogis`, `Hlnorm`, `Hgengamma`, etc., all from `flexsurv`).

```r
library(flexsurv)

# Gompertz example: pull the fitted parameters off the natural-scale res matrix
sh <- fit_gompertz$res["shape", "est"]
rt <- fit_gompertz$res["rate",  "est"]

# Survivor function from the cumulative hazard: S(t) = exp(-H(t))
S <- function(t) exp(-Hgompertz(t, shape = sh, rate = rt))

# One transition probability per cycle boundary
cycles <- 0:n_cycles
tp <- 1 - S(cycles[-1]) / S(cycles[-length(cycles)])   # length n_cycles
```

`tp` then drops into a `model_time`-indexed transition matrix in heemod (see the `decision-modelling-hta` Markov reference), or you can let heemod do the same conversion internally with `compute_surv(fit_gompertz, time = model_time, type = "prob")`.

## Automated conversion (survHE)

From a `survHE::fit.models` object, `make.transition.probs()` produces cycle-by-cycle transition probabilities directly, and `markov_trace()` will run the resulting trace — useful when the whole pipeline is already in survHE:

```r
library(survHE)
tps <- make.transition.probs(fits, labs = ..., ...)   # see ?make.transition.probs for arg shape
```

Check the exact argument shape against the installed `survHE` version (`?make.transition.probs`) — survHE's economic-modelling helpers have been evolving and the signature is worth confirming rather than assuming.

## Partitioned survival models (PSM)

Common in oncology. No transition probabilities at all: state membership is read directly off independently-extrapolated curves. With PFS and OS curves,
- proportion in the **progression-free** state at time t = S_PFS(t)
- proportion **dead** at t = 1 − S_OS(t)
- proportion **progressed (alive)** = S_OS(t) − S_PFS(t)

The one structural pitfall: nothing constrains S_PFS(t) ≤ S_OS(t) when the two curves are fitted independently, so the "progressed" proportion can go negative at some t. Check for and handle crossing (e.g. constrain, or model jointly) before using the areas.

## Propagating uncertainty (do not skip)

Treating the fitted parameters as fixed point estimates understates uncertainty — the survival model's parameter uncertainty is often a large share of the total. Sample the parameters on the **transformed (real-line) scale**, where the asymptotic normal approximation holds, using the fit's covariance:

```r
library(MASS)
mu    <- fit_gompertz$res.t[, "est"]      # transformed-scale estimates
Sigma <- vcov(fit_gompertz)               # covariance on the same scale
draws <- mvrnorm(n_samples, mu = mu, Sigma = Sigma)

# Back-transform each draw before use (shape/rate are exp() of the
# log-scale parameters for Gompertz), then recompute tp per draw.
```

Two things that matter here:
- **Sample jointly, not parameter-by-parameter.** The parameters of one survival fit are correlated (e.g. shape and rate), and `vcov()` carries that — independent draws would distort the implied survival curves.
- **Carry the correlation downstream.** If these draws generate a *set* of transition probabilities that then enter a PSA alongside other parameters, the induced correlation among those transition probabilities should be preserved, not broken by resampling them independently. This is the same point the `decision-modelling-hta` PSA section makes about correlated parameters from a common fit.

For full posterior uncertainty rather than the asymptotic-normal approximation, fit the survival model Bayesianly (`survHE` with `method = "hmc"` or `"inla"`) and carry the posterior draws straight through — preferable when the extrapolation uncertainty is central to the decision.
