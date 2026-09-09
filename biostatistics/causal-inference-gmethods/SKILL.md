---
name: causal-inference-gmethods
description: "Estimate causal treatment effects from clinical data in R - DAG-based confounder selection, propensity scores, inverse probability weighting, g-computation, doubly robust estimation, and sensitivity analysis for unmeasured confounding. Use whenever the question is what would happen if we intervened, not what predicts the outcome, when appraising an observational treatment-effect claim, or when standardising a covariate-adjusted trial model (non-collapsibility). Trigger on \"causal inference\", \"DAG\", \"confounding\", \"collider\", \"propensity score\", \"IPTW\", \"g-computation\", \"g-formula\", \"marginal structural model\", \"doubly robust\", \"AIPW\", \"TMLE\", \"target trial\", \"immortal time bias\", \"ATE\", \"ATT\", \"non-collapsibility\", or \"E-value\" - even when unnamed. Prefer this over memory, because an adjusted model's covariate coefficients are not causal effects (the Table 2 fallacy) and balance must not be assessed with p-values. For pathways use mediation-analysis; for prediction use clinical-prediction-models."
---

# Causal Inference and G-Methods

The governing distinction: a prediction model asks **what will happen**; a causal
analysis asks **what would happen if we intervened**. Different questions,
different variable selection, different reporting. A model that predicts well can
be causally useless, and a model that is causally correct can predict badly.

## Provenance

Verified 13 August 2026.

- Hernán MA, Robins JM. *Causal Inference: What If*. CRC, 2020 (free online) — the reference text
- Hernán MA, Robins JM. *Am J Epidemiol* 2016;183:758-64 — target trial emulation
- **Westreich D, Greenland S. *Am J Epidemiol* 2013;177:292-8 — the Table 2 fallacy**
- Austin PC. *Multivariate Behav Res* 2011;46:399-424 — propensity score methods
- Cole SR, Hernán MA. *Am J Epidemiol* 2008;168:656-64 — marginal structural models, stabilised weights
- VanderWeele TJ. *Eur J Epidemiol* 2019;34:211-19 — principles of confounder selection
- VanderWeele TJ, Ding P. *Ann Intern Med* 2017;167:268-74 — the E-value
- Lipsitch M, Tchetgen Tchetgen E, Cohen T. *Epidemiology* 2010;21:383-8 — negative controls
- ICH E9(R1) estimands addendum, 2019; FDA *Adjusting for Covariates in Randomized Clinical
  Trials*, 2023; EMA guideline on baseline covariates (EMA/CHMP/295050/2013), 2015 — covariate
  adjustment in randomised trials
- Ye T, Shao J, Yi Y, Zhao Q. *J Am Stat Assoc* 2023 — covariate adjustment and marginal effects
  in randomised trials
- Textor J et al. — `dagitty`; Greifer N — `WeightIt`, `cobalt`, `MatchIt`

## Step 1: state the estimand before touching data

Four things, in writing:

- **Target population** and therefore the estimand: **ATE** (average treatment
  effect, whole population), **ATT** (among the treated), or ATO (overlap
  weights). These answer different clinical questions and can differ in sign.
  Matching gives you the ATT by construction and discards unmatched patients —
  which is a change of estimand, not just of sample.
- **Treatment**, defined as a well-specified intervention. "Obesity" is not an
  intervention; "a 12-week weight-loss programme" is.
- **Time zero**, and what is measured before it.
- **Outcome** and time horizon.

## Step 2: the DAG, and the three structures

Draw it before selecting covariates. `dagitty` will then compute the adjustment
sets for you rather than leaving it to intuition.

| Structure | Form | Adjust for the middle variable? |
|---|---|---|
| **Confounder (fork)** | A ← C → Y | **Yes** — this is the whole point |
| **Mediator (chain)** | A → M → Y | **No** for a total effect; adjusting removes part of the effect you want |
| **Collider** | A → C ← Y | **No** — adjusting *creates* bias where none existed |

Collider bias is the one that surprises people, because conditioning is normally
protective. Selection into the study is a collider if both treatment and outcome
influence who is included, which is why "we restricted to hospitalised patients"
can manufacture an association from nothing.

**Confounder selection is not a statistical procedure.** Do not select by
stepwise, by p-value, by "change in estimate" alone, or by throwing in everything
available. Throwing in everything risks adjusting for mediators and colliders.
VanderWeele's principles: adjust for pre-treatment causes of the treatment or of
the outcome, and exclude instruments (causes of treatment only), which amplify
residual bias without reducing confounding.

## Step 3: the assumptions no method can rescue

- **Conditional exchangeability (no unmeasured confounding).** Untestable.
  Everything below is conditional on it, and the honest sentence in any Discussion
  is that it may not hold.
- **Positivity.** Every patient must have a non-zero probability of each
  treatment. Check the propensity score overlap plot *before* estimating
  anything. Where overlap fails, no weighting scheme fixes it — you are
  extrapolating.
