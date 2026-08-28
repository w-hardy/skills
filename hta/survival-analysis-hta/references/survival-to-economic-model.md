# Survival output → economic model inputs

> Sources: R-HTA Ch. 7 (survival-to-decision-model hand-off) and Ch. 9 §9.3.2
> (rate↔probability conversion); `flexsurv` 2.3.2 and `survHE` 2.0.51 (`make.transition.probs()`,
> `three_state_mm()`, `markov_trace()`, `normboot.flexsurvreg()`) source/CRAN/pkgdown docs and
> empirical testing, re-verified 2026-08-27. Accessed 2026-07-03; re-verified 2026-08-27.

Worked patterns for turning a fitted `flexsurv` survival model into the inputs an economic model needs, and propagating the survival model's uncertainty correctly. This is the receiving end's counterpart: the `decision-modelling-hta` skill's `compute_surv()`/manual-conversion guidance consumes what's produced here.

## The conditional transition probability

For a discrete-time state-transition (Markov) model, the per-cycle transition probability for the event is:

```
tp(t, t+1) = 1 - S(t+1) / S(t)
```

the probability of the event during cycle t→t+1 *given* event-free survival to t. Because this varies by cycle, it makes the Markov model **time-inhomogeneous** automatically.

**Assumptions this formula makes.** `tp` as written gives the probability of a **single** modelled event from a state with only one exit. If a state has competing exits (e.g. progression vs. death from a pre-progression state), do not fit each exit's net/latent survival independently and plug both into this formula as per-transition probabilities — they can sum to more than 1, and doing so imposes an unstated (and usually false) independence assumption between the competing events. Work from cause-specific hazards instead. The probability that the *first* event in a cycle is of cause `k` is exactly `p_k = ∫_t^{t+1} h_k(u) · exp(−Σ_j [H_j(u) − H_j(t)]) du` — cause k's hazard weighted by within-cycle event-free survival. The practical closed form, with `ΔH_j = H_j(t+1) − H_j(t)` the cause-specific cumulative-hazard *increments*, is `p_k = (ΔH_k / Σ_j ΔH_j) · (1 − exp(−Σ_j ΔH_j))`: it splits the total exit probability `1 − exp(−Σ_j ΔH_j)` (which is always exact) in proportion to the increments, and is itself **exact when the cause-specific hazards are constant within the cycle — or, more generally, keep a fixed ratio to one another across it**. Otherwise it is a short-cycle approximation: the error is second-order in the per-cycle total cumulative hazard and only mis-allocates probability between causes (under-stating a cause whose share of the total hazard falls across the cycle) — with two Weibull causes of shapes 0.35 and 4 the mis-split is ~0.1% of the smaller probability at monthly cycles, but of order 10–40% at annual cycles carrying an ~87% per-cycle event risk (the exact figure depends on where the cycle falls in the time course). Shorten the cycle (or chain the formula over sub-cycles) when in doubt, and hand off to the `multistate-models-hta` skill for the full competing-risks machinery when within-cycle hazards vary strongly relative to one another, cycles are long, more than about two exits compete, or the clock is semi-Markov. Post-progression transitions raise a related question — whether the fitted hazard depends on time since randomisation (clock-forward/Markov) or time since progression (clock-reset/semi-Markov) — see the same skill.

Also guard against `S(t)` underflowing to exact double-precision `0` at long horizons: once that happens, `1 - S(t+1)/S(t)` becomes `0/0 = NaN` for every subsequent cycle. Cap the grid at the last `t` where `S(t) > 0`, or compute `tp` from cumulative-hazard differences instead (`1 - exp(-(H(t+1) - H(t)))`), which stays well-behaved past that point.

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

Caveat: on a model fitted **with covariates**, `fit$res["...", "est"]` gives the parameter at the **reference level only** — the snippet above then silently produces the reference-arm curve for every patient. For a covariate model, use `summary(fit, type = "survival", t = ..., newdata = ...)` per arm (or `normboot.flexsurvreg(fit, newdata = ...)` when drawing for a PSA), not a hand-pulled `$res` row.

## Automated conversion (survHE)

From a `survHE::fit.models` object, `make.transition.probs()` computes one transition's cycle-by-cycle probability curve for a given covariate profile — it does **not** return a full transition matrix, and it does not run a cohort trace:

```r
library(survHE)
tp <- make.transition.probs(fits, mod = 1)   # a profile/time/lambda tibble, one transition
```

