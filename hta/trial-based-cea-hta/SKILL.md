---
name: trial-based-cea-hta
description: "Build or review Bayesian models of patient-level trial cost and outcome data in R,
producing paired posterior draws of population-average cost and effect per arm for a within-trial
cost-effectiveness analysis. Use whenever the data are individual patients with costs and QALYs
(or another effect measure): QALYs from repeated utilities, baseline-utility adjustment, modelling
costs and effects jointly so their correlation survives, distributions for skewed costs and
bounded QALYs, structural zeros or QALYs piled at 1, missing economic outcomes, arm-level means.
Use it equally to review or critique an existing within-trial economic evaluation — its code,
model choices or draws. Trigger on \"trial-based economic evaluation\", \"within-trial CEA\",
\"joint model of costs and QALYs\", \"QALYs from EQ-5D\", \"skewed costs\", or \"structural
zeros\". Hands draws to bayesian-cea-r-hta for CE planes, CEACs and VOI."
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

> Sources: *Bayesian Models in Health Technology Assessment* — Gianluca Baio (CRC Press, published
> 7 August 2026), online edition <https://gianluca.statistica.it/books/online/bmhta/>, read and
> verified section by section on 2026-09-09.
>
> **Chapter 5** (cost-effectiveness analysis with individual-level data) is the methodological
> backbone: §5.1 for QALY construction and discounting, §5.2 for the three joint models, §5.2.3 for
> non-linearity and posterior-predictive estimation, §5.3 for model comparison, §5.4 for the hand-off
> to `BCEA`. **Chapter 10** contributes the framing for missing economic outcomes (§10.1-10.4) and
> the structural-values treatment (§10.4.1). Note Chapter 10 sits in the book's Part III, which is
> deliberately lighter on code and defers the full missing-data workflow to Gabrio et al. (2025) in
> *R for HTA* — so this skill's Chapter 10 material is the concepts plus the MenSS example, not a
> port of a worked chapter.
>
> Companion code: <https://github.com/giabaio/bmhta-examples> (MIT), commit `d2a6298` (2026-08-07),
> `05-ild/ild.R` and `10-missing-data/`.
>
> **Deliberate deviation from the source.** The book implements every model in JAGS via `R2jags`.
> This skill states the models in **brms** instead, because brms is this repository's Bayesian
> regression stack (`brms-modelling`) and expresses all of these models natively — including the
> hurdle and zero-one-inflated families that Chapter 10 hand-rolls. The *statistical* content is
> the book's; the implementation is not. See `references/joint-cost-effect-models.md` for the
> translation, and read the JAGS formulations only if you are maintaining a legacy BUGS/JAGS
> model. The brms claims here (`set_rescor()`'s gaussian/student restriction, the `zoi`/`coi`/`hu`
> distributional parameters) were verified against brms 2.23.0 on 2026-09-09; `BCEA` and `missingHE`
> were not installed in that environment, so check their signatures against the installed version
> before running anything that calls them.

## The one non-negotiable principle

**Costs and effects must be modelled jointly, and the joint posterior must survive to the draws.**

