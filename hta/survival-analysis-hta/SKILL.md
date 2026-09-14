---
name: survival-analysis-hta
description: "Fit, choose between, extrapolate, and report parametric survival (time-to-event) models for health economic evaluation in R, using flexsurv, flexsurvcure, survHE and survextrap, by maximum likelihood or Bayesian estimation. Use whenever survival analysis informs an economic evaluation or HTA submission: fitting parametric distributions to trial data, choosing a distribution for extrapolation, estimating mean or restricted mean survival, a treatment effect as a hazard ratio or AFT, spline/cure/relative-survival models, Bayesian fitting with priors and posterior survival bands, anchoring extrapolation with external data, reconstructing IPD from a published Kaplan-Meier curve, or turning a fit into transition probabilities. Trigger on \"survival analysis\", \"time-to-event\", \"parametric survival\", \"extrapolate survival\", \"flexsurv\", \"survextrap\", \"cure model\", \"digitise a KM curve\", or \"survival extrapolation for NICE\". For network meta-analysis of survival across trials, hands off to network-meta-analysis-hta."
---

# Survival analysis for HTA

Parametric time-to-event modelling for economic evaluation, in R, following R-HTA chapter 7. The defining feature of survival analysis *for HTA* (as opposed to for a clinical paper) is that **the deliverable is usually mean survival over a lifetime horizon, which requires extrapolating beyond the trial follow-up** — so model choice is governed at least as much by the plausibility of the extrapolated hazard as by fit to the observed data. Keep that framing central; it's what separates this from generic survival analysis.

