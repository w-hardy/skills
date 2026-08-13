---
name: population-adjusted-comparisons
description: "Plan, build, check, and report population-adjusted indirect treatment comparisons (PAICs) for HTA in R (MAIC, STC, and multilevel network meta-regression, ML-NMR) when effect modifiers are imbalanced across trials and standard NMA would be biased. Use whenever there is a mix of individual patient data (IPD) and aggregate data (AgD) and the analysis must adjust for effect-modifier imbalance, target a specific decision population, incorporate single-arm studies, or connect a disconnected network. Trigger on phrases like \"MAIC\", \"matching-adjusted indirect comparison\", \"STC\", \"simulated treatment comparison\", \"ML-NMR\", \"multilevel network meta-regression\", \"population adjustment\", \"anchored or unanchored indirect comparison\", \"target population\", \"effect modifier imbalance\", \"TSD 18\", or \"TSD 17\". Also trigger when a manufacturer has IPD on their own study but only AgD on comparators. Builds on network-meta-analysis-hta; defer to nice-economic-evaluation for how the absolute effects feed the economic model."
---

# Population-adjusted indirect comparisons for HTA

Adjusting indirect comparisons for **effect-modifier imbalance** across trials, in R, following R-HTA chapter 13 and NICE DSU **TSD 18** (population adjustment) and **TSD 17** (unanchored / causal-inference methods).

