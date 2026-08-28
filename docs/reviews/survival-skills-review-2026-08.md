# Survival-modelling skills — technical review and remediation (August 2026)

Comprehensive claim-level review and remediation of the survival/time-to-event modelling
skills in this repository, performed 2026-08-27 by a multi-agent process: five independent
specialist reviews (inventory/consistency, NICE/HTA methodology, statistical methodology,
R/package API with executable verification, and skill design per the Skill Creator
methodology), orchestrator adjudication, three bounded remediation agents, and an
independent adversarial verification of the final state. Nothing in this review was
committed or pushed by the review process itself.

## Scope

**Detailed (claim-level) review:**

- `hta/survival-analysis-hta/SKILL.md`
- `hta/survival-analysis-hta/references/flexsurv-fitting.md`
- `hta/survival-analysis-hta/references/advanced-survival-models.md`
- `hta/survival-analysis-hta/references/km-reconstruction.md`
- `hta/survival-analysis-hta/references/survival-to-economic-model.md`
- `hta/survival-analysis-hta/scripts/check_survival_fit.R`
- `hta/nice-economic-evaluation/references/tsd-methods/survival-extrapolation-tsd14-21.md`
- `hta/nice-economic-evaluation/scripts/survival_extrapolation.R`
- `biostatistics/brms-modelling/references/model-families/survival.md`

**Consistency review only** (consume survival outputs or repeat survival guidance; 22 files):
`hta/multistate-models-hta/*`, `hta/hesim-ctstm-hta/*`, `hta/decision-modelling-hta/*`,
`hta/ispor-smdm-good-practices/*` (survival-adjacent references), `hta/discrete-event-simulation-hta/*`,
`hta/bayesian-cea-r-hta/*`, `hta/network-meta-analysis-hta/*`, the remaining
`hta/nice-economic-evaluation` references (`modelling-and-uncertainty.md`, `tsd-index.md`,
`mapping-itc-psm-tsd22-18-19.md`, `treatment-switching-tsd24.md`, …), and the remaining
`biostatistics/brms-modelling` files. Cross-file formulas were checked for agreement
(transition probabilities, rate↔probability conversions, PSA correlation guidance) and found
consistent; only two files in this tier were edited (single cross-reference lines each).

**Out of scope:** files with incidental mentions only (e.g. `superpowers/*`,
`biostatistics/clinical-prediction-models`), and non-survival content of the skills above.

## Sources

| Source | Version/date | Reference | Accessed |
|---|---|---|---|
| NICE health technology evaluations manual (PMG36), §4.2.24 and ch. 4 | current online edition | https://www.nice.org.uk/process/pmg36 | 2026-08-27 |
| NICE DSU TSD 14 (Latimer) — survival analysis for economic evaluations | June 2011 | https://sheffield.ac.uk/nice-dsu/tsds/survival-analysis | 2026-08-27 |
| NICE DSU TSD 21 (Rutherford et al.) — flexible methods for survival analysis | 23 January 2020 | https://sheffield.ac.uk/nice-dsu/tsds/flexible-methods-survival-analysis | 2026-08-27; full PDF verified 2026-08-28 |
| NICE DSU TSD 19 (Woods et al.) — partitioned survival analysis | 2 June 2017 | https://sheffield.ac.uk/nice-dsu/tsds/partitioned-survival-analysis | full PDF verified 2026-08-28 |
| NICE DSU TSD 26 — expert elicitation for long-term survival outcomes | March 2025 | https://sheffield.ac.uk/nice-dsu/tsds/expert-elicitation-tsd | 2026-08-27 |
| NICE DSU TSD full list | current | https://sheffield.ac.uk/nice-dsu/tsds/full-list | 2026-08-27 |
| `flexsurv` (Jackson) — docs, Distributions vignette, source | 2.3.2 (CRAN-current) | https://cran.r-project.org/package=flexsurv | 2026-08-27, executed locally |
| `flexsurvcure` (Amdahl) — docs, README | 1.1.0 | https://cran.r-project.org/package=flexsurvcure | 2026-08-27, executed locally |
| `survHE` (Baio) — docs, source (giabaio/survHE) | 2.0.51 (2026-01-15) | https://cran.r-project.org/package=survHE | 2026-08-27, executed locally |
| `brms` (Bürkner) — families, `?brmsformula`, source | 2.20.4 | https://cran.r-project.org/package=brms | 2026-08-27, executed locally |
| Guyot et al., BMC Med Res Methodol 12:9 — KM reconstruction | 2012 | https://link.springer.com/article/10.1186/1471-2288-12-9 | 2026-08-27; full PDF verified 2026-08-28 |
| Guyot et al., Med Decis Making 37:353-366 — extrapolation with external information | 2017 | https://journals.sagepub.com/doi/10.1177/0272989X16670604 | full PDF verified 2026-08-28 |
| Latimer, Med Decis Making 33:743-754 — survival model selection process | 2013 | https://journals.sagepub.com/doi/10.1177/0272989X12472398 | 2026-08-27; full PDF verified 2026-08-28 |
| Sweeting et al., Med Decis Making 43(6):737-748 — GPM incorporation (excess hazard/cure) | 2023 | https://journals.sagepub.com/doi/10.1177/0272989X231184247 | 2026-08-27; full PDF verified 2026-08-28 |
| *R for HTA* (Baio et al.), ch. 7 — survival analysis in HTA | online edition | https://gianluca.statistica.it/books/online/r-hta/ | saved copy verified 2026-08-28 |
| Supporting literature on waning/marginal-vs-conditional effects, RMST under NPH | 2019–2025 | see `scratchpad` review matrices | 2026-08-27 |