To actually simulate a trace, `three_state_mm()` runs a fixed three-state illness-death cohort simulation — it needs **three separate** `fit.models` objects (one per transition: pre-progression→progression, pre-progression→death, progression→death) and calls `make.transition.probs()` internally for each. `markov_trace()` then only **plots** that trace (it returns a `ggplot`); it does not accept `make.transition.probs()`'s output directly and does not itself run or simulate anything:

```r
mm <- three_state_mm(fit_12, fit_13, fit_23, ...)   # a list; mm$m is the state-occupancy tibble
markov_trace(mm)                                     # plots mm's trace
```

Both helpers are scoped to exactly that fixed three-state structure, not a general n-state Markov-trace utility — for any other state structure, use the manual conversion above and feed the resulting `tp` into `heemod` (or your own trace loop) instead. These helpers' argument names have shifted across survHE releases (verified here against survHE 2.0.51), so check them against the installed version.

## Partitioned survival models (PSM)

Common in oncology. No transition probabilities at all: state membership is read directly off independently-extrapolated curves. With PFS and OS curves,
- proportion in the **progression-free** state at time t = S_PFS(t)
- proportion **dead** at t = 1 − S_OS(t)
- proportion **progressed (alive)** = S_OS(t) − S_PFS(t)

The one structural pitfall: nothing constrains S_PFS(t) ≤ S_OS(t) when the two curves are fitted independently, so the "progressed" proportion can go negative at some t. Check for and handle crossing (e.g. constrain, or model jointly) before using the areas. More broadly, post-progression survival is only modelled *implicitly* in a PSM — NICE DSU TSD 19 (Recommendation 11) formally recommends building a state-transition model *alongside* the partitioned-survival analysis as a cross-check on that implicit assumption (while stopping short of recommending PSM be replaced); the `multistate-models-hta` skill covers the state-transition side.

## Propagating uncertainty (do not skip)

Treating the fitted parameters as fixed point estimates understates uncertainty — the survival model's parameter uncertainty is often a large share of the total.

**Preferred: let flexsurv do the sampling and back-transformation.** `normboot.flexsurvreg(fit, B = n_samples, newdata = ...)` draws on the transformed scale from `vcov()` and applies each parameter's own inverse transform, correctly handling covariates and splines:

```r
library(flexsurv)
draws <- normboot.flexsurvreg(fit_gompertz, B = n_samples)   # natural-scale parameter draws
```

Or go straight to the quantity you need with `summary(fit, type = "survival"/"rmst", t = ..., B = n_samples)`, which propagates the same sampling internally and gives quantity-level CIs directly.

**If you hand-roll it with `MASS::mvrnorm`**, back-transform *each parameter with its own* `fit$dlist$inv.transforms` entry — never a blanket `exp()`:

```r
library(MASS)
mu    <- fit_gompertz$res.t[, "est"]      # transformed-scale estimates
Sigma <- vcov(fit_gompertz)               # covariance on the same scale
draws <- mvrnorm(n_samples, mu = mu, Sigma = Sigma)

# Apply fit$dlist$inv.transforms[[j]] to column j -- NOT exp() to every column.
# flexsurv's Gompertz shape is estimated on the IDENTITY scale (it must be able
# to go negative -- that is a plateauing/defective fit, not an error) and only
# rate is log-transformed. A blanket exp() silently forces shape positive and
# converts a plateauing fit into a steeply increasing one: a verified worked
# example with a genuinely negative shape gives a 40-year RMST of 32.0 years
# under the correct per-parameter transform vs. 3.55 years under blanket
# exp() on both parameters, from the same draws.
```

`res.t`'s **rows** (parameters are rows, statistics are columns) also include any **covariate coefficients** after the baseline distribution parameters, and those are never transformed — `fit$dlist$inv.transforms` only has as many entries as baseline parameters, so on any model with covariates a positional loop over every column of `draws` runs off the end of `inv.transforms` (or, if it wraps, exponentiates a regression coefficient).

Two things that matter regardless of which route you use:
- **Sample jointly, not parameter-by-parameter.** The parameters of one survival fit are correlated (e.g. shape and rate), and `vcov()` carries that — independent draws would distort the implied survival curves.
- **Carry the correlation downstream.** If these draws generate a *set* of transition probabilities that then enter a PSA alongside other parameters, the induced correlation among those transition probabilities should be preserved, not broken by resampling them independently. This is the same point the `decision-modelling-hta` PSA section makes about correlated parameters from a common fit.

For full posterior uncertainty rather than the asymptotic-normal approximation, fit the survival model Bayesianly (`survHE` with `method = "hmc"` or `"inla"`, via the companion `survHEhmc`/`survHEinla` packages) and carry the posterior draws straight through — preferable when the extrapolation uncertainty is central to the decision.
