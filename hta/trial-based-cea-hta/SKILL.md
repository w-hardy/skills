---
name: trial-based-cea-hta
description: "Build Bayesian models of patient-level cost and health outcome data from a trial, in R, to produce paired posterior draws of population-average cost and effect per arm for a within-trial cost-effectiveness analysis. Use whenever the data are individual patients with costs and QALYs (or another effect measure) and the goal is an economic evaluation: constructing QALYs from repeated utility measurements, adjusting for baseline utility, modelling costs and effects jointly so their correlation survives, choosing distributions for skewed costs and bounded QALYs, handling structural zero costs or QALYs piled at 1, handling missing economic outcomes, and summarising to arm-level means. Trigger on \"trial-based economic evaluation\", \"within-trial CEA\", \"joint model of costs and QALYs\", \"cost-effectiveness from patient-level data\", \"QALYs from EQ-5D\", \"skewed costs\", or \"structural zeros\". Hands the resulting draws to bayesian-cea-r-hta for CE planes, CEACs and VOI."
---

# Trial-based Bayesian cost-effectiveness analysis

This skill owns one job: **turning individual patient-level trial data into paired posterior draws of
population-average cost and effect per arm.** That is the missing middle between fitting a regression
and doing decision analysis. It starts at a per-patient dataset of resource use and health outcomes,
and finishes at an `S × T` matrix of posterior draws for mean cost and an `S × T` matrix for mean
effect — the exact input that `bayesian-cea-r-hta` (and `BCEA::bcea()`) consumes.

Everything upstream of the draws is here. Everything downstream of them — CE plane, CEAC, net
benefit, EVPI — is `bayesian-cea-r-hta`. Do not do decision analysis here, and do not fit these
models there.

> Sources: *Bayesian Modelling in Health Technology Assessment* — Gianluca Baio (Chapman &
> Hall/CRC, 2026); book page <https://gianluca.statistica.it/books/bmhta/>. Chapter 5
> (cost-effectiveness analysis with individual-level data) and Chapter 10 (missing data and
> structural values in HTA) are the methodological basis for this skill. Method claims are
> anchored to the companion code repository <https://github.com/giabaio/bmhta-examples> (MIT),
> inspected at commit `d2a6298` (2026-08-07) — specifically `05-ild/ild.R`, `10-missing-data/`
> and their chapter `README.md` files; accessed 2026-09-09. The book's own text was not
> reachable from the authoring environment, so claims here are grounded in the companion code
> and its annotations rather than quoted prose.
>
> **Deliberate deviation from the source.** The book implements every model in JAGS via `R2jags`.
> This skill states the models in **brms** instead, because brms is this repository's Bayesian
> regression stack (`brms-modelling`) and expresses all of these models natively — including the
> hurdle and zero-one-inflated families that Chapter 10 hand-rolls. The *statistical* content is
> the book's; the implementation is not. See `references/joint-cost-effect-models.md` for the
> translation, and read the JAGS formulations only if you are maintaining a legacy BUGS/JAGS
> model. Package APIs could not be re-verified against CRAN from the authoring environment —
> check argument names against the installed version before running anything here.

## The one non-negotiable principle

**Costs and effects must be modelled jointly, and the joint posterior must survive to the draws.**

