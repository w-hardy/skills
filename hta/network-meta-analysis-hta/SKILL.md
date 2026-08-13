---
name: network-meta-analysis-hta
description: "Build, estimate, check, and report network meta-analyses (NMA) and indirect treatment comparisons for health economic evaluation in R, using multinma (Bayesian, Stan) and netmeta (frequentist). Use whenever the person synthesises relative treatment effects across a network of trials for an HTA: indirect comparison of treatments not compared head-to-head, pooling direct and indirect evidence, fixed vs random effects, heterogeneity, network meta-regression for effect modifiers, ranking treatments (rankograms, SUCRA, P-scores), or testing the consistency assumption (UME / node-splitting). Trigger on phrases like \"network meta-analysis\", \"NMA\", \"indirect treatment comparison\", \"mixed treatment comparison\", \"Bucher\", \"consistency assumption\", \"inconsistency\", \"node-splitting\", \"UME\", \"multinma\", \"netmeta\", or \"SUCRA\". For population-adjusted comparisons with effect-modifier imbalance (MAIC / STC / ML-NMR) hand off to population-adjusted-comparisons."
---

# Network meta-analysis for HTA

Synthesising relative treatment effects across a network of trials, in R, following R-HTA chapter 10.

> Sources: *R for Health Technology Assessment* (Baio et al., online at <https://gianluca.statistica.it/books/online/r-hta/>) — chapter mapping verified against the live ToC (Ch. 10 = network meta-analysis; the chapter's URL folder is numbered 09 but the chapter itself is 10), accessed 2026-07-03. The chapter's surgical-site-infection worked example, `multinma` + `netmeta` dual implementation, and consistency/inconsistency treatment (UME, node-splitting, design-based decomposition, meta-regression, disconnected networks) all confirmed. Package signatures cross-checked against the `multinma` pkgdown and `netmeta` CRAN docs, accessed 2026-07-03. NMA is the indirect-comparison method recommended by NICE, ISPOR, and the EU Joint Clinical Assessment; it sits at the top of the evidence hierarchy for relative effectiveness. In an HTA, the NMA's output (relative effects vs a reference treatment) is what feeds the economic model — the survival/decision/multistate skills consume these estimates, so getting the synthesis and its assumptions right is upstream of everything downstream.

## The conceptual core (don't skip — the assumptions are the whole game)

NMA generalises the **Bucher** indirect comparison: if A-vs-C and B-vs-C are each estimated from trials, then A-vs-B follows by subtraction *on the linear-predictor scale* (log OR, log HR, mean difference — the scale where effects are additive). The engine is the **consistency assumption**: relative effects relate through `d_xy = d_1y − d_1x`, where treatment 1 is the network reference. Everything in NMA — pooling, ranking, the validity of the answer — rests on this.

Two modelling choices sit on top:
- **Fixed (common) vs random effects.** Fixed assumes one true relative effect per comparison across all trials; random lets trial-specific effects vary Normally around the pooled effect with heterogeneity SD τ (`σ`). Choose on the *extent of heterogeneity* — similarity of populations, outcome definitions, timepoints, co-treatments — informed but not decided by fit statistics (DIC, residual deviance, I²). Compare τ to the size of the effects: if τ is large relative to the `d`'s, heterogeneity threatens the conclusions.
- **The estimation paradigm**: Bayesian (`multinma`) or frequentist (`netmeta`). Both are legitimate and the book runs the same example through each; they usually agree. Pick on the considerations below, not dogma.

## Which package — Bayesian (multinma) or frequentist (netmeta)

Neither is "correct"; they trade off differently.

- **`multinma`** (Bayesian, Stan-backed) — the more flexible and HTA-aligned choice. Handles IPD + aggregate data jointly, network meta-regression with proper propagation of uncertainty, survival NMA (parametric / piecewise-exponential / M-spline, non-PH), ML-NMR population adjustment, and gives full posterior distributions — which slot straight into a probabilistic economic model. Costs: needs prior specification (and its defaults warn for a reason — set them deliberately) and MCMC convergence checking. Prefer it when the NMA feeds a probabilistic economic model, when you have any IPD, or when you need meta-regression / survival / population adjustment.
- **`netmeta`** (frequentist, graph-theoretical) — fast, no priors, no MCMC, with an excellent inconsistency-diagnostics toolkit (`netheat`, `decomp.design`). Costs: aggregate-data only in the standard workflow, uses continuity corrections for zero-event arms, and gives point estimates + CIs rather than a posterior. Prefer it for a quick frequentist analysis, a sensitivity check on a Bayesian fit, or when its design-level inconsistency visualisation is the goal.

A good HTA pattern is to run both: `multinma` as the base case feeding the economic model, `netmeta` as a corroborating check with strong inconsistency diagnostics. See `references/multinma-bayesian.md` and `references/netmeta-frequentist.md` for the full workflows.

## The standard workflow (either package)

1. **Build and inspect the evidence network.** Set up the network object, **confirm it's connected** (a treatment with no direct-or-indirect path to the reference can't be estimated), and plot it (node size ~ sample size, edge thickness ~ number of trials). A disconnected network stops the analysis dead — handle separately (out of scope here; needs unanchored MAIC/STC or specialised methods).
2. **Fit fixed and random effects**, compare (DIC/residual deviance in Bayesian; I²/Q in frequentist), and choose.
3. **Check convergence** (Bayesian: Rhat < 1.05, adequate ESS) before reading any estimate.
4. **Report relative effects** vs the reference on the linear-predictor scale, then exponentiate (to OR/HR) for interpretation. CrI/CI excluding the null = evidence of a difference.
5. **Rank treatments** (rankograms, SUCRA / P-scores) — with the health warning below.
6. **Test the consistency assumption** (UME and/or node-splitting; design-by-treatment Q in netmeta). This is not optional in an HTA.
7. **Consider meta-regression** if effect modifiers are plausibly imbalanced.

