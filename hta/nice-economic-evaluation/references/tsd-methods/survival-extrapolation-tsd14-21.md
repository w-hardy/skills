# TSD 14, 21 & 26 — Survival analysis, extrapolation and expert elicitation (methods)

*Supports PMG36 4.2.24 and the survival-modelling paragraphs of section 4.6 (4.6.20–4.6.26;
4.10.5 covers presenting survival estimates). Use alongside
`../modelling-and-uncertainty.md` and `scripts/survival_extrapolation.R`. For fitting mechanics,
cure/relative-survival models, KM reconstruction and PSA sampling, see `survival-analysis-hta`.*
TSD 14 (Latimer 2011/2013): https://sheffield.ac.uk/nice-dsu/tsds/survival-analysis — TSD 21
(Rutherford et al. 2020): https://sheffield.ac.uk/nice-dsu/tsds/flexible-methods-survival-analysis
— TSD 26 (Oakley, Ren et al., Mar 2025): https://sheffield.ac.uk/nice-dsu/tsds/expert-elicitation-tsd — full list:
https://sheffield.ac.uk/nice-dsu/tsds/full-list (all accessed 2026-08-27)

## The TSD 14 process (what EAGs and committees expect to see)
Survival extrapolation should follow a transparent, justified process — not "pick the lowest
AIC". This is a NICE DSU recommendation (TSD 14, Latimer 2011/2013) that committees and EAGs
routinely expect to see followed; PMG36 itself says extrapolation validity "should routinely
be considered" (4.6.25), describes scenario analyses as *desirable*, and says they *should
include* the no-further-benefit assumption (4.2.24) — the TSDs are advisory, but PMG36 cites
TSD 14 and TSD 21 by name (4.6.21–4.6.24), making them the de facto benchmark. Steps:

1. **Inspect the data** — Kaplan–Meier, number at risk, and the **smoothed hazard** over time.
   The shape of the hazard (monotonic, peaked, turning, bathtub) tells you which distributions
   are even plausible.
2. **Test proportional hazards** between arms (log-cumulative-hazard plot; `cox.zph`) — a
   non-significant test with few events is weak evidence FOR PH, not proof. If PH holds, a
   treatment-covariate model may be reasonable; if not, fit arms separately, use an AFT
   structure, or a covariate on an ancillary parameter.
