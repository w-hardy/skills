# BMHTA source verification — reading the book against the PR (September 2026)

Claim-level verification of the material added by the "Incorporate Bayesian Models in HTA" work
(issue #17) against the **full text** of its source, performed 2026-09-09.

## Why this document exists

The original work was done without access to the book. Its own source record said so: the
publisher's site was outside the authoring environment's egress policy, so every methodological
claim was reverse-engineered from the twelve annotated `.R` scripts and chapter READMEs in the
companion repository. That is a reasonable way to work when it is the only way available, and it got
a surprising amount exactly right — but it left a repository of claims attributed to a book nobody
had read.

The online edition later became available locally. All twelve chapters, the preface and the
reference list were read in full, and every claim the repository attributes to the book was checked
against the section it came from. This document records the result so the next maintainer does not
have to repeat it.

## Sources

| Source | Version/date | Reference | Verified |
|---|---|---|---|
| *Bayesian Models in Health Technology Assessment* — Gianluca Baio | published 7 August 2026 | <https://gianluca.statistica.it/books/online/bmhta/> | all 12 chapters + preface + references, 2026-09-09 |
| Companion code — `giabaio/bmhta-examples` (MIT) | commit `d2a6298` (2026-08-07) | <https://github.com/giabaio/bmhta-examples> | cited where code was adapted; not re-inspected in this pass |
| `brms` | 2.23.0 | installed locally | `set_rescor()` family restriction and `zoi`/`coi`/`hu` parameter names executed and confirmed, 2026-09-09 |
| `flexsurv` 2.3.2, `loo` 2.10.1, `mice` 3.19.0 | installed locally | — | available for checking, 2026-09-09 |
| `BCEA`, `voi`, `survHE`, `survextrap`, `multinma`, `heemod` | — | — | **not installed**; signatures remain as printed in the book and are flagged as such |

**Bibliographic correction.** The book is titled *Bayesian **Models** in Health Technology
Assessment*, not *Bayesian Modelling in…*, and the readable edition is at `/books/online/bmhta/`.
Both were wrong in every file that cited it (nine files) and have been corrected. The publisher is
CRC Press — stated in the preface's acknowledgements rather than on the title page.

## What the verification found

Roughly 120 attributed claims were checked. The large majority were confirmed, several precisely
enough to be striking — the PC-prior rates (5.75 and 0.35), the Generalised F priors, the DIC
difference bands, the `hsd ~ Gamma(2,1)` smoothing prior, the structural-values mixture formula, and
the chemotherapy sample-size comparison were all exactly right despite having been inferred from
code alone. What follows is only what changed.

### Corrections applied

| # | Where | Was | Is |
|---|---|---|---|
| 1 | `trial-based-cea-hta/references/missing-economic-outcomes.md` | Multiple imputation described as "Bayesian in spirit", in quotation marks, attributed to the book | **The phrase does not occur anywhere in the book.** Replaced with its actual framing of Rubin's design (§10.3.1) as thinking like a Bayesian and doing as a frequentist — a compromise it says is no longer necessary |
| 2 | `trial-based-cea-hta/references/model-comparison-and-handoff.md` | A linear transformation of the outcome adds a constant Jacobian term, so flipped-scale and raw-scale models are not comparable | **Backwards.** Note 5.2 proves the reflection `e* = 3 − e` leaves a Normal deviance unchanged, and compares the models on that basis. The Jacobian problem belongs to the *multiplicative* £1,000 cost rescaling in the Gamma model, which shifts the deviance by `2n·log(kappa)` = 2307.19 for these data |
| 3 | `bayesian-cea-r-hta/references/bcea-package.md` | CEAF is "the upper envelope of the per-strategy acceptability curves" | **Not the envelope.** §4.3.3 (Fenwick et al. 2001): at each threshold it is the acceptability of the strategy with the highest *expected* net benefit, which need not be the most probable one. `psa-and-summaries.md` had it right; the two files now agree |
| 4 | `hta/README.md` | The `Gamma(0.001, 0.001)` precision-prior warning attributed to Ch. 2 | It is Ch. 6 (§6.2.5 and Note 6.3, after Gelman 2006). PC priors *are* Ch. 2 (§2.2.3, Ex 2.5). The reference file that said Ch. 6 was right and the map was wrong |
| 5 | `hta/README.md` | "the source's Rhat > 1.1 and `n.eff` < 400" | Rhat 1.1 is correct. **The ESS figure is not the book's**: its only ESS guidance is Raftery & Lewis' ESS > 4000 (§2.3.2) — a *higher* bar than this repository's, so half the "we keep more current thresholds" claim was unfounded |
| 6 | `hta/README.md` | "Three chapters produced no new file at all" | Two (1 and 3). Chapters 2, 4, 7, 11 and 12 produced additions to existing files |
| 7 | `trial-based-cea-hta/references/joint-cost-effect-models.md` | The `beta1`/`beta2` slip attributed to the companion script | The slip is **in the book**, §5.2.2, and its consequence is visible in the book's own printed output: the correlation changes sign between the two routes (−0.186 vs +0.157) while the text states they agree |
| 8 | `decision-modelling-hta/references/bayesian-transition-parameters.md` | The `RR` / `1 − RR` discrepancy attributed to the companion script | Also **in the book**: Eq 9.10 states `1 − RR·lambda`, the §9.2.3 code computes `1 − lambda(1 − RR)`. The equation is the correct one |
| 9 | `trial-based-cea-hta/references/population-average-summaries.md` | Said the Gamma model "has no covariates other than treatment" and then that it conditions on baseline utility | Self-contradictory. The covariate is there — which is why neither the direct read-off nor the book's own predictive step marginalises over it |
| 10 | `trial-based-cea-hta/references/missing-economic-outcomes.md` | MenSS analysed "under MAR" | MAR for the effects, **MNAR for the costs** (§10.4.1) |
| 11 | `model-comparison-and-handoff.md` | `pD` = the BUGS definition, obtained by `pD = TRUE` | Two different quantities: Eq 5.14 is Spiegelhalter's; `rjags::dic.samples()` implements Plummer's (2008) variant. Also added: `R2jags` before v0.8-9 printed `pV` labelled as `pD` |
| 12 | Eight files | Book-derived content with no citation at all | `Sources` lines added to `core-workflow.md`, `meta-analysis.md`, `distributional.md`, `ml-nmr-multinma.md`, `multinma-bayesian.md`, `heemod-markov-models.md`, `population-adjusted-comparisons/SKILL.md` and `causal-inference-gmethods/SKILL.md` |

### Material added because the book has it and the repository did not

- **survHE priors are changeable, not just inspectable** (§8.4.1): the `priors` argument, and
  `save.stan = TRUE` for changing a prior's family — after which the model must run through `rstan`.
- **`survextrap` holds the hazard constant beyond the final boundary knot** (§8.5.1). This is the
  assumption that governs the whole extrapolation region, and it makes `add_knots` a modelling
  decision rather than a technicality.
- **A failed RR rescaling is a transportability finding, not a numerical one** (§9.2.2, Eq 9.9): it
  says the pooled RR's source populations are not exchangeable with the local baseline.
- **With missing data, likelihood-based information criteria do not fully apply** (§10.1) — a
  stronger statement than the "check `nobs()`" advice that was there.
- **The book's own MNAR route is a selection model** with an informative prior on the missingness
  coefficient (§10.3.2), beside the pattern-mixture grid the repository recommends.
- Smaller additions: the shape-parameter PC prior (§5.2.1), `Uniform(0, K)` as a second prior to
  avoid (§6.2.5), Gelman & Hill's three-group rule, the baseline-risk adjustment as Cooper et al.
  actually fit it (Welton et al. 2012), the structural-indicator covariates in the MenSS hurdle
  model, and the ENBS money figures behind the 190-vs-450 comparison.

### Deliberate deviations, restated with sections

Each survives the reading; what changed is that the justification is now citable.

- **brms, not JAGS.** Confirmed by the preface: the book runs JAGS/OpenBUGS via `R2jags` throughout,
  with Ch. 8 (HMC via `survHE`/`survextrap`) the stated exception. It also treats the choice of
  engine as incidental — software is "a proxy for the technical sophistication of the modeller".
- **LOO over DIC.** A smaller gap than claimed: §5.3.4 already presents WAIC and LOO-CV via `loo` as
  the more modern criteria and works them through.
- **Rhat/ESS.** See correction 5 — stricter on Rhat, *not* stricter on ESS.
- **Chapter 3 not ported.** §3.4 itself notes Stan has no need of the zero-trick.

## Architectural rulings, re-examined with the book in hand

| Ruling | Verdict |
|---|---|
| No `evidence-synthesis-hta` skill (Ch. 6) | **Stands, now evidenced.** §6.2 is a meta-analysis tutorial (`brms-modelling`'s territory); §6.3 is the genuinely unowned part — baseline sourcing and combination — and is what `baseline-and-absolute-effects.md` covers |
| Chapter 3 not ported | **Stands**, with the book's own remark about Stan and the zero-trick |
| Chapter 1 needed nothing | **Stands** — likelihood, priors, Monte Carlo, forward sampling, all owned by `brms-modelling` |
| `trial-based-cea-hta` built from Ch. 5 + Ch. 10 | **Stands, with a caveat now stated in the skill.** Ch. 5 is Part II and is a full worked chapter; Ch. 10 is Part III, lighter by design, and defers the missing-data workflow to Gabrio et al. (2025). The skill's Sources block now says so rather than presenting the two as equivalent |
| Ch. 9 mapped only to Bayesian transition parameters | **Amended.** §9.3 (three-state cancer model, partitioned survival) is half the chapter; it is already covered by `survival-analysis-hta`, `multistate-models-hta` and the TSD 19 reference, so nothing was added — but the map now records the decision instead of leaving the gap silent. Same for §8.5.3 (survival NMA) |

## Standing caveats

- **Package signatures for the six uninstalled packages** (`BCEA`, `voi`, `survHE`, `survextrap`,
  `multinma`, `heemod`) match the book's printed code and have not been checked against current
  CRAN. The highest-risk of these are `survextrap::mspline_spec()`'s arguments, `voi`'s EVPPI method
  strings, and `BCEA::createInputs()` — the last of which is not in Ch. 12 at all and is sourced to
  BCEA's own documentation.
- **`voi`'s GAM implementation.** §12.4.2 states it is built on `earth` (a frequentist MARS fit).
  Check the installed package's method strings before restating them as API.
- No book prose is reproduced in this repository beyond short attributed phrases; the extracted text
  used for this verification was kept outside the repository.
