# Review / audit checklist

Use this to stress-test an existing model, HEAP, protocol, decision-model
briefing, or manuscript against ISPOR-SMDM good practice, or to prepare for /
respond to external review. It consolidates every numbered recommendation as an
audit question and flags the failure modes reviewers actually probe.

**How to record findings.** For each item, mark one of:
- **Conforms** — met, with a pointer to where.
- **Deviates (documented)** — not met as stated, but the divergence, its
  rationale, and its likely consequences for results/inference are written down.
  Per TF-1, this is a **conforming** outcome — the reports explicitly reject
  unthinking box-ticking and endorse reasoned, documented deviation.
- **Gap** — not met, and not (yet) justified. This is the finding to fix.

Cite the recommendation number in every finding so it can be quoted in a
decision register or a response to reviewers.

Work top to bottom: conceptualisation issues cascade, so an unresolved II-2 / II-3a
problem usually explains several downstream "structural" disagreements.

---

## A. Conceptualisation (TF-2 · details in `conceptualising-models.md`)

- **II-1** Wide consultation with clinical/epi/policy/method experts (and
  patients where relevant); prior related models reviewed?
- **II-2** A **written** decision-problem/objective/scope statement covering
  disease spectrum, perspective, target population, comparators, outcomes, time
  horizon? *(The single highest-leverage check — its absence explains most
  downstream disputes.)*
- **II-2b** Perspective stated **and** all outcomes analysed from the *same*
  perspective? *(Failure mode: "societal" asserted but medical-sector actually
  modelled; or health-outcome perspective left unstated while costs have one.)*
- **II-2c** Target population defined (geography, characteristics, comorbidities,
  stage); subgroups and affected non-targets (herd immunity, carers) considered;
  open vs closed population appropriate?
- **II-2d** Outcomes directly relevant; **adverse effects** modelled, not just
  benefits; intermediate *events* distinguished from intermediate *biological
  measures*?
- **II-2e / II-3a** Interventions fully specified (frequency, components, dose,
  duration, subgroup variants); **comparator set driven by the decision problem,
  not data availability**; standard care / natural history included; any
  constraint on the strategy set **justified**? *(High-frequency reviewer
  finding: a truncated or convenient comparator set.)*
- **II-3** Structure driven by the problem, **conceptualised before inspecting
  the data**; data-poor features still represented (with SA) rather than dropped?
- **II-3b** Time horizon long enough to capture outcome differences; lifetime
  where mortality is affected; extrapolation beyond data flagged with boundary-case
  SA (→ II-4, VI-11)?
- **II-4** Structural uncertainties from conceptualisation **named** for later
  structural SA?
- **II-5** Policy context stated (funder, developer, single/multi-application,
  audience); **sponsorship-bias** direction acknowledged?
- **II-6** Explicit, **written** process (influence diagram / concept map /
  expert consultation) from problem to structure?
- **II-7** Technique matched to problem characteristics (unit of representation,
  interactions, resource constraints, time handling, history dependence); hybrids
  considered where apt?
- **II-8** **Parsimony vs sufficiency** — simple enough to be transparent, complex
  enough to represent value differences and keep clinical face validity? *(Findable
  in either direction: too simple to capture the value difference, or complex
  beyond what problem/data support.)*

## B1. If a state-transition model (TF-3 · `state-transition-models.md`)

- **III-1** Cohort vs individual choice justified by whether states+history stay
  *manageable*; **validity not sacrificed for simplicity**?
- **III-2** Strategies clearly defined; **sequential decisions kept out of the
  Markov cycle tree** (in the strategy specification instead)?
- **III-3** Starting cohort defined by characteristics that affect transitions /
  state values?
- **III-4** States mutually exclusive, collectively exhaustive, biologically/
  theoretically grounded; **history carried in state definitions** where it drives
  transitions; competing causes of death handled without bias; initial/short-term
  events handled (e.g., pre-STM decision tree with time credit)?