Evidence caveat: the session's egress proxy blocked direct fetches of `nice.org.uk`,
`sheffield.ac.uk` and journal domains (403), so the 2026-08-27 review rested on
search-engine-retrieved page text for those sources. On 2026-08-28 the repository owner
supplied full copies of TSD 19, TSD 21, Sweeting 2023, Latimer 2013, Guyot 2012, Guyot 2017
and R-HTA chapter 7, and every claim resting on those sources was re-verified against the
documents themselves (see "Post-review source verification" below). Still search-verified
only: the exact wording of PMG36 (including 4.2.24) and TSD 26 — re-check against the live
documents before quoting them in a submission. Package/API claims never shared this caveat —
they were verified by executing the installed packages.

## Findings

Severity: **Critical** = could materially cause an incorrect analysis/model; **High** =
substantively misleading/outdated; **Medium** = important qualification/API weakness;
**Low** = clarity/robustness. Status: all listed findings **Resolved** unless stated.

| Sev | Location (pre-fix) | Issue | Evidence | Resolution |
|---|---|---|---|---|
| Crit | survival-analysis-hta SKILL.md:40; advanced-survival-models.md:41 | Mixture-cure survivor function given as `S(t)=1-(1-θ)S₀(t)`, which has S(0)=θ and increases to 1 | Derivation + simulation (θ=0.3 → S(0)=0.300, S(∞)=1) | Corrected to `S(t)=θ+(1-θ)S₀(t)` in both files; verified plateau S(∞)=θ empirically |
| Crit | survival-to-economic-model.md:70-72 | PSA back-transform advice "shape/rate are exp() of the log-scale parameters for Gompertz"; flexsurv estimates Gompertz shape on the identity scale (legitimately negative) | `fit$dlist$transforms` inspection; negative-shape fit: correct draws give 40-y RMST 32.0y, blanket `exp()` gives 3.55y | Section rewritten: `normboot.flexsurvreg()` / `summary(fit, B=)` primary; manual route must use per-parameter `fit$dlist$inv.transforms`; covariate-row misalignment warned |
| Crit | SKILL.md:16,58; survival-to-economic-model.md:40-49 | `survHE::markov_trace()` described as running a Markov trace from `make.transition.probs()` output; in fact `markov_trace(make.transition.probs(fits))` errors — `markov_trace()` plots the trace produced by `three_state_mm()` (fixed 3-state illness-death, three fits) | Executed end-to-end against survHE 2.0.51 | All three passages rewritten to the verified chain |
| Crit | brms-modelling references/model-families/survival.md:10 | Nonexistent `gengamma()` brms family presented as available | `brmsfamily("gengamma")` errors in brms 2.20.4 | Removed; real families listed; note added that brms lacks gengamma/Gompertz/log-logistic (3 of the NICE six) with hand-off to flexsurv/survHE |
| Crit | check_survival_fit.R (whole script) | `<<-` inside `tryCatch` wrote checks' results to the global environment: the hazard-validity, RMST and horizon checks were silently discarded (script always ended "No blocking problems found") | Reproduced empirically | Script rewritten (local state environment); every check now demonstrably reaches the report; self-test gate added |
| Crit | tsd14-21.md:25-27; survival_extrapolation.R:99-113 | Background-mortality floor misattributed to TSD 14 and presented as "the process NICE expects"; TSD 14 uses GPM as an external-validity comparator — the incorporation recommendation is TSD 21, whose preferred mechanism is internal additive excess-hazard (relative survival), not a post-hoc cap; PMG36 itself is silent | TSD 14/21 content (search-retrieved); Sweeting 2023 | Step rewritten: both mechanisms presented with correct attribution, matching caveats (age/sex/calendar-year, healthier-cohort, all-cause-OS-only, incremental-effect check), discontinuity caveat, one-mechanism-only rule; inverted "cap the hazard" phrasing fixed |
| Crit | tsd14-21.md:30 | PMG36 4.2.24 "no continued benefit" glossed as "curves converge after treatment stops"; the clause means benefit stops accruing (equal hazards after cutoff, accrued benefit retained — curves do **not** converge). Prose contradicted the repo's own correct helper | PMG36 4.2.24 text; independent confirmation by two reviewers | Corrected; scenario taxonomy added (step-change / gradual HR→1 waning / loss of accrued benefit) with marginal-vs-conditional caveat |
| High | check_survival_fit.R:44-65 | SE/\|estimate\| ratio as identifiability diagnostic: unit-dependent, false-flags parameters legitimately near zero (Weibull shape≈1 → flagged at ratio 3.6; well-identified Gompertz shape≈0 flagged at 131×; ~38% of true-null covariates) while passing genuinely unidentified fits | Reproduced empirically | Removed; replaced with convergence code, finite est/SE, covariance validity (PD, \|ρ\|>0.99, condition number), prediction validity (0≤S≤1 non-increasing, h≥0 finite), defective-tail report, RMST+CI, optional background-hazard comparison |
| High | tsd14-21.md | TSD 26 (structured expert elicitation for long-term survival, March 2025) absent although present in the repo's own tsd-index.md | DSU site | Dedicated section added |
| High | tsd14-21.md:8 | "The TSD 14 process (the one NICE expects to see)" collapses DSU recommendation vs PMG36 requirement | PMG36 / TSD 14 | Reframed with correct provenance |
| High | SKILL.md:69 | survreg↔flexsurv Weibull mapping garbled ("flexsurv's scale is 1/shape of survreg") | Empirical fit comparison | Corrected: flexsurv shape = 1/survreg scale (σ); flexsurv scale = exp(survreg intercept) |
| High | SKILL.md:72 | Implied a constant HR is recoverable from any AFT fit by delta method | Only Weibull/exponential are simultaneously AFT and PH (log HR = −shape·β) | Corrected; `hr_flexsurvreg()` recommended for inherently time-varying cases |
| High | advanced-survival-models.md:43-53 | Cure-model worked examples used `dist="gengamma"`, which flexsurvcure's README flags as unreliable; Hessian-not-positive-definite failures reproduced with gengamma and gompertz bases | flexsurvcure 1.1.0 README + reproduction | Examples switched to a weibull base (executed successfully); explicit convergence warning added |
| High | advanced-survival-models.md:75-84 | `bhazard` fits: predictions are relative—not all-cause—survival, and AIC is not comparable with all-cause fits; both unstated, breaking the skill's own compare-the-set workflow | flexsurv docs/likelihood structure | Both caveats added |
| High | survival-to-economic-model.md:9-17 | Transition-probability formula lacked its assumptions (single modelled event; competing exits need cause-specific hazards/multistate; clock-forward vs clock-reset; S(t)→0 underflow) | Derivation | Assumptions paragraph added with hand-off to multistate-models-hta |
| High | survival-analysis-hta (whole skill) | Treatment-effect-duration scenarios and background-mortality handling entirely absent despite TSD framing | TSD 14/21, PMG36 4.2.24 | Added as bullets with cross-references to the implementing script |
| High | survival_extrapolation.R:92 | `rmst(discount=)` is per time unit while the demo runs in days — an annual rate passed naively is a ~40× error | Code inspection | Documented with conversion formula |
| High | survival_extrapolation.R | No gradual-waning scenario | PMG36 4.2.24 scenario range; TA practice | `waning_scenario()` added (linear HR→1 ≡ geometric interpolation of conditional survival; verified algebraically and by invariant tests) |
| Med | flexsurv-fitting.md table | Weibull hazard written ∝ tᵃ (should be t^{a−1}); PH/AFT lists omitted exponential/gamma and `weibullPH`; Gompertz defective-distribution (shape<0) implication unstated | flexsurv Distributions vignette | All corrected |
| Med | flexsurv-fitting.md:71-79 | PH-check guidance: non-significant cox.zph presented as settling PH | Standard theory | "Absence of evidence" sentence added (also in ph_check output and tsd file) |
| Med | km-reconstruction.md | Guyot total-events input unmentioned; no warning against reconstructing 1−CIF or switching-adjusted curves | Guyot 2012 | Both added |
| Med | survival-to-economic-model.md:26-38 | `fit$res[...]` snippet silently reads reference-level parameters on covariate models | Verified | Caveat added |
| Med | survival_extrapolation.R | Failed fits silently dropped; BIC n-vs-events ambiguity; `apply_background_floor` p_bg matching under-specified | Code inspection | `message()` on failures; comments and docstrings added |
| Med | tsd14-21.md checks list | No immature-data/at-risk-tail check; no PFS≤OS coherence check; RMST implied as required | TSD 19; EAG practice | Added / reframed |
| Med | brms survival.md:11 | `cens()` coding hedged rather than stated | `make_standata()` verification: brms `cens`: 1='right'=censored, 0='none'=event — opposite of `Surv()` status | Stated outright: use `time \| cens(1 - status)` |
| Low | several | Stale access dates, survHE "current as of 2025" (now 2.0.51, 2026-01), unstable TSD download URLs, missing cross-references between the three skills | — | Updated; reciprocal cross-references added (nice-economic-evaluation → survival-analysis-hta; decision-modelling-hta → survival-analysis-hta; brms survival.md → both HTA skills) |

