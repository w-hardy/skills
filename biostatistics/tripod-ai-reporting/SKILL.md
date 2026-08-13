---
name: tripod-ai-reporting
description: Apply the TRIPOD+AI reporting statement (Collins et al., BMJ 2024 - 27 items, 52 subitems, plus a 13-item abstracts checklist) so studies developing, validating, or updating a clinical prediction model are completely and transparently reported. Use for the write-up or appraisal of a prediction model study - auditing a draft manuscript, completing the checklist for journal submission, drafting or redrafting sections of the paper, or assessing reporting completeness in a systematic review. Also covers PROBAST+AI (Moons et al., BMJ 2025) for risk-of-bias appraisal, and TRIPOD-Cluster for multi-centre data. Trigger on "TRIPOD", "PROBAST", "reporting checklist", "reporting guideline", "model card", "prediction model manuscript", or any request to review or improve the write-up of a diagnostic or prognostic model study, even when the guideline is not named. Reporting and appraisal only - for the modelling methods use clinical-prediction-models; for economic evaluation reporting use cheers-2022-reporting.
---

# TRIPOD+AI Reporting

Transparent reporting is what allows a reader to judge whether a prediction model
is trustworthy and whether it could be used in their own setting. Poor reporting
is a principal reason most published models are never externally validated and
almost none reach practice.

## Provenance

- **TRIPOD+AI** — Collins GS, Moons KGM, Dhiman P, Riley RD, Beam AL, Van Calster
  B, et al. TRIPOD+AI statement: updated guidance for reporting clinical
  prediction models that use regression or machine learning methods. *BMJ*
  2024;385:e078378. Checklist and expanded explanation at tripod-statement.org.
- **PROBAST+AI** — Moons KGM, Damen JAA, Kaul T, et al. *BMJ* 2025;388:e082505.
- **TRIPOD-Cluster** — Debray TPA, Collins GS, Riley RD, et al. *BMJ* 2023. Article number not confirmed here; check tripod-statement.org before citing.

Verified 13 August 2026. Check tripod-statement.org for extensions before
starting an audit; the family is actively expanding.

## Facts to get right

These are the details most often stated loosely or wrongly:

- **TRIPOD+AI supersedes TRIPOD 2015.** The 2015 checklist should no longer be
  used. If a manuscript or reviewer refers to "the TRIPOD checklist", establish
  which one is meant.
- **27 main items, expanding to 52 subitems.** Structure: title (item 1),
  abstract (item 2), introduction (items 3-4), methods (items 5-17), **open
  science (item 18)**, **patient and public involvement (item 19)**, results
  (items 20-24), discussion (items 25-27).
- **A separate TRIPOD+AI for Abstracts checklist contains 13 items.** Journals
  increasingly ask for both.
- **It is agnostic to modelling approach.** The same checklist covers logistic
  regression and deep learning. There is no separate "ML checklist" — resisting a
  request to apply different standards to an ML model is part of the point.
- **It covers development, evaluation (validation), updating, or any combination.**
- **Fairness is embedded throughout**, not confined to one item — it appears in
  background, methods, results, and discussion.
- **TRIPOD+AI tells authors what to report; PROBAST+AI assesses risk of bias.**
  They are complements, not alternatives. PROBAST+AI has two distinct parts, for
  model development and for model evaluation, and may replace PROBAST-2019.

## Auditing a manuscript

Work item by item; do not summarise impressionistically. For each item record:

| Field | Content |
|---|---|
| Item | Number and short name |
| Status | Reported / Partially reported / Not reported / Not applicable |
| Location | Section, page, or line |
| Gap | What specifically is missing |
| Suggested text | Concrete wording the authors could use |

"Not applicable" needs a stated reason. A blank is not a judgement.

Produce the completed table, then a short prose summary that leads with the
items whose absence most threatens the reader's ability to trust or reuse the
model — not the items that were easiest to check.

## The items most often missed

In practice, audits keep landing on the same gaps. Check these first:

**Participants and setting.** Study design; eligibility criteria; dates of
recruitment and follow-up; the setting and the moment of prediction.

**Outcome.** Precise definition, how it was ascertained, whether ascertainment
was blinded to predictors, and — for prognostic models — the time horizon.

**Predictors.** Full list with definitions, how and when each was measured, and
whether measurement was blinded to the outcome.

**Missing data.** Amount missing per variable; assumed mechanism; handling
method; for multiple imputation, the number of imputations and which variables
entered the imputation model (including the outcome).

**Sample size.** How it was determined. "All available data" is an answer, but it
must be stated and its adequacy discussed.

**Model building.** How continuous predictors were handled; predictor selection
procedure; any shrinkage or penalisation; for ML, the hyperparameter tuning
strategy, search space, and how tuning was kept inside the validation loop.

**Performance.** Discrimination *and* calibration, with confidence intervals.
Calibration reported as a plot with slope and intercept, not a Hosmer-Lemeshow
p-value. Clinical utility where the model informs a decision.

**Validation.** Which type (internal, temporal, geographical, domain), and
performance in the validation data — not development data alone. A single random
split is not external validation and should not be described as one.

**Fairness (item-embedded).** Performance stratified by relevant demographic
groups, with a statement of which groups were examined and why. If none, say why
not.

**Open science (item 18).** Availability of the full model — coefficients or
weights, intercept, and any preprocessing — plus code, data availability, funding,
conflicts, protocol, and registration. A model a reader cannot reconstruct has not
really been reported.

**Patient and public involvement (item 19).** Whether there was any, and how it
influenced the work. If none, state that.

## Drafting a methods section

Nine paragraphs, one each, in this order:

1. Study design and setting
2. Participants — eligibility, dates, sample size and its justification
3. Predictors — list, definitions, measurement timing, blinding
4. Outcome — definition, ascertainment, time horizon
5. Missing data — amount, assumed mechanism, handling
6. Model development — approach, continuous variable handling, selection, shrinkage
7. Performance measures — discrimination, calibration, clinical utility
8. Validation — internal and/or external approach
9. Software — R/Python version, key packages with versions, random seeds

Then check the draft back against the checklist rather than trusting the
structure to have covered everything.

## Beyond the paper

Reporting is necessary, not sufficient. Smits, van Kuijk and Wynants (*Improving
Health Care with Clinical Prediction Models*, Maastricht UP 2026, CC BY 4.0)
frame what surrounds the model as a **prediction model-based innovation**: the
interface, the decision guidance attached to risk levels, EHR integration, user
training, and a monitoring plan. The model is only the engine.

Two conventions worth recommending:

- A **model card** — a short standardised sheet covering what the model predicts,
  the population it was built for, how it performed, and its known limitations.
  A package insert for a prediction model.
- An **impact study** — testing whether use of the model changes patient
  outcomes, rather than only measuring accuracy.

## Regulatory context

Models qualifying as medical devices may need UKCA or CE marking, or FDA
clearance. The EU AI Act classifies medical AI as high risk, with requirements
for transparency, human oversight, and documentation. Regulatory positions move
quickly — flag the requirement and recommend checking current MHRA, EU, or FDA
guidance rather than asserting specifics.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
The 27 items / 52 subitems / 13 abstract items structure, that TRIPOD+AI supersedes TRIPOD 2015, and PROBAST+AI — all from multiple independent sources.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
The TRIPOD-Cluster article number; the EU AI Act and device-regulation specifics, which move quickly and should be checked against current MHRA/EU/FDA guidance.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
