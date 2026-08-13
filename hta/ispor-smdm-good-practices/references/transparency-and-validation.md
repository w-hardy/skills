# Transparency and validation (TF-7, Eddy et al.)

Source: *Value in Health* 2012;15:843–850. Recommendations VII-1 to VII-11.
Applies to **all** model types.

Trust in a model is built two ways, and they are **inextricably linked but not
interchangeable**: **transparency** (people can see how the model is built) and
**validation** (how well the model reproduces reality). A model can be transparent
yet wrong (the erroneous but transparent formula *Distance = Rate/Time*); it can
be opaque to most readers yet correct (few clinicians can read the equations
behind a CT scan, but CT scans work). What ultimately matters is whether the model
accurately calculates the outcomes of interest — so both are required, and
**sensitivity analysis is a complement to validation, never a substitute** for it.

Multi-application ("general") models are described, validated, and reported as an
**ongoing** process, with each instantiation additionally described/validated/
reported; single-application models are typically done once. Every model today
should be able to achieve the transparency best practices; **not all models will
achieve all the validation best practices**, and failing to does not by itself
mean a model is not useful — but modellers should describe their validation
process and the level achieved, and strive toward the optimum.

## Contents
- Two-tier documentation (VII-1, VII-2)
- Public vs confidential documentation and IP
- The five validation types (overview)
- Face validity (VII-3)
- Verification / internal validity (VII-4)
- Cross-validation (VII-5)
- External validation (VII-6, VII-7, VII-8)
- Predictive validation (VII-9, VII-11)
- Multi-application models (VII-8, VII-10)
- Interpreting validations

---

## Two-tier documentation (VII-1, VII-2)

**VII-1 Non-technical documentation** — freely accessible to any interested
reader. Minimum contents: model type and intended applications; funding sources
and their role; structure; inputs, outputs, and other components that determine
function, and their relationships; data sources (and how they were identified/
selected); validation methods and results; and limitations. (The report's fuller
list adds: equations and their sources, methods for customising to settings,
effects of uncertainty, and a pointer to the technical documentation.) This
overview may not be enough to *replicate* the model.

**VII-2 Technical documentation** — detailed enough for a reader with the
necessary expertise to evaluate and *potentially reproduce* the model (structure,
components, equations, code). Made available **openly or under IP-protecting
agreements, at the modellers' discretion**.

This two-tier split maps cleanly onto the project's own "strict separation of
outputs" discipline: a clean, rationale-forward document for the reviewer;
a fuller technical/audit record behind it.

## Public vs confidential documentation and IP

The Task Force explicitly reconciled scientific openness with the need to protect
IP built at real cost. Public (unrestricted) documentation should at minimum
include the non-technical description; modellers *may* also release technical
docs or a working copy publicly. Confidential documentation — full technical
docs plus access to a working copy — should be provided to designated readers
(journal reviewers, or an organisation using the model for decisions) under
IP-protecting agreements (reviewers keeping it confidential as policy). Because
journals can access everything during review, they should **not** require full
technical documentation in the published paper. Modellers who provide a working
copy deserve credit for exceptional transparency, but not doing so should not
prejudice evaluation.

## The five validation types (overview)

Face → verification → cross → external → predictive, in roughly ascending
strength. **External and predictive validation are the strongest**, because they
correspond most closely to the model's purpose: anticipating what happens if a
decision is taken.

## Face validity (VII-3)

The extent to which the model, its assumptions, and applications correspond to
current science and evidence, judged by people with expertise in the problem.
Four aspects: **structure, data sources, problem formulation, results.**
- Evaluators should be **impartial** — no stake in the results — and **ideally
  blinded to the results** (assess structure/evidence/formulation without
  knowing the answer).
- If face validation raises questions, **discuss them in the report**; make the
  process available on request.
- Limitations to keep in mind: all models simplify (a state-transition model's
  discrete states and fixed cycles are clinically unrealistic yet can be
  accurate enough); insisting on expert agreement with every structural choice
  can *build current misconceptions into the model* (the HDL-cholesterol example);
  and there are no unambiguous criteria, so anyone with a stake can be swayed —
  which is exactly why impartial, ideally blinded evaluation matters.

## Verification / internal validity (VII-4)