### Verification-round findings (Phase 5, all resolved)

The independent verifier confirmed all seven Critical fixes above (re-deriving each, several
to machine precision) and found the following issues **introduced or left by the remediation**,
all fixed in a final orchestrator pass and re-tested:

| Sev | Location | Issue | Resolution |
|---|---|---|---|
| High | SKILL.md pitfalls; flexsurv-fitting.md | The new "log HR = −shape × AFT coefficient" rule is wrong for `dist="exp"`/`"gamma"`, whose covariates sit on log *rate* — for the exponential the coefficient already **is** the log HR (negating it reverses the effect; verified: true log HR −0.693, formula gave +0.78) | Conversion split by `fit$dlist$location`; rate-parameter convention stated |
| High | check_survival_fit.R | Per-arm output unlabelled and in two different row orders on covariate models — inviting arm mix-ups | All per-pattern messages now carry `[covariate=level]` labels from a single ordering; verified on non-alphabetical factor levels |
| Med | survival_extrapolation.R | `waning_scenario(t_start == t_stop)` — the documented step-change special case — returned NaN on a grid point (0/0); both scenario helpers propagated NaN once a curve hit exactly 0 | Degenerate-window branch + non-finite guards added; step case now reproduces `no_continued_benefit()` exactly (verified) |
| Med | flexsurv-fitting.md | New sentence "no other family has a constant HR at all" contradicted the PH list above it (Gompertz/weibullPH/hazard-scale spline have constant HRs by construction) | Reworded to AFT-fit scope |
| Med | advanced-survival-models.md | Spline extrapolated tail described as Weibull on all three scales; true only on the hazard scale (odds → log-logistic-like, normal → log-normal-like; verified numerically) | Corrected per scale |
| Med | km-reconstruction.md | New total-events bullet not actionable via `survHE::digitise()` (which has no such argument); heading still said "two inputs" | `IPDfromKM::getIPD(tot.events=)` / Guyot-code route named; heading fixed |
| Low ×12 | various | PMG36 "requires" gloss (should be "desirable"/"should include"); `res.t` rows-vs-columns; `bhazard` ignored only for *right*-censoring; `mids` misnamed; unsupported "~40×" discount figure (verified true figures used instead); "hazard discontinuity" is a kink (jump only on a discrete grid) and the Sweeting-specific attribution unverifiable; eval 1's AIC premise mathematically impossible for nested gamma/gengamma (comparator switched to log-logistic); `three_state_mm()` returns a list not a tibble; "feed it your fitted models" vs survival-vector inputs; cause-specific formula's ΔH increments made explicit; spline basis-coefficient correlations near the 0.99 threshold (contextual note added); two coverage gaps (data-cut validation, left truncation) closed with one sentence each | All fixed |