Cost and effect are correlated within a patient — a patient who does badly usually costs more, and a
treatment that works usually shifts both. Fitting two separate regressions and pairing their draws
afterwards asserts a correlation of zero that you never checked. The decision quantities downstream
(INB, CEAC, the CE-plane cloud's tilt) are functionals of the *joint* distribution of (Δc, Δe), so a
wrong correlation propagates straight into the answer. Every model in this skill is a joint model,
and the deliverable is draws that are paired row-wise: row *i* of the cost matrix and row *i* of the
effect matrix must be the same posterior draw.

The second principle follows from it: **do not collapse to point estimates anywhere in the pipeline.**
Not after the QALY calculation, not after the regression, not when summarising to arm means. The
whole apparatus exists to carry uncertainty forward.

## Workflow

| Stage | What it produces | The question to ask |
|---|---|---|
| Construct outcomes | Per-patient QALYs and total costs | AUC over the utility profile with discounting, not a sum of utilities? Costs on a sensible scale? |
| Inspect distributions | Histograms of cost and effect by arm | Costs right-skewed? QALYs left-skewed or bounded? A spike at 0 cost or 1 QALY? |
| Specify the joint model | A brms multivariate or conditional formula | Are the two outcomes linked? Is baseline utility adjusted for? Are families matched to the shapes seen above? |
| Set priors | Explicit priors, checked by prior predictive | Are scale priors interpretable on the data's scale? Has the cost rescaling been reconciled with them? |
| Fit and diagnose | A fitted model with clean diagnostics | Rhat, ESS, divergences checked *before* anything is read off? |
| Summarise to arm means | `S × T` draws of mean cost and mean effect | Is the population-average correct under the link used — direct, or via posterior prediction? |
| Compare models | LOO (and DIC where the source workflow demands it) | Same data and likelihood across candidates? Structural uncertainty reported, not hidden? |
| Hand off | Paired draws to `bayesian-cea-r-hta` | Rows aligned? Natural scale (£ and QALYs), not the modelling scale? |

Full detail:

- `references/qaly-construction.md` — QALYs from repeated utility measurements (trapezoid AUC),
  within-trial discounting, and why baseline utility must be adjusted for.
- `references/joint-cost-effect-models.md` — the marginal-conditional factorisation, its equivalence
  to a bivariate/SUR model, distribution choice for costs and effects, scaling, and the brms
  translations of each.
- `references/structural-values.md` — structural zero costs and QALYs piled at 1: hurdle and
  zero-one-inflated models, and the mixture formula for the population average.
- `references/missing-economic-outcomes.md` — missingness in trial costs and QALYs, when the joint
  Bayesian model handles it natively, and when to reach for multiple imputation instead.
- `references/population-average-summaries.md` — recovering arm-level means under non-linear links
  by posterior prediction, and what must not be done instead.
- `references/model-comparison-and-handoff.md` — comparing candidate economic models, structural
  uncertainty, and the exact contract for passing draws downstream.

Read the reference for the stage you are on; do not read all six.

## What makes this different from a generic regression task

If the answer to "which skill?" is unclear, this is the discriminator. A generic Bayesian regression
skill will happily fit a model to cost data. It will not tell you:

- that a QALY is an **area under a utility curve**, not a measurement, and that computing it wrongly
  is the most common error in the whole analysis;
- that **baseline utility is imbalanced by chance in most trials** and that not adjusting for it
  biases the incremental QALY estimate;
- that the deliverable is the posterior of an **arm-level mean**, not individual predictions;
- that costs and effects must be modelled **together**;
- that a QALY of exactly 1 is usually a **structural** value, not a draw from a continuous density;
- that the analysis is only finished when the draws reach the decision model **still paired**.

Those are health-economics facts, not regression facts. That is this skill's content. The regression
machinery — formula syntax, prior classes, `loo()`, convergence thresholds, hurdle-family mechanics,
`mi()` — belongs to `brms-modelling` and should be used from there, not restated here.

## Boundaries with the neighbouring skills

- **`brms-modelling`** owns the fitting machinery: formulas, families, priors, sampler settings,
  diagnostics, posterior predictive checks and `loo()`. This skill decides *which* model an economic
  outcome needs and *why*; brms-modelling is how you build and check it. For hurdle and
  zero-one-inflated specification read its `references/model-families/distributional.md`; for
  in-model imputation read its `references/special-terms.md`.
- **`bayesian-cea-r-hta`** picks up exactly where this skill stops: paired draws in, CE plane,
  CEAC/CEAF, incremental net benefit, BCEA objects, EVPI/EVPPI/EVSI out. Model averaging across
  candidate economic models is also its (`struct.psa()`); this skill produces the candidates.
- **`missing-data-mice`** owns multiple imputation as a general method — mechanisms, `mice()`
  workflow, convergence, MNAR sensitivity, pooling. This skill covers only what is specific to
  economic outcomes, and hands off for the general machinery.
- **`nice-economic-evaluation`** owns the reference case: the discount rate to use, the perspective,
  which utility instrument, what a submission must demonstrate. This skill applies those choices;
  it does not decide them.
- **`survival-analysis-hta`** owns time-to-event modelling and extrapolation beyond follow-up. This
  skill is *within-trial*: the horizon is the trial's own follow-up. The moment the question becomes
  "what happens after the trial ends", it is a decision model, and
  `decision-modelling-hta`/`survival-analysis-hta` own it.
- **`causal-inference-gmethods`** owns g-computation for confounded observational data. The
  posterior-predictive standardisation used here shares its logic but not its problem: in a
  randomised trial the issue is a non-linear link, not confounding. Go there if the data are
  observational and the estimand needs confounding control.
