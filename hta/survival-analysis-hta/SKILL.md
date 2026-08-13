---
name: survival-analysis-hta
description: "Fit, choose between, extrapolate, and report parametric survival (time-to-event) models for health economic evaluation in R, using flexsurv, flexsurvcure, and survHE. Use whenever survival analysis informs an economic evaluation or HTA submission: fitting parametric distributions to trial data, choosing a distribution for extrapolation, estimating mean or restricted mean survival, modelling a treatment effect as a hazard ratio or AFT, fitting spline/cure/relative-survival models, reconstructing IPD from a published Kaplan-Meier curve, or turning a fit into transition probabilities. Trigger on phrases like \"survival analysis\", \"time-to-event\", \"parametric survival\", \"extrapolate survival\", \"flexsurv\", \"proportional hazards vs AFT\", \"cure model\", \"spline survival model\", \"restricted mean survival\", \"digitise a KM curve\", or \"survival extrapolation for NICE\". For network meta-analysis of survival across trials, this skill covers single-study/IPD modelling and hands off to network-meta-analysis-hta."
---

# Survival analysis for HTA

Parametric time-to-event modelling for economic evaluation, in R, following R-HTA chapter 7. The defining feature of survival analysis *for HTA* (as opposed to for a clinical paper) is that **the deliverable is usually mean survival over a lifetime horizon, which requires extrapolating beyond the trial follow-up** — so model choice is governed at least as much by the plausibility of the extrapolated hazard as by fit to the observed data. Keep that framing central; it's what separates this from generic survival analysis.