Verified correct and deliberately kept: the conditional transition-probability formula
`1−S(t+Δ)/S(t)` (exact; no within-cycle homogeneity assumption needed); the non-mixture cure
form `S(t)=θ^{F₀(t)}`; the relative-survival identities `h=h*+λ`, `S=S*·R`; the three
Royston–Parmar scales and k=0 special cases; the gengamma special-case list; the Guyot
algorithm description and its interval-censoring assumption; the joint-MVN-sampling and
downstream-correlation guidance; RMST-vs-mean framing; the brms Cox-family description
(M-splines via splines2; full likelihood; PH; not partial-likelihood coxph); `survHE`'s
companion-package architecture description; `apply_background_floor`'s and
`no_continued_benefit`'s implementations (bodies untouched — only their documentation was
corrected).

## Methodological decisions (where reasonable analysts might differ)

- **Background mortality.** Both the internal additive excess-hazard route (TSD 21's
  recommendation; `flexsurv::bhazard`) and the pragmatic post-hoc hazard floor are presented,
  with the floor explicitly labelled the cruder fallback (discontinuity caveat, Sweeting
  2023) and a rule to apply exactly one mechanism (floor / additive / SMR-based). The floor
  helper was retained because it is correctly implemented and widely used in TA practice.
- **Cure models.** Kept, with strengthened identifiability caveats; examples moved off
  gengamma bases for numerical reliability, not statistical preference. Cure fractions must
  be combined with background mortality for lifetime horizons.
