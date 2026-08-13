# Conceptualising the problem and the model (TF-2, Roberts et al.)

Source: *Value in Health* 2012;15:804–811. Recommendations II-1 to II-8.

Conceptualisation has **two distinct stages**, and conflating them is a common
early error:
1. **Problem conceptualisation** — convert knowledge of the health care
   process/decision into a representation of the *problem*.
2. **Model conceptualisation** — match a modelling *method* to that problem.

Do the first before the second, and both before touching the data. The single
most useful discipline here is a written problem statement, because ambiguity in
the decision problem — not modelling technique — is what most stakeholder
disputes turn out to be.

## Contents
- Statement of the problem (II-1, II-2)
- Perspective (II-2b)
- Target population (II-2c)
- Outcomes (II-2d)
- Interventions / comparators (II-2e, II-3a)
- Structure driven by problem not data (II-3)
- Time horizon (II-3b)
- Structural uncertainties from conceptualisation (II-4)
- Policy context and sponsorship bias (II-5)
- From problem to structure (II-6)
- Choosing a technique (II-7 and sub-recommendations)
- Simplicity vs sufficiency (II-8)

---

## Statement of the problem (II-1, II-2)

**II-1** Consult widely with subject experts and stakeholders — clinical,
epidemiological, policy, methodological, and where relevant patients — so the
model represents disease processes appropriately and addresses the decision
problem. Review existing models of related problems first.

**II-2** Produce a **clear, written statement** of the decision problem,
modelling objective, and scope. It must include: disease spectrum, analytic
perspective, target population, alternative interventions, health and other
outcomes, and time horizon. The written narrative lets stakeholders give direct
input and becomes the reference point for later refinement. The objective is
iterative — expect it to sharpen as understanding deepens — but write it down
early anyway.

A useful discipline is to fill in a scope table (the TF-2 mammography box is the
template): decision problem/objective, policy context, funding source, disease,
perspective, target population and subgroups, health outcomes (and those
*explicitly excluded*), strategies/comparators, resources/costs, time horizon.
The "explicitly excluded" cells matter as much as the included ones.

## Perspective (II-2b)

State and define the analytic perspective; outcomes modelled must be consistent
with it. A narrower-than-societal perspective must report what is included and
excluded. TF-2 flags a widespread failure: analysts assert a "societal"
perspective while actually modelling a narrower **medical-sector / health-care-payer**
perspective (only outcomes for treated patients, only medical-service costs).
When outcomes are modelled without costs, the perspective is often left unstated
— but *all outputs should be analysed from the same perspective*. Check this
consistency explicitly.

## Target population (II-2c)

Define by geography, patient characteristics (including comorbidities), disease
prevalence/stage — each appropriate to the decision. Consider people affected but
not targeted (herd immunity; carer health/costs). Subgroups that differentially
affect disease course or intervention impact may need separate treatment; a large
number of characteristics/levels pushes toward individual-level modelling.

**Open vs closed population.** Closed cohorts (members enter only at the start)
suit the medical-sector perspective and most HTAs; open populations (new members
enter over time) suit ongoing programmes and budget-impact work. A cohort
simulation is implicitly bounded by the cohort's lifetime; open models require
separate decisions about programme duration and run length.

## Outcomes (II-2d)

Outcomes — events, cases, deaths, life-years, QALYs, DALYs, or other stakeholder-
relevant measures — must be directly relevant to the question. Distinguish
**intermediate event outcomes** (e.g., MI) from **intermediate physiological/
biological measures** (e.g., blood pressure, tumour response) used to project
final outcomes via predictive equations. Model **adverse effects**, not just
benefits: if harms aren't captured automatically (as treatment-related mortality
might be), model them separately. Prefer long-term / final outcomes.

## Interventions / comparators (II-2e, II-3a)

Define interventions by frequency, component services (including preceding
services that affect course), dose/intensity, duration, and subgroup variations.
Include standard care and other routinely used strategies.

**II-3a is one of the most consequential recommendations in the whole series:**
the choice of comparators crucially affects results and must be driven by the
decision problem, *not* data availability or quality. Consider all feasible and
practical strategies; **constraining the range must be justified**. "No
intervention" / natural history is a legitimate comparator when it reflects
standard practice. When reviewing, a truncated comparator set with no
justification is a first-order finding.

## Structure driven by the problem, not the data (II-3)