## Network meta-regression — only for effect modifiers

Meta-regression explains between-trial variation in *relative* effects using trial-level covariates. The one conceptual trap to get right: **only treatment-effect modifiers matter, not prognostic factors** — prognostic factors cancel within trials by randomisation, so adjusting for them does nothing for the comparison. Put a covariate in only if it plausibly modifies the treatment effect.

Caveats that bite: aggregate-data meta-regression is badly underpowered (rule of thumb ~10 trials with good covariate spread per coefficient, rarely available), and risks **aggregation bias** — a trial-mean covariate is not the patient-level relationship. IPD meta-regression (or ML-NMR, the `population-adjusted-comparisons` skill) is far more reliable. In `multinma` use `regression = ~.trt:covariate` with `class_interactions`; share the coefficient across treatments (`"common"`) when evidence is thin, accepting it's a strong assumption.

## Inconsistency — testing the assumption the whole method rests on

Inconsistency is direct evidence disagreeing with indirect evidence on the same comparison (caused by effect-modifier imbalance between the trials informing each path). It's testable wherever there's a **loop** of evidence, but it can be present even where it can't be tested. Three tools:
- **UME (unrelated mean effects)** — a global test: refit treating every contrast as independent (dropping consistency), compare DIC/residual deviance to the consistency model. A big improvement ⇒ inconsistency.
- **Node-splitting** — a local test: split direct vs indirect evidence on each loop edge and compare; flags *which* comparisons are inconsistent (small Bayesian p-values).
- **Design-by-treatment / Q decomposition** (netmeta's `decomp.design`, visualised by `netheat`): decomposes `Q_total = Q_het + Q_inc` and locates which *designs* drive inconsistency, including detaching designs to see the effect.

Crucial point on what to do when you find it: a full design-by-treatment interaction model may fit better but is **meaningless for treatment-effect estimation** — you can't use it for inference. Inconsistency is a signal to go back to the trials and clinical experts to understand *why* the evidence disagrees, not a model to estimate around. See `references/inconsistency-testing.md`.

## Ranking — useful, and easy to over-read

Rankograms, SUCRA, and P-scores summarise how treatments perform across the network. Read them honestly: a "spiky" rankogram = confidence a treatment holds a rank; a "flat" one = uncertainty about its rank. The probability of being *best* is seductive but unstable when uncertainty is high — a treatment can rank first on a thin, noisy comparison. Always report ranks alongside the relative effects and their intervals, never instead of them, and never let "ranked first" override an effect estimate whose CrI crosses the null.

## Feeding the NMA into an economic model

The NMA's relative effects are inputs to the downstream skills:
- **Constant relative effect** (log OR / log HR): apply to a baseline to get each treatment's absolute effect; a PH log-HR can go straight into `hesim` via `params_surv_list` (the `multistate-models-hta` skill) or scale survival curves (the `survival-analysis-hta` skill).
- **Survival NMA** with time-varying effects: `multinma`'s parametric/piecewise/M-spline survival NMA, or the two-step multivariate NMA of survival parameters, produces per-arm survival inputs — the `survival-analysis-hta` skill covers the per-arm fitting; this skill covers the network synthesis.
- Carry the **full uncertainty** through: Bayesian posterior draws propagate cleanly into a probabilistic economic model; don't collapse to a point estimate. The `nice-economic-evaluation` skill covers the probabilistic-base-case expectation.

## Common pitfalls

- **Synthesising on the natural scale instead of the linear predictor.** Pool log ORs/HRs, not ORs/HRs — effects are additive only on the link scale. Exponentiate only for final reporting.
- **Skipping the connectivity check.** A disconnected network can't be analysed by standard NMA; confirm connection before fitting.
- **Relying on default priors in multinma.** They deliberately warn — set `prior_intercept`, `prior_trt`, `prior_het` for your outcome scale; a prior that's vague for a log-OR may be informative for another outcome.
- **Reading estimates before checking convergence.** Rhat ≥ 1.05 or low ESS means the numbers aren't trustworthy yet.
- **Meta-regressing on prognostic factors.** Only effect modifiers belong in the regression; prognostic factors cancel by randomisation.
- **Over-trusting "probability best".** Unstable under high uncertainty; report with the effect estimates, not instead of them.
- **Treating inconsistency as a nuisance to model away.** The design-by-treatment model that "fixes" it can't be used for inference — investigate the cause instead.
- **Ignoring zero-event arms.** netmeta adds a 0.5 continuity correction automatically (affecting estimates); multinma handles zero cells in the likelihood but those arms still fit poorly — check residual deviance.

## Validating network setup before fitting

`scripts/check_nma_network.R` runs the pre-fit structural checks: that the arm-level data are coherent (events ≤ patients, no negative counts), that every treatment connects to the reference (a reachability check on the comparison graph, flagging disconnected components), that the reference treatment exists, and that multi-arm trials aren't carrying duplicate same-treatment arms (which `netmeta` rejects and which need merging). Run it before `set_agd_arm()` / `pairwise()` — a disconnected or malformed network otherwise fails deep inside the fit with an opaque error.