- **Treatment-effect duration.** The "no further benefit" scenario is defined as equal
  hazards after a cutoff (accrued benefit retained), per PMG36 4.2.24; gradual HR→1 waning
  added as a distinct scenario; loss of accrued benefit (true curve convergence) documented
  as the more pessimistic third variant rather than implemented as a separate helper (it is
  simply the comparator curve after the cutoff). Marginal-vs-conditional approximation bias
  is flagged rather than resolved.
- **Model selection.** AIC/BIC retained as necessary-but-insufficient; extrapolated-hazard
  plausibility, external evidence and scenario ranges are required alongside. No mechanical
  selection rule was introduced.
- **Uncertainty propagation.** Package-supported sampling (`normboot.flexsurvreg`) preferred
  over hand-rolled transforms; the manual route is documented with per-parameter inverse
  transforms rather than removed, since it is legitimately needed for custom pipelines.
- **Expert elicitation.** TSD 26 presented as the DSU-recommended structured approach where
  extrapolation is weakly informed by data; informal clinician endorsement of a curve is
  explicitly not a substitute.

## Changes made

| File | Nature of change |
|---|---|
| hta/survival-analysis-hta/SKILL.md | Cure formula; survHE function descriptions; survreg mapping; AFT-HR pitfall; waning + censoring notes; validation-script contract; sources |
| hta/survival-analysis-hta/references/flexsurv-fitting.md | Hazard-shape table; PH/AFT lists; weibullPH; Gompertz defective note; PH-test nuance |
| hta/survival-analysis-hta/references/advanced-survival-models.md | Cure formula + stable-base examples + convergence warning; θ-sensitivity mechanism; spline boundary-knot tail; bhazard prediction-scale and AIC caveats; TSD 21 attribution; one-mechanism rule |
| hta/survival-analysis-hta/references/km-reconstruction.md | Total-events input; 1−CIF/switching-adjusted warning |
| hta/survival-analysis-hta/references/survival-to-economic-model.md | Transition-probability assumptions; underflow guard; survHE section rewrite; uncertainty-propagation rewrite (normboot / inv.transforms) |
| hta/survival-analysis-hta/scripts/check_survival_fit.R | Full rewrite: scoping bug fixed, defensible check battery, optional bg_hazard, self-test |
| hta/survival-analysis-hta/evals/evals.json | New: 8 evals with objective assertions (Skill Creator schema) |
| hta/nice-economic-evaluation/references/tsd-methods/survival-extrapolation-tsd14-21.md | Provenance reframing; background-mortality rewrite; waning taxonomy; TSD 26 section; TSD 21 scope; EAG-check additions; stable URLs; cross-reference |
| hta/nice-economic-evaluation/scripts/survival_extrapolation.R | Docstring corrections (floor, waning, rmst discount); `waning_scenario()`; failure reporting; extended self-testing demo |
| hta/nice-economic-evaluation/SKILL.md | One cross-reference line to survival-analysis-hta |
| hta/decision-modelling-hta/SKILL.md | One cross-reference line to survival-analysis-hta |
| biostatistics/brms-modelling/references/model-families/survival.md | gengamma removed; family list corrected; cens() coding stated; hand-off note |
| docs/reviews/survival-skills-review-2026-08.md | This report |

