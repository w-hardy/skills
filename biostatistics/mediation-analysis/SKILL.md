---
name: mediation-analysis
description: Decompose a total causal effect into direct and indirect pathways in R using the modern counterfactual framework - natural direct and indirect effects, controlled direct effects, interventional (randomised analogue) effects, exposure-mediator interaction, and sensitivity analysis. Use whenever the question is how or through what an exposure acts, or when appraising a paper reporting a "percentage mediated". Trigger on "mediation", "mediator", "indirect effect", "direct effect", "pathway analysis", "Baron and Kenny", "Sobel test", "percentage mediated", "proportion mediated", "regmedint", "CMAverse", or "does X act through Y" - even when unnamed. Prefer this over memory, because Baron-Kenny and product-of-coefficients are superseded, natural effects are not identified when a mediator-outcome confounder is affected by the exposure, and the cross-world assumption cannot be verified by any experiment. For total effects use causal-inference-gmethods.
---

# Mediation Analysis

Mediation asks strictly more of the data than a total effect does: you are now
identifying effects on **two** arrows plus the direct one, and the assumptions
required are correspondingly stronger and less checkable. Most published
mediation analysis under-reports how strong they are.

## Provenance

Verified 13 August 2026.

- VanderWeele TJ. *Explanation in Causal Inference: Methods for Mediation and Interaction*. OUP, 2015 — the reference text
- VanderWeele TJ, Vansteelandt S. *Epidemiologic Methods* 2014 — regression-based approaches with interaction
- **VanderWeele TJ, Vansteelandt S, Robins JM. *Epidemiology* 2014;25:300-6 — effect decomposition with an exposure-induced mediator-outcome confounder**
- VanderWeele TJ, Tchetgen Tchetgen EJ. *JRSS-B* 2017;79:917-38 — time-varying exposures and mediators; the mediational g-formula
- Baron RM, Kenny DA. *J Pers Soc Psychol* 1986 — the historical approach, for context
- Smith LH, VanderWeele TJ. *Epidemiology* 2019 — the E-value for mediation
- `regmedint` (CRAN), `CMAverse` (GitHub), `mediation` (CRAN)

## Why Baron-Kenny is not enough

The 1986 approach — a sequence of regressions, with the indirect effect as the
product of coefficients and the Sobel test for significance — is still widespread
and is superseded. It has no counterfactual definition of the estimands, so what
is being estimated is unclear once the outcome model is non-linear; it cannot
accommodate **exposure-mediator interaction**; the product-of-coefficients
decomposition does not hold for logistic or survival outcomes; and it gives no
account of the assumptions needed for a causal reading.

Use counterfactually-defined estimands and a regression-based or simulation-based
estimator that permits interaction.

## The estimands, and which one you actually want

| Estimand | Question | Identification |
|---|---|---|
| **Controlled direct effect (CDE)** | Effect of exposure if the mediator were *fixed at level m* for everyone | Weakest assumptions — needs only 1-3 below |
| **Natural direct effect (NDE)** | Effect of exposure with the mediator left at whatever it would naturally have been under no exposure | Needs all four, including cross-world |
| **Natural indirect effect (NIE)** | Effect of shifting the mediator from its no-exposure to its exposure value, holding exposure fixed | As NDE |
| **Interventional (randomised analogue) effects** | As natural effects, but shifting the mediator's *distribution* rather than each person's value | Identified even with an exposure-induced confounder |

**The CDE is under-used.** It answers the policy question directly — "how much of
the harm would remain if we blocked this pathway?" — and it is identifiable under
weaker assumptions than natural effects. If the mediator is something you could
actually intervene on, the CDE is usually the estimand you want. NDE and NIE give
a clean additive decomposition of the total effect, which is why they dominate
publication, but they buy that at a real cost in assumptions.

## The four assumptions, stated honestly

Identification of natural effects requires no unmeasured confounding of:

1. exposure → outcome
2. exposure → mediator
3. mediator → outcome
4. and **no mediator-outcome confounder that is itself affected by the exposure**

Assumption 3 is the one that most often fails in practice, because
mediator-outcome confounders are frequently post-baseline and unmeasured.

Two points that are usually left out and matter a great deal:

