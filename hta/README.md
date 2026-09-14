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

## Source record: Bayesian Models in HTA (Baio, 2026)

Material drawn from *Bayesian Models in Health Technology Assessment* — Gianluca Baio, CRC Press,
published 7 August 2026, online edition at <https://gianluca.statistica.it/books/online/bmhta/> — is
recorded here so a future maintainer can trace any claim back to its source.

**What was read.** All twelve chapters, the preface and the reference list, in the online edition,
**read in full on 2026-09-09**. Per-skill `Sources` blocks cite the chapter *and section* a claim
comes from, so a reader with the book open can check any of them. A claim-by-claim record of that
verification — what was confirmed, what was corrected, and what the book says that the repository
chose not to adopt — is in
[`docs/reviews/bmhta-book-verification-2026-09.md`](../docs/reviews/bmhta-book-verification-2026-09.md).

The MIT-licensed companion code repository <https://github.com/giabaio/bmhta-examples>, **pinned at
commit `d2a629845f15c56526c83433930d073b87ce2253` (2026-08-07)**, remains cited where code was
adapted from it. Code was adapted, not copied.

**Package signatures are a separate question from the statistics.** The signatures here match the
book's printed code, which was current at publication. Of the packages involved, only `brms`
(2.23.0), `flexsurv`, `loo` and `mice` were installed in the verifying environment; `BCEA`, `voi`,
`survHE`, `survextrap`, `multinma` and `heemod` were not, so their argument names have **not** been
checked against current CRAN — check them against your installed version before relying on one.

**Where the book contradicts itself, the repository says so and states the version that is correct.**
There are two such places, both flagged at the point of use: the `sigma_c`/`rho` reconstruction in
§5.2.2 (whose printed output changes the sign of the correlation), and the relative-risk rescaling in
§9.2.3 (whose code and whose Eq 9.10 disagree in the final term).

### Chapter ownership map

The book is in three parts: **I Preliminaries** (1-4), **II Statistical modelling in HTA** (5-9) and
**III Further modelling** (10-12). Part III is different in kind — by the author's own account it
"focus[es] more on the description of the underlying methodologies and less on giving code and
examples", deferring detail to Gabrio et al. (2025), Phillippo et al. (2025) and Heath et al. (2024).
That is why chapters 10-12 contribute framing and single worked examples rather than ported
workflows. The book also deliberately omits decision trees and DES, pointing to *R for HTA* — so the
repository's skills for those are correctly not BMHTA-sourced.

| Ch. | Topic | Owner | What changed |
| --- | --- | --- | --- |
| 1 | Bayesian reasoning | `brms-modelling` | No change — prior predictive checks, weakly-informative priors and diagnostics already covered, with more current thresholds. Confirmed by reading the chapter |
| 2 | Bayesian computation | `brms-modelling` | PC-prior calibration for scale parameters (§2.2.3, Ex 2.5 — the repo's worked `Exponential(4.61)` is the book's own). Centring to break intercept/slope correlation (§2.3.2) |
| 3 | Bayesian software (JAGS/BUGS) | — | **Deliberately not ported.** No JAGS tutorial. The zero-trick and BUGS-vs-JAGS defaults solve problems this stack does not have; narrow translation notes sit where a maintainer of a legacy model would trip |
| 4 | Introduction to HTA | `bayesian-cea-r-hta` | `ceef.plot()` and the CEAF-vs-CEEF distinction; the rest was already covered in equal or greater depth |
| 5 | Individual-level data | **`trial-based-cea-hta` (new)** | New skill — the unowned middle between regression fitting and decision analysis |
| 6 | Aggregate data and evidence synthesis | `network-meta-analysis-hta`, `brms-modelling` | **No new evidence-synthesis skill** (see below). New `baseline-and-absolute-effects.md`; heterogeneity-prior guidance and prediction intervals in brms. **This is also where the `Gamma(0.001, 0.001)` precision-prior warning comes from** (§6.2.5, Note 6.3), along with the parallel warning against `Uniform(0, K)` |
| 7 | Network meta-analysis | `network-meta-analysis-hta` | Preserving the joint posterior across treatments; heterogeneity prior choice; the link to absolute effects |
| 8 | Survival analysis | `survival-analysis-hta` | New `bayesian-survival.md` — survHE HMC, posterior survival bands, `survextrap` M-splines and external-data anchoring. §8.5.3 (NMA for survival data) was left with `network-meta-analysis-hta`, which already covers it |
| 9 | Markov models | `decision-modelling-hta` | New `bayesian-transition-parameters.md` from §9.2 — Multinomial-Dirichlet transitions, applying a relative risk safely, per-draw propagation. §9.3 (three-state cancer model, partitioned survival) was left with `survival-analysis-hta`, `multistate-models-hta` and the TSD 19 reference, which already cover it |
| 10 | Missing data and structural values | `trial-based-cea-hta`, `missing-data-mice` | Split: economic-outcome distributional and missingness content to the new skill; the full-Bayes-vs-MI routing rule and point-mass guidance to mice. Part III, so the chapter gives the framing and the MenSS example and defers the workflow to Gabrio et al. (2025) |
| 11 | Population adjustment | `population-adjusted-comparisons` | QMC integration explained so its diagnostic is actionable; MIM/`outstandR` named as prose |
| 12 | Value of information | `bayesian-cea-r-hta` | `value-of-information.md` expanded — opportunity loss, GAM/GP/BART, Info Rank, EVSI across sizes, ENBS-based sample size |

