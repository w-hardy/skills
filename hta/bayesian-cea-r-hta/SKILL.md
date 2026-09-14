---
name: bayesian-cea-r-hta
description: "Post-process and present Bayesian cost-effectiveness analyses in R — PSA draws,
cost-effectiveness planes, CEAC/CEAF curves, incremental net benefit, the BCEA package,
value-of-information analysis (EVPI/EVPPI/EVSI), and decision-model calibration. Use for paired
cost/effect draws from a trial-based or decision-analytic model: net benefit at a threshold,
bcea(), or \"is more research worth it\" (VOI). Trigger on \"PSA\", \"CEAC\", \"CEAF\", \"EVPI\",
\"EVPPI\", \"cost-effectiveness plane\", \"net benefit\", \"BCEA\" or \"willingness to pay\" even
when the skill is not named — and whenever an existing model's inputs change (survival
extrapolation, utilities, unit costs, transition probabilities, population), so the ICER, net
benefit and CEAC downstream need re-checking, even though none of those words appear. For NICE
compliance use nice-economic-evaluation; for patient-level data use trial-based-cea-hta; for model
structure use decision-modelling-hta, multistate-models-hta, or discrete-event-simulation-hta."
---

# Bayesian cost-effectiveness analysis in R (R-HTA / BCEA)

This skill covers what happens *after* a cost-effectiveness model produces simulations: turning
paired cost/effect draws into decision quantities (incremental net benefit, CEAC/CEAF, CE plane),
quantifying whether more research is worthwhile (EVPI/EVPPI/EVSI), and the R machinery for both
(BCEA and draws-native code). The structure side — what to get right *inside* a tree/Markov/
patient-level model so its draws mean what they claim, plus calibration — is summarised in
`references/model-structures.md`, with the build mechanics owned by the dedicated skills
(`decision-modelling-hta`, `multistate-models-hta`, `discrete-event-simulation-hta`,
`survival-analysis-hta` for the time-to-event inputs).

## Sources

- *R for Health Technology Assessment* — Baio and colleagues; online edition at
  <https://gianluca.statistica.it/books/online/r-hta/>. Verified against Ch. 1 (decision
  theory, net benefit, PSA, value of information — §1.7, §1.7.1, §1.8) and Ch. 5 (within-trial
  cost-effectiveness — CE plane, CEAC — §5.3–5.4); accessed 2026-07-03. Note: the online
  edition has **no standalone Bayesian-CEA/PSA/BCEA/VOI chapter** — that material is distributed
  through Ch. 1 (theory) and Ch. 5 (applied within-trial), with the model-structure content in
  Chs. 8–9, 11–12.
- *Bayesian Cost-Effectiveness Analysis with the R package BCEA* — Baio, Berardi & Heath
  (Springer, 2017). Package API cross-checked against the `BCEA` CRAN documentation; accessed
  2026-07-03.
- *Bayesian Models in Health Technology Assessment* — Baio (CRC Press, 2026), Ch. 12
  (value of information), for the EVPPI method comparison, Info Rank, and ENBS-based study design in
  `references/value-of-information.md`; anchored to the companion code at
  <https://github.com/giabaio/bmhta-examples> commit `d2a6298`, accessed 2026-09-09.

> Anchoring: method claims are pinned at the chapter/section level of the sources above (e.g.
> "R-HTA §1.8"). Function signatures are matched to the current CRAN `BCEA` — check against the
> installed version before running, as argument names have changed across releases (see
> `references/bcea-package.md`).

## The one non-negotiable principle

**Decision quantities are functionals of the joint distribution of (Δcost, Δeffect).** Every
step must preserve the pairing of cost and effect draws — same simulation row, same parameter
draw, same imputation. Summarising costs and effects separately and recombining them (e.g.
computing an ICER from two marginal means, or a CEAC from marginal quantiles) silently destroys
the correlation that the whole Bayesian apparatus exists to carry. When reviewing, the first
check is always: where do the draws come from, and is row *i* of the cost vector the same world
as row *i* of the effect vector?

## Workflow

| Stage | What it's for | Key question when reviewing |
|---|---|---|
| Draws | PSA / posterior simulations of costs & effects per strategy | Paired? Enough draws (≥1,000; more for VOI)? On the natural scale? |
| Net benefit | INB(λ) = λ·Δe − Δc as the decision-canonical scale | Is the ICER being used where INB should be (sign/quadrant problems)? |
| Summaries | CE plane, CEAC, CEAF, expected INB over a λ grid | CEAC read as P(cost-effective), not as a confidence statement about the ICER? Frontier used when >2 strategies? |
| VOI | EVPI, EVPPI, (EVSI) — value of resolving uncertainty | Population-scaled with stated horizon/discounting before comparing to research costs? |
| Structure | Decision tree / Markov / patient-level model feeding the draws | Cycles, half-cycle handling, discounting, calibration targets explicit? |

Full detail:

- `references/psa-and-summaries.md` — draws conventions, ICER pathologies, CE plane, CEAC/CEAF,
  net-benefit framework, multi-comparator rules.
- `references/value-of-information.md` — EVPI from draws (and the opportunity-loss route),
  regression-based EVPPI with the GAM/GP/BART choice and Info Rank, EVSI across candidate study
  sizes, population scaling, and ENBS-based sample-size selection versus a power calculation.
- `references/bcea-package.md` — the `bcea()` object, its summary/plot functions, and when to
  use BCEA vs draws-native code.
- `references/model-structures.md` — decision trees, Markov models (incl. `heemod`),
  patient-level simulation, calibration.

## Boundaries with the neighbouring skills

- **nice-economic-evaluation** owns the *process*: reference case, perspective, discount rates,
  severity modifier, thresholds as policy. This skill owns the *estimation machinery* that any
  such process consumes. A question like "is my CEAC acceptable for NICE?" uses both.
- **trial-based-cea-hta** owns everything upstream of the draws when the data are individual
  patients: QALY construction, joint cost/effect models, structural values, missing economic
  outcomes, and summarising to arm-level posterior means. It hands this skill an `S × T` matrix of
  cost draws and one of effect draws, paired row-wise. **brms-modelling** owns the underlying
  regression machinery (families, priors, diagnostics, `loo`). This skill picks up at
  `as_draws`/posterior output and does no fitting.
- **decision-modelling-hta / multistate-models-hta / discrete-event-simulation-hta** own
  building the model structures; **survival-analysis-hta** owns the parametric time-to-event
  inputs and their extrapolation; **network-meta-analysis-hta** /
  **population-adjusted-comparisons** own the relative-effect synthesis feeding the model. This
  skill consumes their outputs as PSA draws.
- **missing-data-mice** owns imputation; the only rule imported here is that PSA draws must pair
  within imputation before pooling across them.