Cost and effect are correlated within a patient — a patient who does badly usually costs more, and a
treatment that works usually shifts both. Fitting two separate regressions and pairing their draws
afterwards asserts a correlation of zero that you never checked. The decision quantities downstream
(INB, CEAC, the CE-plane cloud's tilt) are functionals of the *joint* distribution of (Δc, Δe), so a
wrong correlation propagates straight into the answer. Every model in this skill is a joint model,
and the deliverable is draws that are paired row-wise: row *i* of the cost matrix and row *i* of the
effect matrix must be the same posterior draw.

**The correlation must be modelled; no one mechanism is mandated — and the obvious one is often
unavailable.** brms' residual-correlation term, `set_rescor(TRUE)`, works only for `gaussian()` and
`student()` families (verified against brms 2.23.0). The moment costs take `Gamma(link = "log")` or
`hurdle_gamma()`, `set_rescor(FALSE)` is not a defect; it is the only thing brms will accept. Three
routes carry the correlation:

- **Joint Normality with `set_rescor(TRUE)`** — the most transparent, and available only here.
- **Marginal-conditional factorisation (MCF)** — the effect enters the right-hand side of the cost
  equation, so the dependence runs through a coefficient rather than a residual correlation. Works
  across families, and is the usual answer for a Gamma or hurdle cost model.
- **A shared or correlated random effect** — a latent term in both linear predictors, written
  `(1 | p | id)` in brms so the two submodels' group-level effects are correlated rather than
  independent. It is the route available when the families differ and making one outcome a
  predictor of the other is unwanted.

All three are set out in `references/joint-cost-effect-models.md`. So do **not** report
`set_rescor(FALSE)` as a finding on its own. Report it when the model is Gaussian throughout and the
correlation was simply dropped, or when none of the three routes is present. The defect is an
*unmodelled* correlation, not a particular argument value.

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

## Reviewing an existing analysis

When the task is to review a within-trial CEA someone else wrote, work this checklist rather than
reading the repository in file order.

**Check the record before reporting.** Where the work has one — a decision log, a plan, an issue
tracker, a statistical analysis plan, prior review artefacts — search it for the finding before
you write it up, and say what you searched. A deviation that is documented, ruled on and justified
is a conforming outcome, not a defect, and reporting it as one costs the reader more than it
saves. Where there is no such record, say so: "not addressed anywhere I could find" is itself part
of the finding. This applies to substantive findings, not to every observation — do not spend a
search on a typo. This retires a deviation from a plan, a convention or a prior recommendation; a
wrong number, an invalid inference, or a defect in something reported stays a finding however well
documented — cite the ruling and report it anyway, because a record that acknowledges a defect
documents it, it does not fix it.

**Size the finding before you grade it.** Say what the finding moves, and by how much, before
assigning severity: the estimate, the decision, the reported number, the failure rate, the
runtime. A defect in a path nothing consumes — dead code, an unreported exploratory branch, a
value computed and discarded — is not the same as one in a result somebody acts on, and grading
them alike makes the whole list harder to act on. Note the trap in the other direction: anything
pre-specified and reported *is* a result somebody acts on, sensitivity and scenario analyses
included, so "it's only a sensitivity analysis" is not a reason to downgrade.

**Read first, in this order:** the analysis plan or protocol, to learn what was pre-specified; the
script that produces the numbers actually reported; and the object handed to `bcea()` or its
equivalent. Work backwards from the shipped number. Reviewing forwards from the data-loading script
spends the budget on code that may feed nothing.

**Then check, in this order** — each item names the reference that owns the rule:

1. **Outcome construction.** Is the QALY an AUC over the utility profile, in years, discounted with
   baseline undiscounted, and is baseline utility a covariate in the effects model?
   (`qaly-construction.md`.) These are upstream of everything and the errors are silent.
2. **Is the correlation modelled at all** — by `set_rescor(TRUE)`, an MCF term, or a correlated
   random effect? Which of the three is a modelling choice, not a defect (see the principle above).
   (`joint-cost-effect-models.md`.)
3. **Do the families match the histograms**, including any spike at zero cost or at the maximum
   QALY, and is treatment in the boundary component's formula? (`structural-values.md`.)
4. **Are the arm means standardised**, or read off the coefficients under a non-identity link — and
   with a group-level term, is `re_formula` the one the stated estimand needs? On an MCF cost model,
   is the effect integrated over its arm-`t` distribution, or held at each patient's observed value
   while the arm is flipped? This is the most consequential family of defects that looks like working
   code. (`population-average-summaries.md`.)
5. **Is missingness declared and handled** — proportions by arm, mechanism stated, `nobs()` checked
   against the randomised sample, an MNAR sensitivity analysis with a tipping point?
   (`missing-economic-outcomes.md`.)
6. **Do the draws satisfy the hand-off contract** — paired row-wise, same arm order, natural scale,
   no `NA`s, `S` adequate? (`model-comparison-and-handoff.md`.)

**What counts as a documented choice rather than a defect.** Each of these is a legitimate finding
only with the extra condition attached:

- `set_rescor(FALSE)` with a non-Gaussian family — forced, not chosen. A finding only if no other
  route carries the correlation.
- A common dispersion in a cost or effect model, in any family — an efficiency and interval-width
  issue, not a biased increment (`joint-cost-effect-models.md`).
- A Gaussian base case whose predictions could spill past a bound — a finding only where an
  out-of-range value reaches a reported quantity (`structural-values.md`).
- A complete-case fit, or a deliberately simpler model, kept as a stated comparator in the model
  ladder rather than presented as the base case.
- A scenario or sensitivity analysis that departs from the base case by **pre-specified design** —
  the departure is the point, and is not itself the defect. That is not licence to downgrade a
  defect found *inside* one: a pre-specified analysis that is reported is a result somebody acts on.
- Centring an MCF's effect term on the observed rather than the model-implied arm mean — a stated
  approximation in this skill's brms translation (`joint-cost-effect-models.md`).

## What makes this different from a generic regression task

If the answer to "which skill?" is unclear, this is the discriminator. A generic Bayesian regression
skill will happily fit a model to cost data. It will not tell you:

- that a QALY is an **area under a utility curve**, not a measurement, and that computing it wrongly
  is the most common error in the whole analysis;
- that **baseline utility is the strongest prognostic covariate available** and that adjusting for
  it is what buys a usable interval — and, under a non-linear link, changes the estimand;
- that the deliverable is the posterior of an **arm-level mean**, not individual predictions;
- that costs and effects must be modelled **together**;
- that a spike of QALYs at exactly 1 may be a **structural** value rather than a draw from a
  continuous density, and how to tell that apart from a measurement artefact;
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
