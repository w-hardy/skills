# Missing costs and QALYs in a trial-based CEA

> Source: BMHTA §10.1-10.4, Examples 10.1-10.2, verified against the online edition 2026-09-09. The
> chapter sets out the MCAR/MAR/MNAR mechanisms as Model-of-Analysis / Model-of-Missingness pairs,
> demonstrates complete-case bias by simulation (Ex 10.1), and analyses the MenSS trial with three
> joint models assuming **MAR for the effects and MNAR for the costs** (Ex 10.2). Being Part III of
> the book, it gives the framing and one worked example and delegates the full missing-data workflow
> to Gabrio et al. (2025) in *R for HTA*.
>
> **Read `missing-data-mice` first** for the general theory and the `mice` workflow. This file
> covers only what is specific to economic outcomes and to the Bayesian joint model.

## Why economic outcomes are a hard case

Missingness in a within-trial CEA has features that make the generic advice insufficient:

- **It is rarely confined to one variable.** A patient lost to follow-up is usually missing *both*
  the later utility measurements and the later resource use. The missingness is correlated across
  the two outcomes that the whole analysis needs jointly.
- **A QALY is a derived quantity.** One missing utility visit does not make the QALY missing — it
  makes the area under the curve unidentified over one interval. Deleting the patient throws away
  the intervals you do have; naively interpolating across the gap asserts something you have not
  observed. Decide explicitly whether you are imputing *utilities* (then computing QALYs) or
  imputing *QALYs* (a coarser, usually weaker option). Imputing at the utility level is the more
  defensible default because it uses the observed visits.
- **Complete-case analysis is the silent default.** `lm()`, `brm()` and friends drop incomplete rows
  with at most a message. In a trial with 20–40% dropout that is a large, undeclared analysis choice.
  Under MCAR it is merely inefficient; under MAR it is biased. Check `nobs(fit)` against your sample
  size on every model you fit, every time.

## The Bayesian joint model handles MAR natively

This is the argument that matters for this skill, and it is why "just use `mice`" is not the whole
answer.

In a fully Bayesian model, an unobserved outcome is simply **a parameter with no likelihood
contribution**. Its posterior is determined by the model structure and the observed data, and it is
sampled alongside everything else in the same MCMC run. There is no separate imputation step, no
pooling rule, and — critically — **no need to make the imputation model and the analysis model
agree**, because they are the same model. Under MAR, conditioning on the observed covariates and the
observed component of the joint outcome is exactly what the model already does.

Multiple imputation approximates this by drawing from a predictive distribution. The source frames
Rubin's design as "think like a Bayesian and do as a frequentist" (§10.3.1) — a deliberate
compromise made when MCMC was out of reach, and one it says there is no longer any need to keep. As
a two-stage procedure MI introduces an **uncongeniality** risk (Meng, 1994) — the imputation model
can imply a different joint distribution from the analysis model, and the pooled result then answers
a slightly different question. In a joint cost-effect model with a hurdle component and arm-specific
dispersion, building a congenial imputation model in `mice` is real work. The one-stage route avoids
it.

In brms this is the `mi()` mechanism:

```r
f_e <- bf(qaly   | mi() ~ arm + u0_c)
f_c <- bf(cost_k | mi() ~ arm + mi(qaly))
fit <- brm(f_e + f_c + set_rescor(FALSE), data = trial, prior = priors, seed = 1234)
```

Note `mi(qaly)` on the right-hand side of the cost equation: it tells brms to use the *modelled*
(partly imputed) effect, not the observed column, so the conditional cost model is defined for
patients whose effect is missing. A raw `qaly` there — or a centred column derived from it, which
inherits the same NAs — is a missing *predictor*, and brms drops those rows with a warning even
though the response carries `mi()` (`joint-cost-effect-models.md`). See `brms-modelling`'s
`references/special-terms.md` for the mechanics and for the `mi()` vs `brm_multiple()` choice.

## When to use multiple imputation instead

The joint model is not always the better tool. Reach for `mice` when:

- **Covariates are missing, not just outcomes**, and there are many of them with an arbitrary
  missingness pattern. `mi()` needs a model per incomplete variable, which becomes unwieldy;
  `mice`'s chained equations are built for this.
