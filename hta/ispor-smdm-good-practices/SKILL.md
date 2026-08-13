---
name: ispor-smdm-good-practices
description: "Apply the ISPOR-SMDM Modeling Good Research Practices Task Force reports (Value in Health 2012; TF-1,2,3,4,6,7) when conceptualising, structuring, reviewing, validating, or reporting a decision-analytic model for health economic evaluation — model design and credibility rather than coding. Use for: defining the decision problem, scope, perspective, target population, comparators, or time horizon; choosing between decision tree, cohort Markov, microsimulation, or DES; stress-testing a model structure, HEAP, protocol, or briefing; state definition, cycle length, heterogeneity bias; the uncertainty taxonomy (stochastic/parameter/heterogeneity/structural), distributions, calibration; transparency documentation and validation (face, verification, cross, external, predictive). Trigger on 'ISPOR', 'SMDM', 'good practice', 'model conceptualisation', 'structure review', 'model validation', 'model audit', or 'is this defensible'. Jurisdiction rules → nice-economic-evaluation; R implementation → the method skills."
---

# ISPOR-SMDM modelling good research practices

Help the user design, review, validate, and report decision-analytic models to the
standard set by the **ISPOR-SMDM Modeling Good Research Practices Task Force**
(seven joint reports, *Value in Health* 2012;15:796–850, co-published in
*Medical Decision Making*). This remains the canonical cross-jurisdiction citation for
what a defensible model looks like — HTA bodies, journals, and reviewers still anchor
critique to it.

**Coverage.** This skill distils six of the seven reports:

| Report | Topic | Reference file |
|---|---|---|
| TF-1 (Caro et al.) | Overview, consolidated recommendations, quandaries | woven through this file and `references/review-checklist.md` |
| TF-2 (Roberts et al.) | Conceptualising the problem and the model | `references/conceptualising-models.md` |
| TF-3 (Siebert et al.) | State-transition models (cohort Markov + microsimulation) | `references/state-transition-models.md` |
| TF-4 (Karnon et al.) | Discrete event simulation | `references/discrete-event-simulation.md` |
| TF-6 (Briggs et al.) | Parameter estimation and uncertainty | `references/parameters-and-uncertainty.md` |
| TF-7 (Eddy et al.) | Transparency and validation | `references/transparency-and-validation.md` |

TF-5 (dynamic transmission models, Pitman et al.) is a **deliberate scope exclusion**:
it matters only when an intervention alters infection transmission or strain
distribution in the population. If that arises, go to the source paper
(*Value in Health* 2012;15:828–34) rather than improvising.

## Three modes of use

**1. Design mode** — a new model, protocol, or analysis plan is being drafted.
Start with `references/conceptualising-models.md` (problem statement before
structure, structure before data), then the technique-specific file once the
model type is chosen. Insist on the written problem statement early: most
downstream structural disputes are unresolved ambiguities in the decision
problem, not modelling disagreements.

**2. Review / audit mode** — an existing model, HEAP, protocol, or briefing is
being stress-tested (self-review, internal audit, or preparing/responding to
external review). Go straight to `references/review-checklist.md`, which
consolidates every numbered recommendation as an audit question and lists the
known failure modes reviewers probe. Record each item as *conforms* /
*deviates with documented rationale* / *gap* — the Task Force explicitly
endorses documented, reasoned deviation over unthinking box-ticking, so a
deviation register is a conforming output, not a confession. The checklist also
includes a **companion-artefact cascade check** (Section E) for confirming that
load-bearing decisions are stated consistently across a document suite
(protocol, HEAP/decision register, briefing, analysis plan) rather than patched
locally — essential for staged projects where corrections must fan out to every
artefact at once.

**3. Reporting & validation mode** — writing up, building the documentation
suite, or planning validation. Use `references/transparency-and-validation.md`
for the two-tier documentation standard and the five validation types, and the
reporting sections of the technique files for model-specific communication
(diagrams, traces, intermediate outcomes).

## The spine: principles that cut across every report

1. **Problem-driven, never data-driven.** The conceptual structure follows from
   the decision problem; conceptualise before inspecting the data (II-3).
   Data gaps do not amputate structure — they become explicit uncertainty,
   which then feeds value-of-information analysis. The converse also holds:
   abundant data is not a licence for complexity.
2. **Parsimony with sufficiency** (II-8). Simplicity serves transparency,
   debugging, and trust; but the model must be complex enough to represent the
   differences in value between strategies and keep face validity with clinical
   experts. Finding this balance is the modeller's core skill.
3. **Recommendations are not a checklist to follow unthinkingly.** Where a
   recommendation cannot or should not be followed, document the divergence,
   its rationale, and its likely consequences for results and inference (TF-1).
4. **Uncertainty examination and honest reporting is the hallmark of good
   practice** (VI-1). "Robust" means the *conclusion* is stable within the
   *actual* uncertainty of the inputs — not that outputs are insensitive to
   inputs. A model whose outputs don't respond to inputs is broken, and
   arbitrary ±50% sweeps measure sensitivity, not uncertainty.
5. **Any problem can be forced into any technique; the choice still matters.**
   Match technique to problem characteristics — unit of representation,
   interactions, resource constraints, time handling, history dependence —
   and be open to hybrids (II-7).
6. **Credibility = transparency + validation, and neither substitutes for the
   other.** A fully transparent model can be wrong; an opaque one can be right.
   Both are needed, and validation is application-specific, never a permanent
   property of the model (TF-7).

## Vintage and complements

The series dates from 2012. Treat it as the floor, not the ceiling, and layer
current expectations on top:

- **Jurisdictional requirements** (NICE reference case, severity modifier,
  discounting, PMG36 clause-level rules) supersede it where they conflict —
  hand off to `nice-economic-evaluation`.
- **Journal reporting** now also requires CHEERS 2022; TF-7's documentation
  standard is compatible but not identical.
- **Half-cycle correction** (III-14) is stated in its simple 2012 form; current
  practice often prefers within-cycle corrections (life-table/trapezoidal or
  Simpson's rule) or shorter cycles — flag this when the topic arises.
- **Structural uncertainty** was an acknowledged open problem in 2012 and
  largely still is; do not imply a settled method exists.

## Boundaries with sibling skills

This skill owns the *methodological standard* — what a good model, analysis,
and report look like, independent of software and jurisdiction. Hand off:

- **R implementation**: `decision-modelling-hta` (heemod cohort models, trees),
  `multistate-models-hta` (continuous-time/individual STMs),
  `discrete-event-simulation-hta` (simmer), `survival-analysis-hta`
  (time-to-event inputs and extrapolation).
- **PSA post-processing, CEAC/CEAF, EVPI/EVPPI/EVSI computation**:
  `bayesian-cea-r-hta` (TF-6 says *what* to report; that skill says *how*).
- **Evidence synthesis for effect inputs**: `network-meta-analysis-hta`,
  `population-adjusted-comparisons`.
- **NICE process and reference case**: `nice-economic-evaluation`.
- **Missing data in source analyses**: `missing-data-mice`.

When citing, give the recommendation number (e.g., III-6, VI-10, VII-6) so the
user can quote the source in protocols, decision registers, and responses to
reviewers.