> Sources: *R for Health Technology Assessment* (Baio et al., online at <https://gianluca.statistica.it/books/online/r-hta/>) — chapter mapping verified against the live ToC (Ch. 13 = population-adjusted indirect comparisons), accessed 2026-07-03. NICE DSU TSD 17 and TSD 18 (<https://www.sheffield.ac.uk/nice-dsu>). `multinma` signatures (`set_ipd()`, `set_agd_arm()`, `add_integration()`, `nma()`, `relative_effects()`, `marginal_effects()`, `predict()`) cross-checked against the pkgdown docs, accessed 2026-07-03. These methods matter because standard NMA assumes effect modifiers are balanced across all study populations *and* match the decision target population; when that fails, NMA is biased, and population adjustment is how you relax the assumption. The output — absolute effects or relative effects in a chosen population — is what feeds the economic model, so this sits upstream of the cost-effectiveness analysis.

## The assumptions are the entire subject — get these right first

Everything hinges on two covariate roles and three escalating assumptions.

**Effect modifiers vs prognostic factors.** An *effect modifier* alters the relative treatment effect on the chosen scale (treatment works better/worse at different covariate levels). A *prognostic factor* affects outcomes equally regardless of treatment. Both definitions are **scale-specific** (a variable can be prognostic on one scale and effect-modifying on another). This distinction is the whole game: in an *anchored* comparison, only effect modifiers need adjusting (prognostic factors cancel within trials by randomisation); in an *unanchored* comparison, prognostic factors matter too.

**Three escalating assumptions:**
1. **Constancy of relative effects** (standard NMA) — relative effects are the same across all study populations. Violated by effect-modifier imbalance.
2. **Conditional constancy of relative effects** (anchored population adjustment) — relative effects can be *predicted* across populations given the included effect modifiers. Requires **all** effect modifiers included and **correctly specified**. The achievable assumption for connected networks.
3. **Conditional constancy of absolute effects** (unanchored adjustment) — *absolute* outcomes can be predicted across populations given all prognostic *and* effect-modifying covariates. **Much stronger, widely considered very hard to satisfy** — "if this were straightforward, there would be no need for RCTs." Untestable; residual bias unknown and potentially substantial.

**Anchored vs unanchored.** *Anchored* = a common comparator arm links the studies (the normal connected-network case) → assumption 2. *Unanchored* = no common comparator (single-arm studies, disconnected networks) → assumption 3. Treat unanchored results with strong caution; decision-makers justifiably demand greater cost-effectiveness to offset the decision risk, and the assumptions are untestable.

**The target population is central (TSD 18).** Even with effect modifiers balanced across studies, if the studies don't represent the *decision* target population, NMA estimates are still biased for that decision. Estimates must be relevant to the target population — which **need not be any trial's population** (it may be best represented by a registry or cohort). This single requirement is what separates the methods below, because most of them can't target an arbitrary population.

## Method choice by IPD availability — and the one message that dominates

| IPD available | Method | Can target any population? | Network size |
|---|---|---|---|
| **All studies** | IPD network meta-regression (gold standard) | Yes | Any |
| **Mixed IPD + AgD** (the usual HTA case) | **ML-NMR** | **Yes** | **Any** |
| Mixed IPD + AgD | MAIC (reweighting) | **No — AgD study pop only** | Two-study only |
| Mixed IPD + AgD | STC (outcome regression) | **No — AgD study pop only** | Two-study only |
| **No IPD** | NMI, reference prediction, aggregate matching | Limited | Limited |

**The dominating message:** *ML-NMR is the only population-adjustment method (besides full-IPD NMR) that can produce estimates in any target population of interest, for a network of any size, with any mix of IPD and AgD.* MAIC and STC are doubly limited — to a **two-study** comparison, and to the **AgD study population**. In HTA terms, a MAIC/STC lets a manufacturer estimate only in their *competitor's* trial population, which is almost never the decision target population. That's usually disqualifying for the decision problem, however carefully the MAIC is executed. So unless the analysis is genuinely a two-study comparison where the AgD study population *is* the target, ML-NMR is the right default — and TSD 18 / the current literature point the same way.

ML-NMR also extends NMA cleanly: it reduces to IPD-NMR when all studies have IPD, and to standard AgD-NMA when no covariates are included — so it's not an exotic detour, it's the general case the `network-meta-analysis-hta` skill specialises.

See `references/ml-nmr-multinma.md` for the full ML-NMR pipeline and `references/maic-stc.md` for MAIC and STC (including when a two-study MAIC is legitimately the right tool, e.g. quick analysis where the AgD study is the target).

## MAIC in one paragraph (full code in the reference)

MAIC reweights IPD individuals by `w = exp(x'α)` (method of moments, equivalent to entropy balancing) so the reweighted IPD covariate moments match the AgD study's, after centring covariates on the AgD summaries. The estimable target is then *only* the AgD population. Two diagnostics are non-negotiable: the **effective sample size** `ESS = (Σw)² / Σw²` and a **histogram of the weights** — a large drop in ESS or extreme weights signals poor overlap, and MAIC *cannot extrapolate*, so poor overlap means bias and unstable variance. Variance via bootstrap or robust sandwich (`sandwich::vcovHC`). Anchored: `Δ_BC(AC) = Δ_AC(AC) − Δ_AB(AC)`.

## STC and the plug-in-means trap

STC is outcome regression: fit a model in the IPD, predict into the AgD population. The common **"plug-in means" anchored STC — substituting the AgD mean covariates into the model — is biased** whenever the model is non-linear in covariates (aggregation bias) or the effect measure is non-collapsible (log OR, log HR): the resulting conditional effect isn't compatible with the marginal effect from the AgD study. The fix is **simulation/G-computation STC** (Remiro-Azócar 2022), which simulates from the AgD covariate distribution to target a proper marginal effect and capture uncertainty correctly. Don't use plug-in-means STC with an OR/HR outcome. (Note: the claim that MAIC is "assumption-free" because no outcome model is stated is false — the matched moments and chosen scale imply a linear-in-moments outcome model.)

## Marginal vs conditional estimands — they can disagree

Population-average effects come in two forms that **do not coincide under non-collapsibility (OR/HR) with effect modification**:
- **Conditional** (`relative_effects()`): the average of individual-level treatment effects in the population.
- **Marginal** (`marginal_effects()`): the effect on the expected *number of events* in the population.

When effect modification is present these can give **conflicting treatment rankings** — the treatment best on average overall may be inferior for most individuals, and vice versa, because no single treatment is best for everyone. The marginal estimand is often considered primary for population decision-making. But for **cost-effectiveness specifically, the relevant estimand is expected net benefit over the population**, which with heterogeneous effects should ideally be computed in an economic model (e.g. a DES — the `discrete-event-simulation-hta` skill) fed with the absolute effects. ML-NMR and full-IPD NMR are the **only** methods that produce both conditional and marginal population-average effects *and* the absolute effects an economic model needs, in a chosen population.

## Feeding the economic model

The deliverables to the economic model are typically **absolute effects** in the target population — average event probabilities or survival curves per treatment — not just relative effects. ML-NMR's `predict(type = "response", ...)` produces these directly for the target population (given a baseline-risk distribution); they then become the inputs the `survival-analysis-hta`, `decision-modelling-hta`, or `discrete-event-simulation-hta` skills consume, and the `nice-economic-evaluation` skill governs how the probabilistic base case is taken. Survival outcomes — the most common PAIC application in oncology — are supported: MAIC extends via weighted survival models, and ML-NMR has a full survival implementation (parametric / M-spline, non-PH).

## Common pitfalls

- **Using a MAIC/STC estimate for a decision in a different population.** The estimate is valid *only* in the AgD study population; using it for the target population reintroduces exactly the bias population adjustment was meant to remove. If the target ≠ AgD study population, you need ML-NMR.
- **Adjusting for prognostic factors in an anchored analysis (or forgetting them in an unanchored one).** Anchored needs effect modifiers only; unanchored needs prognostic factors *and* effect modifiers (and baseline risk for absolute outcomes).
- **Treating unanchored results as comparable to anchored.** Unanchored rests on conditional constancy of *absolute* effects — untestable, very strong; flag the elevated decision risk explicitly.
- **Plug-in-means STC with a non-collapsible measure.** Aggregation + non-collapsibility bias; use G-computation STC.
- **Ignoring low ESS / extreme weights in MAIC.** Poor overlap → substantial bias and unstable variance; MAIC can't extrapolate out of it. Report ESS and the weight histogram every time.
- **Trying to scale MAIC/STC to a >2-study network.** They don't synthesise networks coherently; separate MAICs against different AgD studies sit in different, non-comparable populations and reuse the IPD. Use ML-NMR.
- **Conflating marginal and conditional estimands.** State which you're reporting; under non-collapsibility + effect modification they can rank treatments differently.
- **Relying on the shared-effect-modifier assumption silently.** In a small/two-study ML-NMR it may be needed to identify interactions (treatments in the same class sharing a mode of action); state it, and assess/relax it where the network allows (relax one covariate at a time).
- **Assuming "doubly robust" rescues unanchored comparisons.** Doubly-robust methods are *not* robust to omitted covariates in imbalance (unobserved confounding) — precisely the unanchored concern.

## Validating the design before analysis

`scripts/check_paic_setup.R` checks the design choices against TSD 18 logic before any model is fitted: whether the chosen method can actually target the stated decision population (flags MAIC/STC when target ≠ AgD study population), whether the anchored/unanchored setting matches the covariate adjustment (effect modifiers only vs prognostic + effect modifiers), whether a MAIC's ESS indicates adequate overlap, whether the network size suits the method (MAIC/STC are two-study only), whether plug-in-means STC is being used with a non-collapsible measure, and whether a small-network ML-NMR is relying on the shared-effect-modifier assumption. Run it at the planning stage — the wrong method for the target population is a problem no amount of careful execution fixes.