### Deliberate deviations from the book

- **brms, not JAGS.** The book implements almost everything in JAGS via `R2jags`. This repository
  states the same models in brms, which expresses all of them natively — including the hurdle and
  zero-one-inflated families Chapter 10 hand-rolls, `mi()` for the missingness Chapter 5 deletes, and
  `posterior_epred()` for the g-computation Chapter 5 hand-codes. The statistics are the book's; the
  implementation is not. Higher-level tooling already chosen here (`multinma`, `flexsurv`/`survHE`,
  `heemod`) is likewise retained.
- **LOO, not DIC, as the default.** A smaller deviation than it looks: the book's workflow is
  DIC-centred because JAGS reports it, but §5.3.4 presents WAIC and LOO-CV via the `loo` package as
  the "more modern" measures and works them through (Ex 5.7). DIC is documented here where a
  package's own workflow supplies it (survHE, multinma) or where a legacy submission must be read,
  including the `pD`-vs-`pV` distinction and the fact that `R2jags` before v0.8-9 printed `pV` under
  the label `pD`. It is not adopted as a repository-wide recommendation, and no DIC section was added
  to `brms-modelling`.
- **Current diagnostic thresholds retained.** The repository keeps Rhat < 1.01 with separate bulk and
  tail ESS. The book's Rhat rule of thumb is the older 1.1 (§2.3.2.1, applied throughout Ch. 5), so
  the repository is stricter there. It is **not** stricter on effective sample size: the book's only
  ESS guidance is Raftery & Lewis' "typically need ESS > 4000" (§2.3.2), which is a higher bar than
  most applied work clears. On thinning the book is not far from this repository either — it
  describes thinning as a way to keep a sample manageable while noting that running longer "is what
  makes the actual difference" — so this stack simply has less need of it.
- **No chapter mirroring.** Chapters were mapped to owners, not reproduced. **Two chapters — 1 and
  3 — produced no new content at all**, and both rulings were re-checked against the chapters
  themselves (see below). Chapters 2, 4, 7, 11 and 12 produced additions to existing files rather
  than new ones.

### The Chapter 1 and Chapter 3 rulings

Both were made before the chapters could be read, and both survive reading them.

**Chapter 1** covers the likelihood, the impact of the prior, encoding contextual information,
natural- vs original-scale parameters, Monte Carlo and forward sampling — all owned by
`brms-modelling`, and nothing in it is HTA-specific.

**Chapter 3** is software mechanics for a BUGS/JAGS stack: running JAGS from R, BUGS-vs-JAGS
differences, and the zero-trick for non-standard distributions (§3.4). The book itself closes that
section by noting that "in `Stan` there is no need to use the zero-trick" — you define the
distribution in a `functions` block, which "would generally work in a more efficient and
generalisable way" — and the preface treats the choice of engine as incidental to the statistics.
Porting it would import problems this stack does not have.

### The Chapter 6 ruling

No `evidence-synthesis-hta` skill was created. Pooling, exchangeability, shrinkage and heterogeneity
priors are `brms-modelling`'s existing territory; multi-treatment synthesis is
`network-meta-analysis-hta`'s. A third skill would compete with both for every trigger word
("meta-analysis", "evidence synthesis", "pooling", "heterogeneity") and degrade routing for all
three. What was genuinely unowned is narrower — where a decision model's *baseline* comes from, how
it combines with pooled relative effects, and multiparameter evidence synthesis — and that is a
reference file under the skill whose `SKILL.md` already claimed the step in one unexplained clause.

Reading the chapter supports the ruling. §6.2 is a meta-analysis tutorial (no / complete / partial
pooling, exchangeability, shrinkage, heterogeneity priors) — `brms-modelling`'s territory. §6.3 is
the part that was unowned: the influenza example draws its relative effect from six head-to-head
trials and its baseline from nine *separate* placebo-arm studies, then combines them as
`logit(p2) = logit(p1) + log(OR)`, and discusses when the two evidence streams could instead be
modelled as exchangeable with each other. That is exactly the content of
`baseline-and-absolute-effects.md`.