- **Utilities are missing at the visit level** and you want to impute them *before* computing the
  QALY. This is a longitudinal imputation problem in its own right (`missing-data-mice` covers `2l.`
  methods and longitudinal patterns), and it sits upstream of everything in this skill.
- **The analysis must match a pre-specified statistical analysis plan** that commits to MI — a real
  constraint in regulatory and HTA submissions.

Whichever route, one rule is specific to this setting and easy to break: **cost must appear in the
effect's imputation model and effect in the cost's.** Imputing them separately, each from covariates
only, produces imputed pairs that are conditionally independent given the covariates — which
destroys exactly the cost-effect correlation the joint model exists to estimate, and does so
invisibly. In `mice` that means not excluding either outcome from the other's predictor matrix; in
the joint Bayesian model it is automatic, which is another reason to prefer it here.

The two routes can be combined: impute visit-level utilities with `mice`, compute QALYs within each
imputed dataset, then fit the joint Bayesian model to each. If you do this, the pairing rule
(`population-average-summaries.md`) extends: draws must be paired **within** an imputation before
being stacked across imputations, and the stacked matrix carries both sources of uncertainty. Never
average the imputed datasets into one and fit once — that discards the imputation uncertainty
entirely.

## MNAR and sensitivity analysis

Everything above assumes MAR. In economic evaluations MNAR is a live concern with a specific shape:
patients who do badly are more likely to drop out, so both their costs (higher) and their utilities
(lower) are missing *because of* their values. The bias then runs in a predictable direction and is
not removed by any MAR-based method, Bayesian or otherwise.

MAR is not testable from the observed data. What is available is a sensitivity analysis: refit under
a departure from MAR and report how far the conclusion moves. In a Bayesian joint model the natural
form is a **pattern-mixture** shift — add a sensitivity parameter `delta` to the mean of the missing
component and re-run over a grid:

```
E[Y_missing] = E[Y_observed-model] + delta
```

with `delta` spanning a range agreed as clinically plausible (and, for a two-outcome problem,
plausibly of opposite sign for costs and effects — the pessimistic corner).

The source takes the other of the two standard routes (§10.2 sets out both: pattern-mixture, Little
1993, and selection, Diggle and Kenward 1994). It fits a **selection model** — a Bernoulli
missingness indicator with `logit(pi_i) = delta0 + delta1*x_i + delta2*y_i`, where the MNAR term
`delta2` is unidentified by the data and so **must** carry an informative prior; the worked choice
is `Normal(0.28, sd ≈ 0.15)` on the logit scale, an odds ratio for missingness of about 1.34. For a
CEA the same decomposition applies to each outcome separately: an intercept alone is MCAR, adding
observed covariates makes it MAR, adding the partially-observed outcome itself makes it MNAR. Either
route is defensible; a delta grid is usually easier to present to a committee, an explicit selection
model easier to justify when you have a substantive belief about *why* people dropped out. Report
the incremental result and the CEAC across the grid, and state the `delta` at which the decision
would change: a **tipping-point** analysis is far more useful to a decision-maker than a single MNAR
scenario. `missing-data-mice` covers the general MNAR machinery; what is specific here is that the
sensitivity must be applied to costs and effects **jointly and coherently**, not one at a time.

## Reporting

State, for every trial-based CEA:

- the proportion missing for costs and for effects, **by arm**;
- the mechanism assumed, and why it is plausible given what is known about why people dropped out;
- the method (joint Bayesian model with `mi()`, or MI with the imputation model described);
- the number of observations actually used by the final model;
- the MNAR sensitivity analysis and its tipping point.

`cheers-2022-reporting` owns the reporting checklist; this is the economics-specific subset that is
most often omitted.

## The package the book names

Chapter 10 (§10.4.2) points to **`missingHE`** (Gabrio, 2024) as a higher-level interface for
Bayesian missing-data models in health economics — it writes and runs the JAGS code in the
background once you state the missingness assumption and the outcome distributions — it wraps the
joint cost-effect models (including hurdle and selection/pattern-mixture forms) with missingness
handled internally. It was not possible to verify its current API from the authoring environment, so
no function signatures are given here. If a user is already using it, treat it as a packaged route
to the same models described in this skill, and check its documentation against the installed
version.