## Testing and validation

- R environment: R 4.x with flexsurv 2.3.2, flexsurvcure 1.1.0, survHE 2.0.51, survival
  3.5-8, brms 2.20.4, muhaz, rstpm2 (CRAN mirrors built from source; versions verified
  CRAN-current on 2026-08-27).
- `Rscript hta/survival-analysis-hta/scripts/check_survival_fit.R` — self-test suite passes
  (exit 0): clean Weibull/Gompertz fits pass; immature 12-observation gengamma fit correctly
  flagged (near-ridge correlation |ρ|≈0.999); negative-shape Gompertz produces the
  defective-tail note without a false failure; the former false-positive scenario
  (well-identified Gompertz, true shape 0, n=500) is no longer flagged; bg_hazard triggers
  correctly. Additional spot-checks: exponential, covariate models, flexsurvspline, bhazard
  fits, non-convergent fits.
- `Rscript hta/nice-economic-evaluation/scripts/survival_extrapolation.R` — full demo passes
  (exit 0), including new `stopifnot` invariants: all scenario curves start at 1, are
  non-increasing, lie in [0,1]; floored ≤ model curve; no-benefit ≤ waned ≤ active.
- Synthetic verification runs (saved in the session scratchpad): mixture-cure S(0)/S(∞)
  behaviour; Gompertz transform scales and the exp()-corruption demonstration; survHE
  `make.transition.probs`→`three_state_mm`→`markov_trace` chain; flexsurvcure weibull-base
  examples (mixture, anc, non-mixture); brms `make_standata` censoring coding; survreg↔flexsurv
  mapping; AFT/PH Weibull HR identity.
- Evals: `hta/survival-analysis-hta/evals/evals.json` — 8 evals, JSON-validated. These are
  eval *definitions* per the Skill Creator schema; the full run-and-benchmark loop
  (with-skill vs baseline subagent runs, viewer, human feedback) was not executed in this
  autonomous session and is the natural next step with a human reviewer.
- Independent verification: a fresh Opus-class reviewer re-derived the mathematics, re-ran
  both scripts, re-verified API claims empirically against the installed packages, and
  stress-tested the helpers with adversarial inputs. Verdicts: mathematics PASS, NICE claims
  PASS, evals PASS, consistency PASS, diff hygiene PASS; R-API and scripts initially FAIL on
  the two High regressions in the table above (0 Critical). Thirty substantive claims survived
  active falsification — several to machine precision (the waning hazard-interpolation
  identity to 1e−16; the Weibull AFT↔PH log-HR identity to 1e−9; the `bhazard`
  likelihood-constant reproducing the all-cause log-likelihood exactly).
- Post-fix re-testing: both scripts re-run to exit 0; multi-arm labelling verified with
  non-alphabetical factor levels; `waning_scenario` degenerate window verified identical to
  `no_continued_benefit`; zero-survival guards verified finite and monotone; evals.json
  re-validated.

## Post-review source verification (2026-08-28)

After the PR was opened, the repository owner provided full copies of seven primary sources.
Four verification agents re-checked every claim resting on them, page by page. Outcomes:

