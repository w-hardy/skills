# Assumptions and estimands in population adjustment

The conceptual core, separated out because getting it wrong invalidates the analysis no matter how clean the code. Grounded in TSD 18 (population adjustment) and TSD 17 (unanchored / causal-inference methods).

> Sources: NICE DSU TSD 18 (Phillippo et al., population-adjusted indirect comparisons) and TSD 17 (unanchored comparisons / observational methods), <https://www.sheffield.ac.uk/nice-dsu>; R-HTA Ch. 13. Accessed 2026-07-03.

## Covariate roles (scale-specific)

- **Effect modifier**: alters the *relative* treatment effect on the chosen scale. Treatment is more/less effective at different covariate levels.
- **Prognostic factor**: affects outcomes on *all* treatments equally; doesn't change the relative effect.
- A covariate can be **both**, and its role is **scale-dependent** — prognostic on one scale (e.g. risk difference) can be effect-modifying on another (e.g. odds ratio). Always state the scale.

Why it matters: randomisation balances prognostic factors *within* a trial, so in an **anchored** comparison they cancel and only **effect modifiers** need adjustment. In an **unanchored** comparison there's no within-trial cancelling of the cross-study difference in absolute outcomes, so **prognostic factors matter too**.

## The three assumptions, escalating

1. **Constancy of relative effects** — standard NMA / the `network-meta-analysis-hta` consistency assumption. Relative effects identical (or exchangeable) across study populations. Broken by effect-modifier imbalance.

2. **Conditional constancy of relative effects** — anchored population adjustment. Relative effects can be *predicted* across populations *given the included effect modifiers*. Holds only if **all** effect modifiers are included **and correctly specified** (e.g. a linear interaction term when the truth is non-linear, or matching only means when higher moments matter, breaks it). Can also break under a non-collapsible measure if baseline risk differs between populations — then prognostic variables may need adjusting too. This is the achievable target for connected RCT networks.

3. **Conditional constancy of absolute effects** — unanchored adjustment (single-arm studies, disconnected networks). *Absolute* outcomes predictable across populations given **all prognostic and effect-modifying** covariates. Very strong: "if this were straightforward, there would be no need for RCTs." **Untestable; residual bias from any unobserved imbalanced covariate is unknown and may be substantial.** Decision-makers justifiably demand greater cost-effectiveness to offset the decision risk, and often discount unanchored evidence heavily.

## Anchored vs unanchored

- **Anchored**: a common comparator arm links the studies → relies on assumption 2 → adjust **effect modifiers**. The normal, defensible case.
- **Unanchored**: no common comparator → relies on assumption 3 → adjust **prognostic + effect-modifying** covariates *and* model baseline risk. Treat with strong caution; flag explicitly in any report.

"Doubly robust" methods (combining weighting + regression, "two chances" at a correct model) do **not** rescue unanchored comparisons: they are not robust to *omitted covariates in imbalance* (unobserved confounding), which is precisely the unanchored concern. Don't let "doubly robust" launder an untestable assumption.

## Target population (the TSD 18 centrepiece)

Estimates must be relevant to the **decision target population**. Two consequences often missed:
- Even if effect modifiers are *balanced across all studies*, NMA is still biased for a decision if the studies don't represent the target population.
- The target population **need not be any trial's population** — it may be best represented by a registry or cohort (in the worked example, the PROSPECT cohort, represented by none of the 9 trials).

This is what makes ML-NMR (and full-IPD NMR) decisive: they can produce estimates in an arbitrary target population. MAIC and STC are confined to the AgD study population, so for any decision where the target differs they reintroduce the bias adjustment was meant to remove — usually disqualifying regardless of execution quality.

## Marginal vs conditional estimands

Population-average treatment effects come in two non-equivalent forms:

| | Conditional | Marginal |
|---|---|---|
| `multinma` | `relative_effects()` | `marginal_effects()` |
| Meaning | average of individual-level treatment effects in the population | effect on the expected *number of events* in the population |
| Interpretation | "for the average patient" | "for the population total" |

**They coincide only under collapsibility or no effect modification.** Under a **non-collapsible** measure (OR, HR) **with effect modification**, they differ — and can give **conflicting treatment rankings**:
- the treatment with the best *average event probability overall* (marginal) may be *inferior for most individuals* (conditional), and vice versa,
- because with effect modification there may be **no single treatment best for everyone**.

Which to report:
- **Marginal** is often considered primary for population-level decisions (it's about the population's total events).
- For **cost-effectiveness specifically, the relevant estimand is expected net benefit over the population.** With heterogeneous effects, that's not a single relative effect at all — it should ideally be computed in an **economic model** (e.g. a DES, the `discrete-event-simulation-hta` skill) fed with **absolute effects** per treatment (and, where possible, per subgroup), not collapsed to one marginal or conditional number.

ML-NMR and full-IPD NMR are the **only** population-adjustment methods that deliver **both** conditional and marginal population-average effects **and** the absolute effects an economic model needs, in a chosen population. That's the practical reason they dominate when the analysis feeds a cost-effectiveness model rather than just reporting a relative effect.

## A short decision checklist
1. Is the comparison **anchored** (common comparator) or **unanchored**? Unanchored → assumption 3, much stronger, flag the risk.
2. What is the **target population**, and is it any trial's population? If not, MAIC/STC can't reach it → ML-NMR.
3. Which covariates are **effect modifiers** vs **prognostic**, on the chosen **scale**? Anchored adjusts EMs; unanchored adjusts both.
4. **Network size**: >2 studies → MAIC/STC can't synthesise it coherently → ML-NMR.
5. Which **estimand** does the decision need — and does the cost-effectiveness model want absolute effects rather than a single summary effect?
6. Are the assumptions **assessable** (residual heterogeneity/inconsistency in ML-NMR; ESS/overlap in MAIC) — and have you assessed them?