3. **Fit the standard parametric set** — follow TSD 14 and consider all six: exponential,
   Weibull, Gompertz, log-normal, log-logistic and generalised gamma ("should all be
   considered", TSD 14 p. 13 and Rec. 3); that is what `survival_extrapolation.R` fits. The
   condensed journal version (Latimer 2013, p. 749) categorises differently, describing
   generalised gamma / generalised F as "more flexible" extensions to consider when the
   standard ones look unsuitable, rather than part of its five-model "standard" set — a
   difference in categorisation, not a conflict. Compare on AIC/BIC together with visual fit
   to the KM and, crucially, external plausibility of the extrapolated tail.
4. **Assess external validity** — does the extrapolation agree with long-term registry/trial
   data, expected general-population mortality, and clinical expectation? Where follow-up
   allows, refit to an earlier data cut and compare the extrapolation against the later
   observed data. A fit implying implausible long-term survival (cure where none exists, or
   beating the general population) is rejected however good its in-trial AIC.
5. **Deal with general-population mortality (TSD 21, not TSD 14).** TSD 14 is silent on
   general-population mortality (its external-data recommendations — Rec. 9 — cover validity
   comparison, calibration and direct use of registry data, but never life tables); the
   recommendation to incorporate it is TSD 21 (Rutherford et al., Jan 2020, p. 89):
   "recommended … and is essential for cure models". The principled route is
   internal additive excess-hazard / relative-survival modelling — general-population hazard
   plus modelled excess hazard combined inside the likelihood (flexsurv's `bhazard`; see
   `survival-analysis-hta`) — which by construction cannot let modelled all-cause mortality
   fall below general-population mortality. Pragmatic alternative: a post-hoc hazard FLOOR on
   the extrapolated curve (`apply_background_floor`) — the population hazard is a floor on
   modelled mortality, equivalently a cap on conditional survival — simple, but Sweeting et
   al. (2023, p. 738) note this switching approach "causes a discontinuity in the all-cause
   hazard function" where the floor first binds and describe excess-hazard modelling as the
   more statistically coherent route. Match life
   tables on age, sex and calendar year; trial populations can be healthier OR sicker than the
   general population; the constraint is for all-cause OS, not PFS/time-on-treatment; check the
   effect on the incremental result; apply exactly ONE mechanism (floor, additive excess hazard,
   or SMR adjustment) — never stacked.
6. **Carry uncertainty forward** — present several plausible distributions as scenarios (not
   just the best fit), reflect parameter uncertainty in the PSA, and include a "no further
   benefit" family per PMG36 4.2.24 ("assuming the technology does not provide further benefit
   beyond the technologies' use"): (i) no further benefit after a cutoff — step change to equal
   hazards (`no_continued_benefit`) — accrued benefit is RETAINED, curves do NOT converge; (ii)
   gradual waning, hazard ratio returning to 1 over an interval (`waning_scenario`); (iii) loss
   of accrued benefit — curves actually converge onto the comparator — the most pessimistic
   variant, rarely the base case. Applying HR-waning to marginal (population-average) curves
   only approximates individual-level waning and can bias RMST when populations are heterogeneous.

## When standard parametric models aren't enough (TSD 21)
TSD 21 covers the flexible alternatives, incorporation of general-population mortality
(relative survival), cure models, and when-to-use guidance — not merely "when the six standard
distributions fit poorly":
- **Flexible parametric / spline (Royston–Parmar)** models — splines on the log-cumulative-hazard,
  odds, or normal scale; more knots capture complex hazards.
- **Mixture-cure and non-mixture-cure** models — a fraction effectively cured (e.g. some
  immuno-oncology), so survival plateaus toward background mortality.
- **Landmark / piecewise** and **mixture** models for changing hazards.
- **Relative-survival / excess-hazard models** incorporating general-population mortality
  (step 5) — relevant to standard parametric fits too, not only flexible ones.
Justify the added flexibility (don't over-fit); still check external validity and how
general-population mortality has been handled.

## Structured expert elicitation for long-term survival (TSD 26, March 2025)
Bespoke DSU guidance ("a companion to TSD 14 and TSD 21") for eliciting long-term survival
where trial data are immature. Protocol-agnostic: any of the standard protocols (SHELF,
Cooke's, Delphi, IDEA, MRC reference protocol) can be adapted — TSD 26's own worked example
is SHELF-based, but it explicitly declines to recommend one protocol over another (Rec. 13).
By default elicit a probability distribution of survival at **one** time point per treatment
arm (not the survivor function at multiple landmarks), with explicit discussion of the
underlying hazard behaviour (Recs. 1–2). Experts give distributions, not point estimates,
with self-consistency and scenario checks, run by an experienced facilitator; aggregation is
by behavioural consensus by default (performance weighting belongs with Cooke's method,
Rec. 16). Use it to inform extrapolations and to *exclude* implausible models, reporting
results for each remaining scenario (Rec. 19) — an improvement on the common practice of
informal clinician validation of a chosen curve.

## Things a committee / EAG checks (and common errors)
- **AIC-only selection** with no visual/external check — the single most common criticism.
- **Pooling arms / assuming PH** without testing it.
- **General-population mortality not addressed** — hazards below matched general-population
  mortality will be challenged (step 5).
- **A single chosen curve** with no scenario range and no "no further benefit" case.
- **Standard distributions forced** onto a plateauing/curing hazard where cure/spline models
  are indicated.
- **Immature data / few at risk in the tail** — check the extrapolation isn't driven by a
  handful of patients; state follow-up and events at the point extrapolation takes over.
- **Partitioned survival models: PFS/OS incoherence** — independently fitted curves must not
  cross (S_PFS ≤ S_OS everywhere); crossing implies negative progressed-alive occupancy. TSD
  19 (Recommendation 11) formally recommends state-transition modelling be used *alongside*
  the partitioned-survival analysis as a cross-check (while stopping short of recommending
  PartSA be replaced).
- Choosing the curve that maximises the technology's benefit without justification.

RMST to a common horizon is useful supporting practice for comparing candidate fits and
summarising benefit under non-proportional hazards — not itself a required NICE/EAG item; the
decision-relevant quantity remains mean (lifetime) survival.

## Reporting
Hazard and KM-vs-fit plots per arm; AIC/BIC table; the PH assessment; the external-validity
argument and data used; how general-population mortality was handled; and the set of
extrapolation scenarios taken to the model.