**The cross-world independence assumption.** Natural effects are defined using
counterfactuals that can never be jointly observed — the outcome under exposure
with the mediator set to its value under *no* exposure. That assumption cannot be
verified by any experiment, even a perfectly randomised one. This is not a
data-quality problem that a larger study fixes; it is a property of the estimand.
Say so in the Discussion.

**When assumption 4 fails, natural effects are not identified at all.** An
exposure-induced mediator-outcome confounder (an intermediate confounder) breaks
identification of NDE and NIE outright — no amount of adjustment recovers them,
because adjusting for it blocks part of the effect and not adjusting leaves
confounding. This is common: an exposure that changes disease severity, which in
turn drives both the mediator and the outcome.

The constructive response is **interventional effects** (VanderWeele,
Vansteelandt & Robins 2014; the mediational g-formula in VanderWeele & Tchetgen
Tchetgen 2017). These replace "set the mediator to the value it would have taken"
with "draw the mediator from the distribution it would have had", and **are**
identified in this setting. They are the right tool when an intermediate
confounder is present, and `CMAverse` implements them.

One caveat worth carrying: interventional effects do not in general satisfy the
mediational sharp null — an interventional indirect effect can be non-zero when
no individual has an indirect effect. They are a well-defined and useful
contrast, not a direct measure of mechanism.

## Exposure-mediator interaction

If the direct effect of the exposure depends on the level of the mediator, the
outcome model must include an exposure × mediator interaction term. Omitting it
biases the decomposition. Including it means the total effect decomposes into
**four** components rather than two — pure direct, pure indirect, a mediated
interaction, and a reference interaction — which is why modern software reports
four numbers where the older method reported two. Report the four-way
decomposition; the two-way version conceals where the interaction sits.

## Implementation

```r
library(regmedint)   # on CRAN; CMAverse is GitHub-only

fit <- regmedint(
  data          = dat,
  yvar          = "outcome",
  avar          = "exposure",
  mvar          = "mediator",
  cvar          = c("age", "sex", "baseline_severity"),
  a0 = 0, a1 = 1,          # the exposure contrast
  m_cde = 0,               # level at which the CDE is evaluated
  c_cond = c(60, 1, 2),    # covariate values the natural effects condition on
  mreg = "linear", yreg = "logistic",
  interaction = TRUE       # keep this TRUE unless you can justify otherwise
)
summary(fit)
```

`m_cde` and `c_cond` are not incidental: the CDE depends on the level at which
the mediator is fixed, and the natural effects are conditional on the covariate
values supplied. Report both.

For interventional effects, multiple mediators, or an exposure-induced
confounder, use `CMAverse::cmest()` with `model = "gformula"` or `"msm"`.

## Reporting

- **Proportion mediated is fragile.** It is unstable when the total effect is
  near null (a small denominator), can exceed 100% or go negative when direct and
  indirect effects have opposite signs, and is scale-dependent. Report the direct
  and indirect effects with confidence intervals as the primary result; give the
  proportion as a secondary descriptive figure, or not at all.
- **Confidence intervals** by bootstrap or the delta method — say which.
- **Sensitivity analysis is not optional**, given that three of the four
  assumptions are untestable. The E-value has been extended to mediation (Smith &
  VanderWeele); report it for the direct and indirect effects separately.
- State the estimand by name (CDE, NDE/NIE, or interventional), the assumed
  temporal ordering exposure → mediator → outcome and its justification, whether
  interaction was modelled, and — explicitly — that natural effects rest on a
  cross-world assumption no experiment can test.

## When not to do it

If exposure, mediator and outcome are measured at the same time, temporal
ordering is assumed rather than established, and the analysis is
uninterpretable. If the mediator is measured with substantial error, the indirect
effect is attenuated and the direct effect inflated — mediation is unusually
sensitive to mediator measurement error. And if the mediator is not something
anyone could intervene on, ask what decision the answer would inform before
proceeding.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
`regmedint()` argument names, checked against the package reference; VanderWeele, Vansteelandt & Robins on interventional effects when an exposure-induced confounder is present; the sharp-null caveat.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
`CMAverse::cmest()` arguments and `model =` options; the E-value-for-mediation citation details; `regmedint` also has `emm_ac_mreg` / `emm_ac_yreg` / `emm_mc_yreg` for effect-measure modification, not covered here.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
