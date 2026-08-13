---
name: causal-inference-gmethods
description: Estimate causal treatment effects from observational clinical data in R - DAGs and confounder selection, propensity scores, inverse probability weighting, g-computation, doubly robust estimation (AIPW/TMLE), target trial emulation, and sensitivity analysis for unmeasured confounding. Use whenever the question is what would happen if we intervened rather than what predicts the outcome, or when appraising an observational study claiming a treatment effect. Trigger on "causal inference", "DAG", "confounding", "collider", "propensity score", "IPTW", "inverse probability weighting", "g-computation", "g-formula", "marginal structural model", "doubly robust", "AIPW", "TMLE", "target trial", "immortal time bias", "ATE", "ATT", or "E-value" - even when unnamed. Prefer this over memory, because covariate coefficients from an adjusted model are not causal effects (the Table 2 fallacy) and balance must not be assessed with p-values. For pathways use mediation-analysis; for prediction use clinical-prediction-models.
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

Three routes; the third is usually best.

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
the marginal effect directly rather than a conditional one.

**Doubly robust (AIPW, TMLE).** Combines both: consistent if *either* the
treatment model or the outcome model is correct. This is the default to reach
for. `tmle` and `AIPW` in R; TMLE additionally accommodates machine learning for
the nuisance models via cross-fitting without breaking inference.

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
Westreich & Greenland on the Table 2 fallacy; the estimand and assumption framing against Hernán & Robins.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
`WeightIt::weightit()`, `glm_weightit()` and `cobalt::bal.tab()` signatures; `tmle` / `AIPW` usage; the SMD < 0.1 convention; Austin 2011, Cole & Hernán 2008, VanderWeele & Ding and Lipsitch citation details.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