**Confirmed (no change needed):** TSD 21 recommends incorporating background mortality
(p. 89: "recommended … essential for cure models") — the review's central re-attribution
holds; TSD 21's scope list and matching qualifications; Sweeting 2023 corroborates the
bhazard-AIC-non-comparability caveat verbatim (p. 741); TSD 19 supports the PSM content and
the tier-2 `mapping-itc-psm-tsd22-18-19.md` description sentence-by-sentence; Guyot 2012
confirms the KM-reconstruction inputs, the constant-within-interval censoring assumption, and
the stated limitations; every R-HTA-attributed claim in the skill checks out against chapter
7 (the AIC values and the ~1-year RMST gap match exactly); Guyot 2017 substantiates the
external-information guidance and contradicts nothing.

**Corrections made from the documents:**

| Location | Correction | Source |
|---|---|---|
| tsd14-21.md step 3 | TSD 14's *standard* set is five distributions (exp, Weibull, Gompertz, log-normal, log-logistic); generalised gamma/F are its "more flexible" extensions to consider when the five appear unsuitable — previously presented as a standard set of six | Latimer 2013 p. 749 |
| tsd14-21.md step 5; survival_extrapolation.R docstring; advanced-survival-models.md | "TSD 21's preferred route" over-attributed: TSD 21 recommends *incorporation* but never names or compares the post-hoc floor; the internal-vs-floor comparison is now sourced to Sweeting 2023 ("more statistically coherent"; the switch "causes a discontinuity in the all-cause hazard function", p. 738) with TSD 21 quoted only for what it says | TSD 21 pp. 42, 44, 89; Sweeting 2023 p. 738 |
| advanced-survival-models.md sources | TSD 21 date corrected: 23 January 2020 (not November 2020) | TSD 21 title page |
| advanced-survival-models.md cure caveat | "per Latimer & Rutherford's guidance" replaced with TSD 21's own words ("essential for cure models") | TSD 21 p. 89 |
| km-reconstruction.md | Accuracy nuance: survival probabilities/medians reconstruct accurately even with limited information; it is *hazard ratios* that need at-risk numbers or total events and become unusable with neither | Guyot 2012 abstract, p. 6 |
| survival-to-economic-model.md PSM; tsd14-21.md EAG list | State-transition cross-check upgraded from described practice to TSD 19's formal Recommendation 11 (alongside, not replacing, PartSA) | TSD 19 p. 58 |
| advanced-survival-models.md external data | One sentence added: Guyot 2017 as the worked example of joint likelihood constraints vs post-hoc model selection | Guyot 2017 pp. 359-364 |

One tension noted, no change made: R-HTA ch. 7's own cure example uses a gengamma base
successfully on the colon data, while this skill warns that gengamma/gompertz cure bases can
fail (flexsurvcure README + reproduced Hessian failures). The warning says "can fail /
check convergence", not "always fails", so both are consistent; the stable-base default
stands.

## Remaining limitations

- TSD 19/21 and the key methodological papers have now been verified against full documents
  (see above). Still search-verified only: PMG36's exact clause wording (including 4.2.24)
  and TSD 26 — the owner attempted to supply both but the files did not reach the session;
  re-verify on receipt, and re-check verbatim quotations against the live documents before
  use in a submission.
- The eval set has not been executed against a with-skill/baseline agent pair (requires the
  Skill Creator run loop with a human in the loop).
- `count-skill-tokens.py` could not run (tiktoken download blocked); token counts were
  approximated. All three frontmatter descriptions exceed the repo's 100-token description
  guideline — as do the comparator HTA skills. Left unchanged deliberately: trimming risks
  triggering regressions that cannot be eval-tested in this session. Flagged for a future
  description-optimisation pass with Skill Creator's trigger-eval loop.
- Observations recorded for the maintainer, out of this review's scope: (1) leaked
  "EXPO"-engagement references in `hta/hesim-ctstm-hta`, `hta/decision-modelling-hta`,
  `hta/ispor-smdm-good-practices`, `hta/bayesian-cea-r-hta`; (2) per PMG36's update log,
  EQ-5D-5L (UK value set) applies to reference-case analyses from 27 August 2026 —
  `hta/nice-economic-evaluation/references/reference-case.md` should be checked; (3) the
  three background-mortality mechanisms across the HTA skills (floor, additive excess
  hazard, SMR-multiplied) are now cross-referenced from the survival files, but the hesim
  skill's SMR reference does not yet point back.
- Marginal-vs-conditional waning bias is flagged but not quantified; no helper implements
  individual-level waning.