- **III-5** States capture intervention type (prevention/screening/diagnosis/
  treatment) and benefits **and harms**; screening controls for **lead-time and
  length bias**; realistic adherence?
- **III-6** States **homogeneous** for observed *and unobserved* transition-
  affecting characteristics; **heterogeneity bias** from unknown-at-decision
  variables considered?
- **III-7** Time horizon captures all relevant effects/costs (lifetime if
  mortality affected)?
- **III-8** Cycle length short enough that an event occurs at most once per
  cycle, consistent with clinical event frequency?
- **III-9** Symmetric representation across strategies; shared clinical courses
  **built once and linked**, not recreated?
- **III-10** Probabilities/effects from the **most representative** sources
  (population-based > trial control arms; systematic review/MA where available;
  evidence table otherwise)?
- **III-11** Methods/assumptions described; unit conversions done **through
  rates**; probabilities not called rates, rates not shown as percentages;
  additive-vs-multiplicative mortality assumption stated and its impact assessed?
- **III-12** Observational effects controlled for confounding, incl. **time-
  varying** confounding; extrapolated mortality reductions applied to
  disease-specific (not all-cause) mortality; **double counting** of
  incidence+mortality reductions avoided/validated?
- **III-13** State values (utilities, costs) justified?
- **III-14** Half-cycle correction on costs and effects in the first cycle (and
  final cycle if not lifetime)? *(Flag the modern within-cycle-correction
  alternatives if relevant.)*
- **III-15** Where relevant (e.g., equity), distribution of outcomes reported,
  not only the mean?
- **III-16** Microsimulation run at an n giving **stable** estimates (variance ≪
  smallest strategy difference)?
- **III-17 / III-18** Clear diagrams and non-technical communication; **intermediate
  outcomes** presented (and usable for face validity / curve comparison)?

## B2. If a discrete event simulation (TF-4 · `discrete-event-simulation.md`)

- **IV-1** DES justified (constrained resources, or interactions / stochastic
  time-to-event / multi-characteristic pathways / individual experience)?
- **IV-2 / IV-3** Constrained-resource models report **health outcomes**, not just
  throughput; constrained resources modelled where access levels change **and**
  access time affects cost/outcome?
- **IV-4** Structure supports analysis of significant **downstream decisions**?
- **IV-5–IV-7** Expert-elicited inputs have **represented uncertainty** and are
  **validated**; low-confidence inputs flagged as what-if only; structure changes
  for data reasons analysed for induced uncertainty?
- **IV-8 / IV-9** **Guideline adherence not assumed**; decision algorithms based on
  observed decisions or validated against routine data?
- **IV-10** Competing events estimated **jointly** rather than as separate
  independent curves?
- **IV-11** Continuous-parameter-driven events defined **jointly** to preserve the
  event-driven nature (sample level, then time to reach it)?
- **IV-12** Submodels used; **common submodels defined once and called from each
  strategy**?
- **IV-13** Structural SA implemented **within a single DES**?
- **IV-14** Ongoing risks not inadvertently **blocked** over the horizon?
- **IV-15** Only required outputs collected (attributes for individual-level;
  aggregates otherwise)?
- **IV-16** Software choice (general vs dedicated) justified; **spreadsheet DES
  avoided** unless justified?
- **IV-17** Output **stability** tested across seeds (entities / duration /
  replications)?
- **IV-18** Variance-reduction techniques used with a sensible effort trade-off?
- **IV-19–IV-21** Factorial/optimum-seeking for many strategies; empirically
  optimised PSA run mix; meta-modelling when compute-bound?
- **IV-22** Non-empty systems handled by justified **warm-up** or empirically
  based **preload**?
- **IV-23 / IV-24** Animation used where helpful; **both** general and detailed
  structure/logic documented?

*(Dynamic transmission model → TF-5, out of this skill's scope; go to the source
paper, VIH 2012;15:828–34.)*

