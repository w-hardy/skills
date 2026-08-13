# Competing events and uncertainty in DES

Two design decisions that are easy to get wrong and dictate how the input data must be analysed: how to simulate competing events, and how to handle the four distinct kinds of variation. Both should be settled *before* fitting time-to-event models, not after.

> Sources: R-HTA Ch. 12 (competing-events handling and the layers of variation in DES). Accessed 2026-07-03.

## Competing-events strategies

Competing events prevent or alter each other (recurrence vs death; cancer death vs other-cause death). DES gives more flexibility than a state-transition model here, but the chosen strategy must match how the data were analysed. Four strategies (Barton et al. 2004; Karnon et al. 2012):

### 1. Latent times — sample a time per event, earliest wins
Draw a time-to-event for *each* competing event independently; the minimum determines both *when* and *which*.
- Robust under **censoring** (each event's distribution fitted with the others as competing-risk censoring, exactly as in the multistate per-transition setup).
- Implementation: store each event's time as an attribute, `which.min()` picks the event. (The book's colon case study uses this.)

### 2. Event first, then time
Use event-specific probabilities to pick which event occurs, then sample from that event's time-to-event distribution.
- Good performance on **uncensored** data and the most straightforward to implement there.
- **Awkward under censoring** — recovering unbiased event probabilities and conditional time distributions from censored data isn't straightforward.

### 3. Time first, then event  (the general recommendation)
Sample from a **combined** all-events time-to-event distribution, then choose the event conditional on that time (e.g. multinomial logistic regression on time).
- Recommended in general, and efficient when a multivariable survival model is used (only one time model to parametrise on covariates).
- **Critical caveat**: if events occur on different timescales, the combined time distribution is **multimodal**, and a naive single parametric distribution will misfit it. Use a **mixture distribution or a survival spline** for the combined time. Getting this wrong is the main failure mode of strategy 3.

### 4. Discretised cyclic probabilities
Mimic a discrete-time Markov model with per-cycle probabilities.
- Available, but **forfeits DES's continuous-time advantage** — only sensible if matching an existing discrete-time model.

### Choosing
The decision is driven by **censoring and data characteristics**, and it determines how the data must be analysed (combined vs event-specific distributions; multimodality handling). Censored data → strategy 1 or 3 generally preferred; uncensored → 2 is simple and performs well. Decide first, then fit the survival models to match — fitting first and choosing the strategy afterwards risks a mismatch between the fitted distributions and what the simulation needs.

## The four kinds of variation (Briggs et al. 2012)

Conflating these is the most common conceptual error in individual-level modelling. Keep them distinct:

| Type | What it is | How to handle | Loop |
|---|---|---|---|
| **Heterogeneity** | Variation *explained by* characteristics (age, stage, biomarker) | Vary attributes / distribution parameters across individuals | within a run |
| **Stochastic** (1st-order) | Random variation between *identical* individuals | Simulate enough individuals for the mean to converge | within a run |
| **Parameter** (2nd-order) | Uncertainty in the estimated parameter values | Probabilistic analysis: resample parameters from their distributions | outer PSA loop |
| **Structural** | Uncertainty from modelling assumptions/structure | Scenario analysis (no gold standard) | scenarios |

### The trap: stochastic vs parameter uncertainty
They both produce between-individual variation, so they're easy to mix up — but they need different fixes:
- **More individuals** reduces *stochastic* noise (makes the within-run mean stable). It does **nothing** for parameter uncertainty.
- **Parameter uncertainty** needs an outer loop that resamples the parameters each iteration (PSA). Within each PSA iteration you *still* need enough individuals for the stochastic mean to converge.

So a correct probabilistic DES is **two nested loops**: outer over PSA parameter draws, inner over simulated individuals. Reporting "we ran 50,000 individuals so uncertainty is handled" conflates the two — that addresses stochastic noise only.

### Parameter uncertainty with correlated distribution parameters
When a distribution's parameters are estimated jointly (e.g. Gompertz shape and rate for background mortality), they're **correlated**, and resampling them independently distorts the implied survival. Sample jointly:
- **Frequentist**: multivariate normal on the (transformed) parameter scale using the fit's covariance, or **non-parametric bootstrap** — the latter also preserves correlation *across* different distributions estimated from one dataset.
- **Bayesian**: draw parameter sets from the posterior.

This is the same joint-sampling point made in the `survival-analysis-hta` and `multistate-models-hta` skills — DES consumes those fitted distributions, so the same discipline applies when propagating their uncertainty into the simulation.

## Practical convergence check

Because two loops interact, check convergence of *both*: that mean costs/QALYs are stable as the number of individuals grows (stochastic), and that the PSA output (e.g. mean incremental net benefit, CEAC) is stable as the number of PSA iterations grows (parameter). A model that looks converged on one axis can still be noisy on the other.