- **Consistency / well-defined intervention.** If "treatment" bundles several
  versions with different effects, the estimand is ill-defined.
- **No interference.** One patient's treatment does not affect another's outcome.

## Step 4: estimation

Three routes; in observational data the third is usually best.

**Inverse probability weighting.** Model treatment given covariates, weight each
patient by the inverse of the probability of the treatment they actually
received, and fit an outcome model on the pseudo-population.

- Use **stabilised weights** (Cole & Hernán). They have much lower variance and a
  mean near 1, which is itself a diagnostic — a mean far from 1 signals a
  misspecified treatment model or a positivity problem.
- **Examine the weight distribution.** A handful of enormous weights means a few
  patients dominate. Truncating at the 1st/99th percentile trades a little bias
  for a large variance reduction; report that you did it and the percentile used.
  Better still, ask why the extreme weights exist — they are usually a positivity
  warning, and truncation hides the symptom.
- **Standard errors must account for the weights.** Use robust/sandwich errors or
  the bootstrap. In R, `WeightIt::weightit()` then `glm_weightit()`, not
  `glm(..., weights = )`, whose standard errors treat weights as frequencies and
  come out far too small.

**G-computation (standardisation).** Fit an outcome model including treatment and
covariates; predict every patient's outcome under treatment and under control;
average the difference. Efficient when the outcome model is right, and it gives
the marginal effect directly rather than a conditional one. In R,
`marginaleffects::avg_comparisons()` does the averaging and the delta-method or
bootstrap standard error.

The same standardisation arithmetic does three different jobs, and "g-computation"
names all three. Work out which one is in front of you before answering, because
the assumptions and the owning skill differ:

- **Identification under confounding.** Observational data; standardise over the
  confounders to recover the causal effect. This skill, and every assumption in
  Step 3 applies.
- **Marginalisation within a single randomised trial.** Randomisation already
  supplies exchangeability, so nothing here is about confounding. Standardisation
  is needed because the effect measure is **non-collapsible**: for an odds ratio
  or a hazard ratio (logistic, Cox), the treatment coefficient of a
  covariate-adjusted model is a *conditional* effect, and exponentiating it does
  not give the marginal contrast the decision needs. Fit the adjusted model,
  predict every randomised patient under each arm, average within arm, then
  contrast: the covariates buy precision while the estimand stays marginal and
  the randomisation still does the identifying. ICH E9(R1) makes the
  population-level summary part of the estimand rather than a by-product of the
  model; the FDA's 2023 covariate-adjustment guidance requires the estimand to
  state whether the effect of interest is conditional or unconditional and
  permits covariate-adjusted estimation of the unconditional effect in the
  primary analysis, while the EMA's 2015 guideline uses neither term and asks
  only that an adjusted estimate from a non-linear model be given its correct
  interpretation. **This case belongs here, not in
  `population-adjusted-comparisons`** — nothing is being transported to another
  population.

  A log-link cost model reaches the same recipe by a different route. The mean
  *ratio* is collapsible — absent a treatment-covariate interaction,
  `exp(b_treatment)` is already the marginal ratio — but a CEA needs the mean
  *difference*, and `E[exp(eta)] != exp(E[eta])`, so the arm means must still be
  standardised over the trial's covariate distribution rather than read off the
  coefficients or evaluated at mean covariates. `trial-based-cea-hta` works that
  case through.