> Sources: *R for Health Technology Assessment* (Baio et al., online at <https://gianluca.statistica.it/books/online/r-hta/>) — chapter mapping verified against the live ToC (Ch. 7 = survival analysis), accessed 2026-07-03; the chapter's colon-cancer worked example, `flexsurvreg`/`flexsurvspline` workflow, `hr_flexsurvreg`, and the AIC-fit-vs-extrapolation-plausibility framing all confirmed. Package signatures and version-sensitive behaviour (`flexsurv` 2.3.2, `flexsurvcure` 1.1.0, `survHE` 2.0.51 incl. `digitise()`, `make.ipd()`, `fit.models()`, `make.transition.probs()`, `three_state_mm()`, `markov_trace()`) re-verified against source/CRAN documentation and empirical testing, accessed 2026-08-27. The
> Bayesian material (`references/bayesian-survival.md`) is from *Bayesian Modelling in Health
> Technology Assessment* — Baio (CRC Press, 2026) Ch. 8, anchored to the companion code at
> <https://github.com/giabaio/bmhta-examples> commit `d2a6298`, accessed 2026-09-09; `survHE`
> Bayesian and `survextrap` signatures there are as observed in that working code, not re-verified
> against CRAN.

## Packages and what each is for

- **`flexsurv`** — the workhorse. `flexsurvreg()` fits standard parametric distributions (exponential, Weibull, gamma, Gompertz, log-normal, log-logistic, generalised gamma) by maximum likelihood; `flexsurvspline()` fits Royston-Parmar spline models. Current version ~2.3.x. Covers covariates on any parameter, relative-survival (`bhazard`), time-varying hazard ratios (`hr_flexsurvreg()`), and marginal/standardised survival (`standsurv()`).
- **`flexsurvcure`** — mixture and non-mixture cure models, for when a fraction of patients are plausibly "cured" and will never have the event. Wraps `flexsurvreg` internally.
- **`survHE`** — Baio's HTA-oriented layer over flexsurv. `fit.models()` batch-fits several distributions at once; `digitise()` + `make.ipd()` reconstruct pseudo-IPD from a digitised KM curve (Guyot algorithm); `make.transition.probs()` computes per-cycle transition probabilities from a `fit.models` object. Running an actual cohort trace is a separate, narrower pair: `three_state_mm()` simulates a fixed three-state illness-death trace (it needs three separate fits, one per transition) and `markov_trace()` only *plots* that trace (it returns a `ggplot`). Bayesian back-ends (`method = "hmc"`/`"inla"`) now live in companion packages `survHEhmc`/`survHEinla`, installed separately from the maintainer's r-universe. Current release: survHE 2.0.51 (Jan 2026).
- **`survextrap`** — Bayesian M-spline hazard models that let **external aggregate evidence** (registry data, a life table, elicited long-term survival) enter the likelihood and anchor the extrapolation, rather than leaving the tail entirely to a two-parameter family's functional form. The main Bayesian addition for the part of the curve that decides the ICER; see `references/bayesian-survival.md`.
- **`survival`** — base KM (`survfit`), Cox (`coxph`) for checking the PH assumption. Cox and KM are *not* used for extrapolation (neither is parametric), so they're diagnostic here, not the main event.

## The workflow

1. **Explore before fitting.** Plot the KM curve (`survfit` + `survminer::ggsurvplot`) and, crucially, the *empirical hazard* (`muhaz`, or `flexsurv`'s hazard plots). The shape of the hazard over time — monotonic? peaked? turning down at the end? — is what tells you which distributions are even worth fitting. Fitting every available distribution without looking at the hazard first is the most common bad habit in this area. Every method in this file identifies the survival distribution only under **non-informative (independent) censoring** — flag informative censoring as a threat, e.g. censoring at disease progression when the endpoint is overall survival.
2. **Fit candidate parametric models** with `flexsurvreg()`. See `references/flexsurv-fitting.md` for the distribution menu, the AFT-vs-PH distinction, and how to put a treatment effect (or other covariate) on the location parameter vs. ancillary parameters via `anc`.
3. **Choose a distribution** on *both* statistical fit (AIC/BIC) *and* extrapolation plausibility. This is the heart of the chapter — see the dedicated section below.
4. **Extract the economic quantity**: mean or restricted mean survival (`summary(fit, type = "rmst")`), survival probabilities, or transition probabilities for a decision model.
5. **Propagate uncertainty** into the economic model — bootstrap or the model's own parameter covariance, not just the point estimate.

## Model choice and extrapolation — the part that matters most

AIC/BIC measure fit to the *observed* short-term data only. They say nothing about whether the extrapolation is sensible, and the longer the extrapolation relative to follow-up, the less AIC should weigh in the decision. Two models can fit the trial data almost identically (similar AIC) yet imply mean survival estimates that differ by years, because they extrapolate the hazard differently — the book's colon-cancer example shows AFT vs. GG2 differing by nearly a year in 15-year RMST. Always:

- **Inspect the extrapolated hazard, not just the survival curve.** A distribution can look fine on the S(t) plot over the trial window and still imply a clinically absurd hazard at age 90 (e.g. a hazard that's implausibly low, or rising without bound). Plot fitted hazards out to the full horizon and sense-check against what's known about the disease and background mortality.
- **Bring in external information** where the extrapolation is doing heavy lifting: background/population mortality (relative-survival or cure framing), registry data, or expert judgement. Packages: `flexsurv` relative survival via `bhazard`; `survextrap` and `blendR` for explicit external-data approaches. NICE DSU TSD 21 calls incorporating background mortality recommended generally and **essential for cure models**, so treat its absence in a long-horizon extrapolation as a finding. `references/advanced-survival-models.md` has the `bhazard` mechanics and the three rules that go with them: predictions from a `bhazard` fit come back on the *relative/excess* scale and overstate survival if fed to an economic model as S(t) (use `standsurv()` for all-cause); AIC is not comparable between an excess-hazard fit and an all-cause fit of the same data; and exactly **one** background-mortality mechanism — a post-hoc hazard floor, an additive excess hazard, or an SMR adjustment — may be applied in a given model, never two stacked.
- **Report the model-choice uncertainty**, not just parameter uncertainty within the chosen model — different plausible distributions are a structural uncertainty that often dominates.
- **Run treatment-effect-duration scenarios.** NICE work expects scenarios around how long a treatment effect lasts — including a "no further benefit beyond treatment" scenario (equal hazards after a cutoff; the survival advantage already accrued is retained, so the curves stay separated, not converging) and gradual hazard-ratio waning. `nice-economic-evaluation`'s `survival_extrapolation.R` implements both — feed it the survival curves extracted from your fitted models (on the yearly grid it expects) rather than duplicating the logic here. Where follow-up allows, also validate the extrapolation itself: refit to an earlier data cut and compare the extrapolated curve against the later observed data.

For NICE submissions specifically, the systematic model-selection process (fit all standard parametrics, compare AIC/BIC, assess hazard plausibility, justify the choice) follows NICE DSU TSD 14 and 21. Defer to the **`nice-economic-evaluation`** skill for what the submission has to demonstrate; this skill is about doing the fitting correctly.

## Advanced models — when standard distributions aren't enough

- **Spline models** (`flexsurvspline`, Royston-Parmar): when there's enough short-term data to identify a flexible shape and the conclusions hinge on how the short-term hazard is modelled. More knots = more flexibility; choose on AIC but remember flexibility helps fit, not extrapolation. Three scales: hazard (→ Weibull at 0 knots, gives a PH model), odds (→ log-logistic), normal (→ log-normal).
- **Cure models** (`flexsurvcure`): when a fraction θ of patients plausibly never have the event (disease recurrence, cause-specific death). Mixture: `S(t) = θ + (1-θ)·S₀(t)` (S(0)=1, plateaus at θ as t→∞); non-mixture via `mixture = FALSE`. Identifiability is the catch — you need enough long-term follow-up showing the curve plateauing to estimate θ, and θ can be sensitive to the choice of uncured distribution. Don't fit a cure model just because the curve looks flat at the end of a short trial.
- **Relative survival** (`flexsurv` `bhazard`): partitions all-cause hazard into background (from life tables) + excess (disease-specific, modelled parametrically). Valuable for long-term extrapolation because the two components trend differently. Pairs naturally with cure models for the "cured patients revert to population mortality" assumption.

See `references/advanced-survival-models.md` for fitting patterns for each.

## The Bayesian route

Everything above can be done by maximum likelihood (`flexsurv`) or Bayesian estimation
(`survHE` with `method = "hmc"`, or `survextrap`). The framing does not change — model choice is
still governed by extrapolation plausibility, and a Bayesian fit with the best DIC can still
extrapolate absurdly. What changes is worth having in three specific places:

- **Weakly identified flexible distributions.** The Generalised F's ancillary parameters are
  effectively non-identifiable by MLE on realistic trial data; mildly regularising priors make the
  fit usable. Flexibility and identifiability trade off, and priors are how you buy both.
- **Uncertainty propagation without a normal approximation.** The posterior carries the joint
  parameter uncertainty directly, instead of a multivariate-normal approximation on the transformed
  scale — which matters most where the likelihood is skewed, i.e. small samples and heavy censoring.
  `plot(fit, nsim = 1000, t = ...)` gives a credible band on the extrapolated curve.
- **External evidence as evidence.** `survextrap` lets long-term aggregate data contribute to the
  likelihood, so the extrapolation is fitted to it rather than adjusted toward it afterwards.

See `references/bayesian-survival.md` for the fitting workflow, priors and diagnostics, posterior
survival bands, the `survextrap` M-spline and external-data mechanics, and how DIC and LOO sit
together here. Do not create a parallel Bayesian survival analysis — it is the same workflow with a
different estimator.

## Reconstructing IPD from a published KM curve

Frequently the only data for a comparator is a published KM curve, not patient-level data. The Guyot algorithm reconstructs pseudo-IPD from (a) digitised survival coordinates and (b) the numbers-at-risk table. In `survHE`: digitise the curve (e.g. with `SurvdigitizeR` or by hand into the two input files), then `digitise()` → `make.ipd()` produces a time/event/arm dataset you can fit with `flexsurvreg` as if it were real IPD. Caveat worth stating every time: reconstructed data has **no patient-level covariates**, so no subgroup analysis is possible unless the source reported curves by subgroup. See `references/km-reconstruction.md`.

## Feeding survival into an economic model

The bridge to a **discrete-time cohort** decision model (the `decision-modelling-hta` skill) is the conditional transition probability:

```
tp(t, t+1) = 1 - S(t+1) / S(t)
```

i.e. the probability of the event in cycle t+1 given event-free survival to t. This is exactly what makes a state-transition model time-inhomogeneous. Four routes, depending on the target model:
- **State-transition / Markov** (most common): convert the fitted S(t) to per-cycle transition probabilities via the formula above. `survHE::make.transition.probs()` automates this from a `fit.models` object, returning one transition's probability curve; or compute by hand from any `flexsurvreg` fit's cumulative hazard. Running and plotting a full cohort trace from survHE is a separate, narrower chain limited to a fixed three-state structure (`three_state_mm()` → `markov_trace()`) — for any other state structure, use the manual conversion. The `decision-modelling-hta` skill's `compute_surv()`/manual-conversion guidance is the receiving end.
- **Partitioned survival model (PSM)**: areas under independently-extrapolated PFS and OS curves define state membership directly — no transition probabilities. Common in oncology.
- **Continuous-time or individual-level multistate model**: no per-cycle probabilities at all — the fitted transition models are handed over as objects and the engine integrates them. `multistate-models-hta` is the receiving skill for the structure (and for the competing-risks machinery when the per-cycle split above stops being adequate); `hesim-ctstm-hta` for the engine code. One thing to get right on this side of the hand-off: whether a fit is clock-reset or clock-forward is baked into how `Surv()` was written (`Surv(time, status)` vs `Surv(Tstart, Tstop, status)`), so fit each transition on the clock the receiving model will declare, and say which.
- **Patient-level (trial-based CEA)**: extrapolate survival directly per arm.

Propagate uncertainty by sampling the survival model's parameters (multivariate normal on the transformed-parameter scale from the fit's `vcov`) rather than treating the point estimate as fixed — and if these parameters feed a correlated set of transition probabilities, carry that correlation through (the `decision-modelling-hta` PSA section's correlation point).

See `references/survival-to-economic-model.md` for the worked conversion snippets (manual cumulative-hazard route per distribution, the survHE automated route, the PSM membership formulas with the curve-crossing caveat, and the joint-parameter-sampling code for uncertainty).

## Common pitfalls

- **Choosing on AIC alone.** The single most common error; AIC ignores extrapolation plausibility entirely. Always plot the extrapolated hazard.
- **Confusing parameterisations across packages.** `flexsurv`'s Weibull matches `dweibull` (shape/scale), which differs from `survreg`'s. The book and `flexsurv`'s "Distributions reference" vignette are the authority; don't assume a "scale" means the same thing across functions. `flexsurv`'s `shape` = 1/`survreg`'s `scale` (σ), and `flexsurv`'s `scale` = `exp()` of `survreg`'s intercept.
- **Reporting median when the decision needs the mean.** Medians need no extrapolation but don't answer the resource-allocation question; mean survival (area under the whole curve) is the HTA-relevant quantity and *requires* extrapolation.
- **Cure model without identifiability.** A flat tail on a short trial is not evidence of cure; you need long follow-up with people genuinely observed past the cure time.
- **Extracting a hazard ratio from a flexsurv AFT fit by reading off a coefficient.** AFT coefficients are time-acceleration factors, not log-HRs. A *constant* HR exists only for the Weibull and exponential, and the conversion depends on which parameter carries the covariate (`fit$dlist$location`): for `dist = "weibull"` (covariate on log scale, a log-time effect), log HR = −shape × the coefficient; for `dist = "exp"` the covariate sits on log *rate*, so the coefficient already **is** the log HR — negating it reverses the effect. For log-normal, log-logistic, and generalised gamma the model-implied HR is inherently time-varying — there's no constant HR to convert to. Use `hr_flexsurvreg()` and present HR(t) over time instead of quoting a single number.

## Validating a fitted model before using it downstream

`scripts/check_survival_fit.R` takes a `flexsurvreg` (or `flexsurvspline`) object and reports: optimiser convergence; whether all parameter estimates and SEs are finite; covariance-matrix validity (positive-definiteness, and any extreme parameter correlations); extrapolated survival/hazard validity over the horizon (finite, hazard ≥ 0, survival in [0,1] and non-increasing); a defective-distribution/plateau report (e.g. a Gompertz with negative shape, or a spline tail that never reaches zero); restricted mean survival at the horizon with a confidence interval; and, optionally, a comparison of the horizon hazard against a supplied background hazard. Run it before trusting any fit you're about to extrapolate or feed into an economic model — a non-converged or unidentifiable fit can still print without obvious error.