## C. Parameters and uncertainty (TF-6 · `parameters-and-uncertainty.md`)

- **VI-1** A systematic uncertainty assessment appropriate to the decision
  problem — present at all?
- **VI-2** Decision-maker's power to delay/review and commission/mandate research
  stated as part of the perspective?
- **VI-3** The **four uncertainty types** (stochastic / parameter / heterogeneity
  / structural) distinguished and terminology defined?
- **VI-4** Parameters populated per **evidence-based-medicine** principles (all
  evidence, formal synthesis, no cherry-picking)?
- **VI-5** DSA and PSA linked to the evidence base and **mutually consistent**?
- **VI-6** No **arbitrary ±X% ranges dressed up as uncertainty**? *(Common
  finding.)*
- **VI-7 / VI-9** Standard, **continuous, theoretically-appropriate** distributions
  (beta/gamma/log-normal/logistic); triangular/uniform used only with
  justification?
- **VI-8** No parameter excluded from uncertainty analysis for "too little
  information" — broad conservative ranges instead?
- **VI-10** Correlation handled: joint estimates' covariance reflected;
  independence **not assumed by default** for separately estimated parameters
  (correlation parameter or re-parameterisation)?
- **VI-11** Structural uncertainties **tested** (parameterised where possible); if
  untestable, acknowledged as potentially dominant?
- **VI-12 / VI-13** Both DSA and PSA reported where useful; tornado ranges
  **defensible not arbitrary**; distributions and added assumptions disclosed and
  justified; **negative ICERs avoided**, quadrants labelled?
- **VI-14** Calibration uncertainty reported and reflected in DSA/PSA?
- **VI-15 / VI-16** VOI (EVPI/EVPPI/EVSI) where the purpose is guiding research;
  otherwise CEACs + NMB/NHB distributions, with **a CEAC per comparator on one
  graph** when >2 comparators?

*(Computation of these → `bayesian-cea-r-hta`.)*

## D. Transparency and validation (TF-7 · `transparency-and-validation.md`)

- **VII-1** Freely accessible **non-technical** documentation with the minimum
  contents (type, applications, funding, structure, inputs/outputs/relationships,
  data sources, validation, limitations)?
- **VII-2** **Technical** documentation sufficient to evaluate/reproduce, released
  openly or under IP-protecting agreement?
- **VII-3** **Face validity** evaluated on structure/evidence/formulation/results
  by **impartial, ideally blinded** experts; questions raised are discussed in the
  report?
- **VII-4** Rigorous **verification** (walkthroughs, double programming, hand
  calcs, extreme-value/trace analysis); methods in the non-technical docs?
- **VII-5** **Cross-validation** against other models of the same problem, with
  differences discussed?
- **VII-6 / VII-7** Formal **external validation** process: sources systematically
  identified and justified; **dependence status stated**; each source simulated
  and compared with quantitative match measures; un-validatable parts identified;
  no **refitting** to force a match; same statistics as the source?
- **VII-8 / VII-10** For multi-application models, **multiple criss-crossing**
  validations, separate-part validation, and criteria for when to repeat/expand?
- **VII-9 / VII-11** **Predictive** validation sought where feasible (especially
  for multiple-use models)?
- Overall: is **sensitivity analysis being mis-sold as validation**? It
  complements but never substitutes for it.

## E. Companion-artefact consistency (cascade check)

Staged, auditable modelling projects rarely live in one document. A typical suite
is: the model protocol (or candidate protocol), a decision-model briefing (for the
CI or an external reviewer), a statistical / linked-data analysis plan, the Health
Economic Analysis Plan (HEAP) and its decision register, any prior specification,
and later the technical documentation and manuscript. TF-2's written problem
statement (II-2) is meant to be the **single reference point** the rest derive
from, and TF-7's two-tier documentation guarantees several artefacts coexist. The
failure mode is a **load-bearing decision changed in one artefact but not the
others** — patched locally instead of cascaded — which leaves a silent
inconsistency that (a) reviewers catch and (b) quietly corrupts the audit trail,
because the register no longer describes what the documents actually say.