Checks that the mathematics is performed correctly and consistently with the
model's specifications — **not** whether the structure or predictions are right.
Two steps: verify the individual equations (against their sources), and verify
their accurate implementation in code. Techniques: up-to-date code documentation;
structured **walkthroughs**; part-by-part verification; **double programming**
(independent coding by two programmers); comparison with hand calculations;
sensitivity analysis; **extreme-value analysis**; **trace analysis** (tracking
individual events and timing); and removing unnecessary detail that invites
errors. Verification will *not* catch a poorly chosen structure (the
*D = α + β₁R + β₂T* example can be coded and fitted perfectly and still be
wrong). Describe the verification methods in the non-technical documentation;
make pertinent results available on request.

## Cross-validation (VII-5)

Compare the model against other models addressing the same problem and examine
the differences and their causes. Search for prior modelling analyses of the same
/ similar problems and **discuss insights from similarities and differences**.
Value depends on the **independence** of methods and data — high dependency
(reusing another model's parameters) weakens it; genuinely independent
alternative structures (e.g., the seven independent CISNET breast-cancer models)
strengthen it.

## External validation (VII-6, VII-7, VII-8)

Compare the model's results with **actual event data** — simulate events that
have occurred (e.g., a clinical trial) and see how well results correspond.

**VII-6 Formal process:**
- **Systematic identification of suitable data sources**, with **justified
  selection**, an explicit statement of whether each source is **dependent,
  partially dependent, or independent**, and a description of which model parts
  each source evaluates.
- **Simulation of each source.**
- **Comparison of results**, with descriptions of: the data source; the
  simulation set-up; discrepancies between source and simulation and their
  implications; discrepancies between simulation and observed results; and
  sensitivity analyses.
- **Quantitative measures** of how well results match source outcomes.

Dependence definitions (get these right — reviewers do): a validation is
**dependent** if the same source built/estimated the model *and* validates it;
**partially dependent** if the source built/calibrated *part* of the model but
that part doesn't wholly determine the validated outcome; **independent** if no
source information was used to build the model; and **blinded** if validators had
no information about the source outcomes. Choose the validation plan/sources
**before results are known**, via a formal search, based on intended model use —
not on convenience or the likelihood of a flattering result.

Practical rules when simulating a source: match setting, population, treatment
and follow-up protocols, and outcome definitions as closely as possible (a
mismatch — e.g., MI defined as hospitalisations only vs including silent/sudden —
will make event rates diverge legitimately); do **not** set up the simulation
using the source's health *outcomes*; and once a model is ready for external
validation, do **not refit** its natural-history/effect parameters to each source
to force a match (refitting is a signal the structure may be wrong). Compare using
the **same statistical methods** the source used (Kaplan-Meier vs Kaplan-Meier,
same follow-up times), report uncertainty and any un-simulable factors, then
explore quantitatively how discrepancies affect results — if justifiable
assumptions bring convergence, results can be called "consistent with" the actual
data.

**VII-7** Make the external-validation process/results available on request;
identify parts that cannot be validated for lack of sources; describe how
uncertainty about those parts is addressed.

Limitations to state honestly: external validation only covers parts with data
sources; accurate matching of aggregate results may not validate subpopulations;
informal sources ("real practice") are hard because it is difficult to know what
actually happened; and validation of **resource use and costs** is especially
problematic because practice patterns and unit costs vary across settings.

## Predictive validation (VII-9, VII-11)

The strongest and most desirable type: specify a study design, simulate it,
**record predictions**, wait for events to unfold, then compare. It guarantees a
completely independent validation with no opportunity to alter the model to fit
observed results. Limitations: results lie in the future (rarely in time for the
immediate decision) and require a trial planned/in progress applicable to the
decision — often none exists. Best use: simulate a trial already initiated but
not yet reported. Builders of **multiple-use** models should seek opportunities
to conduct predictive validations (VII-11).

## Multi-application models (VII-8, VII-10)

Distinguish validating a model in a general sense (a "diabetes model") from
validating it for a specific application. Perform **multiple** validations that
criss-cross intended applications (range of populations, interventions, outcomes,
horizons) and validate **separate model parts** — a model can overestimate
incidence, underestimate treatment effect, and still hit mortality by
cancellation, falsely appearing wholly valid. Describe criteria for when
validations should be **repeated or expanded** (VII-10), and redo external
validations as models are modified or new evidence arrives.

## Interpreting validations

Whether a model is sufficiently valid for a given application is decided by those
who would use its results, against four criteria: **rigour of the process**;
**quantity and quality of sources**; the model's ability to **simulate sources in
appropriate detail**; and **how closely results match observed outcomes**,
initially and after justifiable assumptions about uncertain elements. Remember the
grounding caution the report closes on: models are not reality; they are aids for
questions too complex for unaided judgement.