- **Transport between studies (G-computation STC).** Standardising an outcome
  model fitted in one randomised trial's individual data over *another* study's
  covariate distribution, to move a marginal effect between populations.
  Randomisation disposes of confounding inside the trial, but identification is
  not therefore free: the cross-study step assumes every effect modifier is
  measured and correctly specified — and, if the comparison is unanchored (no
  common comparator arm), every prognostic factor too. If that is the question,
  use `population-adjusted-comparisons`. (Baio, *Bayesian Models in Health
  Technology Assessment*, CRC Press 2026, §11.3.2 uses "parametric g-computation"
  in exactly that sense, after Remiro Azócar et al. 2022, noting the "g" is
  Robins' 1986 *generalised*.)

**Doubly robust (AIPW, TMLE).** Combines both: consistent if *either* the
treatment model or the outcome model is correct. **In observational data this is
the default to reach for.** `tmle` and `AIPW` in R; TMLE additionally
accommodates machine learning for the nuisance models via cross-fitting without
breaking inference.

Do not *require* it in a randomised trial, and do not raise its absence as a
finding there. The treatment model is known by design, so nothing rests on
getting that half right. What the augmentation still buys is consistency when the
*outcome* model is wrong. Plain g-computation gives that for free only under a
**canonical link** — the intercept's score equation then forces the mean of the
fitted values to equal the observed mean within the fitted sample, so
standardising reproduces the arm mean whatever else the model gets wrong
(Rosenblum & van der Laan 2010). It needs an intercept and a treatment main
effect, or a separate fit per arm, but **the canonical link is the load-bearing
condition and by-arm fitting does not substitute for it**: fitting a log-link
Gamma separately by arm removes the omitted-interaction failure mode and leaves
the link one untouched. Check it rather than assume it — `mean(fitted(fit))`
against the observed arm mean is one line, exact to machine precision under a
canonical link and not otherwise. (Gamma's canonical link is the inverse, not
the log; for Poisson and quasi-Poisson the log *is* canonical, which is one
reason a log-link Poisson is a reasonable cost model.) Outside a canonical-link
fit, augment, or accept that the standardised means carry the outcome model's
misspecification.

What an augmented estimator can cost is something an economic evaluation cannot
spare: a CEAC, a cost-effectiveness plane and incremental net benefit are all
computed from *paired* draws of incremental cost and incremental effect, and a
one-number AIPW or TMLE estimate per outcome, each carrying its own
influence-curve standard error, throws the cost-effect correlation away — unless
the two estimators' influence functions are stacked and their joint covariance
taken, or the whole estimator is bootstrapped by resampling *patients*. Either
route recovers the correlation and yields paired draws, so raise it as a finding
only when two separately estimated numbers with marginal standard errors are all
that is reported. The simplest route to paired draws is a joint cost-and-effect
model, standardised per posterior draw over the trial's covariate distribution —
`trial-based-cea-hta` owns that fit, `bayesian-cea-r-hta` what the draws feed.

## Balance diagnostics

**Assess balance with standardised mean differences, not p-values.** SMD < 0.1 is
the conventional target. Significance tests for balance are inappropriate: they
conflate imbalance with sample size, so a large trivial imbalance passes in a
small sample and a negligible one fails in a large sample. Reviewers still ask
for the "Table 1 with p-values" — decline and explain, or supply SMDs alongside.

Check balance on **means and higher moments**, using `cobalt::bal.tab()` with
`un = TRUE` and love plots. Balance on the mean of a variable does not imply
balance on its distribution.

## The reporting error that undoes good analysis

**The Table 2 fallacy.** It is common to present adjusted effect estimates for
the exposure *and* for every covariate from a single model in one table. Those
covariate coefficients are not interpretable as their causal effects: they are
conditional on the other variables in the model, may be controlled direct rather
than total effects, and may remain confounded even when the exposure's effect is
properly adjusted, because the adjustment set was chosen for the exposure and not
for them.

Report the effect estimate for **the exposure only**. If a covariate's effect is
also of interest, it needs its own adjustment set and its own model. This is the
single most common way a competently executed causal analysis gets misread.

## Design-based approaches

**Target trial emulation** (Hernán & Robins). Specify the randomised trial you
would run — eligibility, treatment strategies, assignment, follow-up start and
end, outcome, causal contrast, analysis plan — then emulate each component with
the observational data. Its value is that it forces the design errors into the
open, particularly:

- **Immortal time bias**, from misaligning time zero with treatment assignment —
  patients cannot have the outcome before they can be classified, so the treated
  group looks artificially protected. Aligning eligibility, treatment assignment
  and follow-up start at the same moment is the fix.
- **Prevalent user bias**, from including patients already on treatment, who by
  definition survived and tolerated it.

**Regression discontinuity** and instrumental variables exploit specific
structures; use them where the structure genuinely exists, not as fallbacks.

## Sensitivity analysis

Since exchangeability is untestable, quantify how fragile the conclusion is.

- **E-value** (VanderWeele & Ding): the minimum strength of association, on the
  risk-ratio scale, that an unmeasured confounder would need with both treatment
  and outcome to explain away the observed effect. Report it for the estimate and
  for the confidence limit nearer the null. Interpret it against the strength of
  *measured* confounders — an E-value of 1.4 is unimpressive if a known covariate
  has an association of 2.
- **Negative control outcomes and exposures** (Lipsitch et al.): an outcome that
  the treatment could not plausibly affect, sharing the suspected confounding
  structure. Finding an "effect" there exposes residual confounding directly.
- **Quantitative bias analysis** for a specified confounder.

## Reporting

State the estimand and target population; the DAG and the adjustment set it
implied; the positivity check; the estimator and both nuisance models; balance by
SMD; weight distribution and any truncation; how uncertainty was computed; and
the sensitivity analysis. Then state plainly that the causal interpretation rests
on no unmeasured confounding.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
Westreich & Greenland on the Table 2 fallacy; the estimand and assumption framing against Hernán
& Robins. Added 9 September 2026: what the FDA 2023 guidance and EMA/CHMP/295050/2013 do and do
not say about conditional versus unconditional effects, quoted from both documents.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
`WeightIt::weightit()`, `glm_weightit()`, `cobalt::bal.tab()` and
`marginaleffects::avg_comparisons()` signatures; `tmle` / `AIPW` usage; the ICH E9(R1), Ye et
al. and Rosenblum & van der Laan covariate-adjustment citations; the SMD < 0.1 convention;
Austin 2011, Cole & Hernán 2008, VanderWeele & Ding and Lipsitch citation details.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