Data are essential, but the *conceptual structure* follows from the decision
problem or research question — not from what data happen to exist. Range broadly
over the problem even where data are poor or absent; features lacking data can
still be included and explored via sensitivity analysis (methods exist for
inferring values for unobserved parameters). Credibility is still judged partly
on data quality for key parameters, so data selection balances fidelity to the
problem, representativeness, and quality.

## Time horizon (II-3b)

Long enough to capture relevant differences in outcomes across strategies; a
**lifetime horizon may be required**, especially when the intervention affects
mortality. Lifetime horizons usually force extrapolation well beyond trial/
observational data — so short-term effects rest on primary data while long-term
ones are extrapolated, and **sensitivity analyses on the extrapolation
assumptions (upper/lower boundary cases) are expected** (this links to II-4).
Consider secular trends (e.g., serotype replacement) at least in sensitivity
analysis. The decision-maker's relevant horizon may be shorter than the disease's
— state and justify the choice.

## Structural uncertainties identified at conceptualisation (II-4)

Every conceptualisation decision can alter results. During conceptualisation,
experts and modellers should **name the assumptions to test via structural
sensitivity analysis**. The choice of technique interacts with this: a structural
SA in one model type may reduce to a parameter SA in another. Capture these
candidate structural analyses now — they are hard to reconstruct later, and TF-6
(VI-11) will expect them.

## Policy context and sponsorship bias (II-5)

State the policy context: funder, developer, single- vs multi-application,
policy audience. Flag the **sponsorship-bias** risk candidly — manufacturers have
incentives toward favourable conclusions; payers/governments toward cost
constraint. Both directions of bias are documented in the literature. This is a
transparency obligation, not an accusation.

## From problem to structure (II-6)

Use an **explicit process** — influence diagrams, concept mapping, expert
consultation — to convert the problem conceptualisation into a model structure,
with a **written record** of the instantiation. The explicit record is what lets
content experts, policymakers, and modellers argue productively about what's in,
what's out, and which simplifications were made.

## Choosing a technique (II-7)

Virtually any problem can be represented in any technique, so these are not
prescriptive — but some problems are more *naturally* represented in some types.
Decide on these problem characteristics:

- **Unit of representation — individuals vs groups.** Cohort methods (decision
  trees, Markov, compartmental) treat populations as homogeneous within a
  state/compartment; individual methods (microsimulation, DES, agent-based)
  track each entity. Modelling individuals is not automatically more accurate,
  but it is the practical choice when many predictive characteristics must be
  carried, when continuous variables should stay continuous rather than
  categorised, or when history matters.
- **Interactions between individuals** (or between individuals and model
  components such as shared resources) → dynamic transmission, DES, or agent-
  based.
- **Resource constraints / queues** → DES or agent-based (see
  `discrete-event-simulation.md`).
- **Time horizon and time measurement.** Very short horizon / few outcomes →
  decision tree (II-7a). Longer horizons or time-varying probabilities → STM,
  DES, dynamic transmission. Continuous time vs discrete cycles: short cycles are
  needed when event likelihood is high.

Sub-recommendations:
- **II-7a Decision tree** — simple problems, very short horizons, few outcomes,
  or consequences known with some certainty; quick to outline a problem's
  components.
- **II-7b State-transition** — when the process is a series of homogeneous
  health states; the Markov (memoryless) limitation is handled by adding states,
  and by switching to individual STMs when states would explode. See
  `state-transition-models.md`.
- **II-7c Interactions** → methods that represent them (dynamic transmission /
  DES / agent-based), which also handle continuous time and time-to-event data
  more naturally.
- **II-7d Resource constraints** → DES / agent-based, designed for competition
  for resources and queues.
- **II-7e Hybrids** — combinations and other methodologies (e.g., physiologic
  "in-silico" models, hybrid state/event models) are legitimate; the standard
  types are not exhaustive.

## Simplicity vs sufficiency (II-8)

Simplicity aids transparency, analysis, validation, and description — but the
model must be complex enough that differences in value (health or cost) across
strategies are faithfully represented and face validity with clinical experts is
preserved. Multi-application policy models may need more complexity. "Everything
should be made as simple as possible, but not simpler." Selecting the right level
of detail is described as one of the hardest decisions a modeller faces — so a
review finding of "too simple to capture the value difference" or "complex beyond
what the problem or data support" is squarely on-point, in either direction.