This check is not tied to a single ISPOR recommendation; it is the governance
discipline that keeps II-2, II-3a, II-6, and TF-7 honest **across** a document set.
Treat it as a first-class review item, not a nicety.

**How to run it.** Build a small matrix — **load-bearing decisions (rows) ×
artefacts (columns)**. For each decision, confirm it is stated *identically*, or
with a *deliberately reconciled* difference, everywhere it appears, and that the
decision register records its current version and every artefact that instantiates
it. An unreconciled difference is a **Gap**; an intended, documented difference is
a **Deviates (documented)**.

**The rows that cascade widest** — a change here ripples furthest, so check these
first:

- **Decision-problem framing** — what the comparators *are* (e.g., open-ended
  maintenance therapies vs fixed-duration-plus-continuation), how post-trial /
  post-supply-window data are treated, whether a censoring event is
  administrative or a real discontinuation. This is the highest-cascade decision
  in the suite: II-3a means it drives results, so a re-framing must reach the
  protocol's decision problem, the analysis plan's handling of the relevant data,
  the HEAP's extrapolation and sensitivity specification, **and** the briefing's
  plain-language statement — consistently and all at once.
- **Perspective** (II-2b), consistent across outcomes and costs.
- **Comparator set** (II-3a) and any justified constraint on it.
- **Target population / subgroups** (II-2c).
- **Time horizon and extrapolation approach** (II-3b, II-4).
- **Model structure / state space**, the base-case choice, and any pre-specified
  **fallback / data-density criteria** and ladder between candidate structures
  (II-6, III-4).
- **Outcome set including adverse effects** (II-2d).
- **Utility / value-set and mapping approach** (III-13) — e.g., response/dimension-
  level vs index-level mapping, and which value set is base case.
- **Mortality sourcing and structure** (III-10, III-11) — which source, applied to
  which states/periods.
- **Pre-specified sensitivity / structural analyses** (II-4, VI-11), including
  their pre-specification status — established *before* seeing arm-level outcomes.
- **Discounting, cycle length, half-cycle handling** (III-8, III-14) and any
  jurisdiction rule (→ `nice-economic-evaluation`).

**Register discipline (fail-closed).** Last-write-wins is only safe if the write
is *propagated*. The decision register should be the source of truth that names,
for each decision, its current version, its rationale, and the artefacts it lives
in — so a change is a single register update plus a fan-out edit, not a
hunt-and-patch. Keep the split TF-7 draws: the reviewer-facing artefacts carry the
clean, current statement; the register carries the full history of changes,
conflicts, and decision rounds. A correct earlier decision should not be silently
reversed by a local edit that never reaches the register.

---

## Cross-cutting reviewer heuristics

- **Trace the comparator and perspective decisions first.** They are the highest-
  leverage, most-cited weaknesses and they propagate.
- **"Robust" ≠ insensitive.** A conclusion stable within the *actual* uncertainty
  is the goal; outputs that don't move when inputs move indicate a broken model.
- **Separate outputs cleanly.** Reviewer-facing document: clean, rationale-forward.
  Internal register: the full audit trail of findings, deviations, and decision
  rounds. (This mirrors TF-7's non-technical vs technical split.)
- **Cascade corrections** — run the companion-artefact check (Section E). A change
  to a load-bearing decision (comparator definition, framing, perspective) must be
  propagated across protocol, HEAP, briefing, and analysis plan, not patched
  locally.
- **Date-check the standard.** The series is from 2012. Where a jurisdiction rule
  (NICE PMG36), CHEERS 2022, or a superseded method (half-cycle correction)
  applies, layer it on and hand off to `nice-economic-evaluation` as needed.
