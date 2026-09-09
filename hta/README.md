# HTA skills

Health technology assessment and health economic evaluation in R. Fourteen skills, each owning one
identifiable job in the analytic pipeline an HTA analyst walks:

| Stage | Skill |
| --- | --- |
| Process, reference case, submission requirements | `nice-economic-evaluation`, `ispor-smdm-good-practices` |
| Evidence synthesis of relative effects, and the baseline they apply to | `network-meta-analysis-hta`, `population-adjusted-comparisons` |
| Time-to-event inputs and extrapolation | `survival-analysis-hta` |
| Model structure | `decision-modelling-hta`, `multistate-models-hta`, `hesim-ctstm-hta`, `discrete-event-simulation-hta` |
| Patient-level trial data to paired cost/effect draws | `trial-based-cea-hta` |
| Draws to decision quantities and value of information | `bayesian-cea-r-hta` |
| Costing inputs | `hrg4-costing-grouper` |
| Delivery and reporting | `shiny-hta`, `cheers-2022-reporting` |

Statistical machinery these skills depend on but do not own lives in `biostatistics/` —
`brms-modelling` for Bayesian regression, `missing-data-mice` for imputation,
`causal-inference-gmethods` for identification from observational data.

## Source record: Bayesian Modelling in HTA (Baio, 2026)

Material drawn from *Bayesian Modelling in Health Technology Assessment* — Gianluca Baio, Chapman &
Hall/CRC, 2026 (<https://gianluca.statistica.it/books/bmhta/>) is recorded here so a future
maintainer can trace any claim back to its source.

**What was actually read.** The book's own text was not reachable from the authoring environment
(the publisher's site is outside the egress policy), and neither was CRAN. The accessible
authoritative source was the MIT-licensed companion code repository
<https://github.com/giabaio/bmhta-examples>, **pinned at commit `d2a629845f15c56526c83433930d073b87ce2253`
(2026-08-07)**, whose twelve chapter folders each carry an annotated `.R` script and a `README.md`
describing the code's statistical intent. Per-skill `Sources` blocks cite that commit and the chapter
they draw on. Package signatures taken from that code are stated as *observed in working code at that
commit*, not as verified against current CRAN — check them against the installed version before
relying on an argument name.

Code was adapted, not copied. Where the companion code and its own stated formula disagree, the
repository states the mathematically correct version and says so.

### Chapter ownership map

| Ch. | Topic | Owner | What changed |
| --- | --- | --- | --- |
| 1 | Bayesian reasoning | `brms-modelling` | No change — prior predictive checks, weakly-informative priors and diagnostics already covered, with more current thresholds |
| 2 | Bayesian computation | `brms-modelling` | PC-prior calibration for scale parameters; warning against the BUGS `Gamma(0.001, 0.001)` precision prior |
| 3 | Bayesian software (JAGS/BUGS) | — | **Deliberately not ported.** No JAGS tutorial. The zero-trick and BUGS-vs-JAGS defaults solve problems this stack does not have; narrow translation notes sit where a maintainer of a legacy model would trip |
| 4 | Introduction to HTA | `bayesian-cea-r-hta` | `ceef.plot()` and the CEAF-vs-CEEF distinction; the rest was already covered in equal or greater depth |
| 5 | Individual-level data | **`trial-based-cea-hta` (new)** | New skill — the unowned middle between regression fitting and decision analysis |
| 6 | Aggregate data and evidence synthesis | `network-meta-analysis-hta`, `brms-modelling` | **No new evidence-synthesis skill** (see below). New `baseline-and-absolute-effects.md`; heterogeneity-prior calibration and prediction intervals in brms |
| 7 | Network meta-analysis | `network-meta-analysis-hta` | Preserving the joint posterior across treatments; heterogeneity prior choice; the link to absolute effects |
| 8 | Survival analysis | `survival-analysis-hta` | New `bayesian-survival.md` — survHE HMC, posterior survival bands, `survextrap` M-splines and external-data anchoring |
| 9 | Markov models | `decision-modelling-hta` | New `bayesian-transition-parameters.md` — Multinomial-Dirichlet transitions, applying a relative risk safely, per-draw propagation |
| 10 | Missing data and structural values | `trial-based-cea-hta`, `missing-data-mice` | Split: economic-outcome distributional and missingness content to the new skill; the full-Bayes-vs-MI routing rule and point-mass guidance to mice |
| 11 | Population adjustment | `population-adjusted-comparisons` | QMC integration explained so its diagnostic is actionable; MIM/`outstandR` named as prose |
| 12 | Value of information | `bayesian-cea-r-hta` | `value-of-information.md` expanded — opportunity loss, GAM/GP/BART, Info Rank, EVSI across sizes, ENBS-based sample size |

### Deliberate deviations from the book

- **brms, not JAGS.** The book implements almost everything in JAGS via `R2jags`. This repository
  states the same models in brms, which expresses all of them natively — including the hurdle and
  zero-one-inflated families Chapter 10 hand-rolls, `mi()` for the missingness Chapter 5 deletes, and
  `posterior_epred()` for the g-computation Chapter 5 hand-codes. The statistics are the book's; the
  implementation is not. Higher-level tooling already chosen here (`multinma`, `flexsurv`/`survHE`,
  `heemod`) is likewise retained.
- **LOO, not DIC, as the default.** DIC is documented where a package's own workflow supplies it
  (survHE, multinma) or where a legacy submission must be read, including the `pD`-vs-`pV` distinction.
  It is not adopted as a repository-wide recommendation, and no DIC section was added to
  `brms-modelling`.
- **Current diagnostic thresholds retained.** The repository keeps Rhat < 1.01 with separate bulk and
  tail ESS, rather than the source's Rhat > 1.1 and `n.eff` < 400, and does not carry thinning across
  as advice for an HMC stack.
- **No chapter mirroring.** Chapters were mapped to owners, not reproduced. Three chapters produced no
  new file at all.

### The Chapter 6 ruling

No `evidence-synthesis-hta` skill was created. Pooling, exchangeability, shrinkage and heterogeneity
priors are `brms-modelling`'s existing territory; multi-treatment synthesis is
`network-meta-analysis-hta`'s. A third skill would compete with both for every trigger word
("meta-analysis", "evidence synthesis", "pooling", "heterogeneity") and degrade routing for all
three. What was genuinely unowned is narrower — where a decision model's *baseline* comes from, how
it combines with pooled relative effects, and multiparameter evidence synthesis — and that is a
reference file under the skill whose `SKILL.md` already claimed the step in one unexplained clause.