> Sources: *R for Health Technology Assessment* (Baio et al., online at <https://gianluca.statistica.it/books/online/r-hta/>) — chapter mapping verified against the live ToC (Ch. 7 = survival analysis), accessed 2026-07-03; the chapter's colon-cancer worked example, `flexsurvreg`/`flexsurvspline` workflow, `hr_flexsurvreg`, and the AIC-fit-vs-extrapolation-plausibility framing all confirmed. Package signatures (`flexsurv`, `flexsurvcure`, `survHE` incl. `digitise()`, `make.ipd()`, `fit.models()`, `make.transition.probs()`, `markov_trace()`) cross-checked against the CRAN/pkgdown documentation, accessed 2026-07-03.

## Packages and what each is for

- **`flexsurv`** — the workhorse. `flexsurvreg()` fits standard parametric distributions (exponential, Weibull, gamma, Gompertz, log-normal, log-logistic, generalised gamma) by maximum likelihood; `flexsurvspline()` fits Royston-Parmar spline models. Current version ~2.3.x. Covers covariates on any parameter, relative-survival (`bhazard`), time-varying hazard ratios (`hr_flexsurvreg()`), and marginal/standardised survival (`standsurv()`).
- **`flexsurvcure`** — mixture and non-mixture cure models, for when a fraction of patients are plausibly "cured" and will never have the event. Wraps `flexsurvreg` internally.
- **`survHE`** — Baio's HTA-oriented layer over flexsurv (and optionally Bayesian back-ends via `rstan`/`INLA`). `fit.models()` batch-fits several distributions at once; `digitise()` + `make.ipd()` reconstruct pseudo-IPD from a digitised KM curve (Guyot algorithm); `make.transition.probs()` and `markov_trace()` turn fitted survival into decision-model inputs. CRAN-maintained by Baio, current as of 2025.
- **`survival`** — base KM (`survfit`), Cox (`coxph`) for checking the PH assumption. Cox and KM are *not* used for extrapolation (neither is parametric), so they're diagnostic here, not the main event.

## The workflow

1. **Explore before fitting.** Plot the KM curve (`survfit` + `survminer::ggsurvplot`) and, crucially, the *empirical hazard* (`muhaz`, or `flexsurv`'s hazard plots). The shape of the hazard over time — monotonic? peaked? turning down at the end? — is what tells you which distributions are even worth fitting. Fitting every available distribution without looking at the hazard first is the most common bad habit in this area.
2. **Fit candidate parametric models** with `flexsurvreg()`. See `references/flexsurv-fitting.md` for the distribution menu, the AFT-vs-PH distinction, and how to put a treatment effect (or other covariate) on the location parameter vs. ancillary parameters via `anc`.
3. **Choose a distribution** on *both* statistical fit (AIC/BIC) *and* extrapolation plausibility. This is the heart of the chapter — see the dedicated section below.
4. **Extract the economic quantity**: mean or restricted mean survival (`summary(fit, type = "rmst")`), survival probabilities, or transition probabilities for a decision model.
5. **Propagate uncertainty** into the economic model — bootstrap or the model's own parameter covariance, not just the point estimate.

## Model choice and extrapolation — the part that matters most

AIC/BIC measure fit to the *observed* short-term data only. They say nothing about whether the extrapolation is sensible, and the longer the extrapolation relative to follow-up, the less AIC should weigh in the decision. Two models can fit the trial data almost identically (similar AIC) yet imply mean survival estimates that differ by years, because they extrapolate the hazard differently — the book's colon-cancer example shows AFT vs. GG2 differing by nearly a year in 15-year RMST. Always:

- **Inspect the extrapolated hazard, not just the survival curve.** A distribution can look fine on the S(t) plot over the trial window and still imply a clinically absurd hazard at age 90 (e.g. a hazard that's implausibly low, or rising without bound). Plot fitted hazards out to the full horizon and sense-check against what's known about the disease and background mortality.
- **Bring in external information** where the extrapolation is doing heavy lifting: background/population mortality (relative-survival or cure framing), registry data, or expert judgement. Packages: `flexsurv` relative survival via `bhazard`; `survextrap` and `blendR` for explicit external-data approaches.
- **Report the model-choice uncertainty**, not just parameter uncertainty within the chosen model — different plausible distributions are a structural uncertainty that often dominates.

For NICE submissions specifically, the systematic model-selection process (fit all standard parametrics, compare AIC/BIC, assess hazard plausibility, justify the choice) follows NICE DSU TSD 14 and 21. Defer to the **`nice-economic-evaluation`** skill for what the submission has to demonstrate; this skill is about doing the fitting correctly.

## Advanced models — when standard distributions aren't enough

- **Spline models** (`flexsurvspline`, Royston-Parmar): when there's enough short-term data to identify a flexible shape and the conclusions hinge on how the short-term hazard is modelled. More knots = more flexibility; choose on AIC but remember flexibility helps fit, not extrapolation. Three scales: hazard (→ Weibull at 0 knots, gives a PH model), odds (→ log-logistic), normal (→ log-normal).
- **Cure models** (`flexsurvcure`): when a fraction θ of patients plausibly never have the event (disease recurrence, cause-specific death). Mixture: `S(t) = 1 - (1-θ)·S₀(t)`; non-mixture via `mixture = FALSE`. Identifiability is the catch — you need enough long-term follow-up showing the curve plateauing to estimate θ, and θ can be sensitive to the choice of uncured distribution. Don't fit a cure model just because the curve looks flat at the end of a short trial.
- **Relative survival** (`flexsurv` `bhazard`): partitions all-cause hazard into background (from life tables) + excess (disease-specific, modelled parametrically). Valuable for long-term extrapolation because the two components trend differently. Pairs naturally with cure models for the "cured patients revert to population mortality" assumption.

See `references/advanced-survival-models.md` for fitting patterns for each.

## Reconstructing IPD from a published KM curve

Frequently the only data for a comparator is a published KM curve, not patient-level data. The Guyot algorithm reconstructs pseudo-IPD from (a) digitised survival coordinates and (b) the numbers-at-risk table. In `survHE`: digitise the curve (e.g. with `SurvdigitizeR` or by hand into the two input files), then `digitise()` → `make.ipd()` produces a time/event/arm dataset you can fit with `flexsurvreg` as if it were real IPD. Caveat worth stating every time: reconstructed data has **no patient-level covariates**, so no subgroup analysis is possible unless the source reported curves by subgroup. See `references/km-reconstruction.md`.

## Feeding survival into an economic model

The bridge to a decision model (the `decision-modelling-hta` skill) is the conditional transition probability:

```
tp(t, t+1) = 1 - S(t+1) / S(t)
```

i.e. the probability of the event in cycle t+1 given event-free survival to t. This is exactly what makes a state-transition model time-inhomogeneous. Three routes, depending on the target model:
- **State-transition / Markov** (most common): convert the fitted S(t) to per-cycle transition probabilities via the formula above. `survHE::make.transition.probs()` automates this from a `fit.models` object; or compute by hand from any `flexsurvreg` fit's cumulative hazard. The `decision-modelling-hta` skill's `compute_surv()`/manual-conversion guidance is the receiving end.
- **Partitioned survival model (PSM)**: areas under independently-extrapolated PFS and OS curves define state membership directly — no transition probabilities. Common in oncology.
- **Patient-level (trial-based CEA)**: extrapolate survival directly per arm.

Propagate uncertainty by sampling the survival model's parameters (multivariate normal on the transformed-parameter scale from the fit's `vcov`) rather than treating the point estimate as fixed — and if these parameters feed a correlated set of transition probabilities, carry that correlation through (the `decision-modelling-hta` PSA section's correlation point).

See `references/survival-to-economic-model.md` for the worked conversion snippets (manual cumulative-hazard route per distribution, the survHE automated route, the PSM membership formulas with the curve-crossing caveat, and the joint-parameter-sampling code for uncertainty).

## Common pitfalls

- **Choosing on AIC alone.** The single most common error; AIC ignores extrapolation plausibility entirely. Always plot the extrapolated hazard.
- **Confusing parameterisations across packages.** `flexsurv`'s Weibull matches `dweibull` (shape/scale), which differs from `survreg`'s. The book and `flexsurv`'s "Distributions reference" vignette are the authority; don't assume a "scale" means the same thing across functions. `flexsurv`'s `scale` is `1/shape` of `survreg`, and `survreg`'s intercept is `log(scale)`.
- **Reporting median when the decision needs the mean.** Medians need no extrapolation but don't answer the resource-allocation question; mean survival (area under the whole curve) is the HTA-relevant quantity and *requires* extrapolation.
- **Cure model without identifiability.** A flat tail on a short trial is not evidence of cure; you need long follow-up with people genuinely observed past the cure time.
- **Extracting a hazard ratio from a flexsurv AFT fit by reading off a coefficient.** AFT coefficients are time-acceleration factors, not log-HRs; for a time-varying HR use `hr_flexsurvreg()`, and for a constant HR from an AFT model the conversion is distribution-specific (delta method on the parameters).

## Validating a fitted model before using it downstream

`scripts/check_survival_fit.R` takes a `flexsurvreg` (or `flexsurvspline`) object and reports: convergence status, parameter estimates with SEs flagged if implausibly large (poor identifiability), AIC/BIC, restricted mean survival at a stated horizon, and a check that the extrapolated hazard stays finite and non-negative out to the horizon. Run it before trusting any fit you're about to extrapolate or feed into an economic model — a non-converged or unidentifiable fit can still print without obvious error.
