# Discrete event simulation (TF-4, Karnon et al.)

Source: *Value in Health* 2012;15:821–827. Recommendations IV-1 to IV-24.
For R implementation (simmer) hand off to `discrete-event-simulation-hta`.

**Core concepts:** entities (usually patients; also carers, organs, signals),
attributes (features carried by an entity — age, sex, history, accumulated
cost/QoL), events (things that happen to an entity or environment), resources
(objects that serve entities, possibly with limited capacity), queues (when a
resource is occupied — FIFO, LIFO, or priority), and time (an explicit
simulation clock that jumps from event to event). Two further ideas: interaction
(entities competing for a resource) and emergent behaviour (system-level
behaviour such as spontaneous overcrowding).

## Contents
- When to use DES (IV-1)
- Constrained-resource outcomes (IV-2, IV-3)
- Downstream decisions (IV-4)
- Parameter estimation and expert elicitation (IV-5–IV-7)
- Clinical guidelines are not always applied (IV-8, IV-9)
- Competing events (IV-10)
- Continuous disease parameters (IV-11)
- Implementation: submodels, structures, blocking, outputs (IV-12–IV-15)
- Software choice (IV-16)
- Analysis: stability, optimisation, uncertainty (IV-17–IV-21)
- Warm-up / preload (IV-22)
- Representing and reporting (IV-23, IV-24)

---

## When to use DES (IV-1)

DES is the natural choice when the problem involves **constrained/limited
resources** — the problem class it was built for. It is also attractive in
*non-constrained* models when: there are interactions between individuals,
populations, or their environment; time-to-event is better described
stochastically than with fixed intervals and time dependencies matter; individual
pathways depend on multiple entity characteristics; or recording individual entity
experience is desirable. DES handles multiple/competing risks well because its
treatment of time makes optimal use of time-to-event data (a short-cycle STM can
approximate this but pays in run time by checking every event every cycle).

Two application classes in health care: **non-constrained-resource** (unusual
elsewhere but required here to match the standard health-economic assumption that
resources are always available) and **constrained-resource** (capacity limits,
queues, priority by attribute). Agent-based modelling is described as an
extension of DES for richer direct interactions between agents.

## Constrained-resource outcomes (IV-2, IV-3)

**IV-2** Constrained-resource models must consider the effect of strategies on
**health-related outcomes**, not only throughput/utilisation/capacity; omitting
health outcomes must be justified. The point of health systems is health.

**IV-3** Model constrained resources when **(1)** levels of access are altered
(e.g., higher referral rates → longer waits) **and (2)** time to access has
significant effects on cost or outcomes (e.g., surgery). Identify the events for
which entities may not have immediate access and therefore queue.

## Downstream decisions (IV-4)

If downstream decisions can significantly affect differences in cost/outcome,
structure the model to allow analysis of alternative downstream decisions. At
each decision point decide whether to *parameterise* the probabilities of
alternative decisions or to *evaluate combinations* of decisions.

## Parameter estimation and expert elicitation (IV-5–IV-7)

DES facilitates complex structures and so is data-hungry. Options when data are
missing: desist (if the gap is extensive); keep the structure and **calibrate**
missing values (represent the calibration uncertainty in SA — there is no unique
input set reproducing a set of targets); or eliminate the data-hungry sections
(assessing first, ideally by running the original model over a credible range,
whether the reduced model still gives sufficient insight).

- **IV-5** If parameters are elicited from experts, **represent the uncertainty**
  around elicited values and **validate** them — e.g., ask experts also to
  estimate a quantity you *can* check empirically, and cross-check across
  independent experts. Established elicitation methods provide transparency.
- **IV-6** If confidence in elicited values is low, treat the analysis only as a
  starting point for what-if analyses and for estimating the value of collecting
  more data.
- **IV-7** If structure is modified because of data constraints, analyse the
  modification's effects and present the likely size and direction of the induced
  additional uncertainty.

## Clinical guidelines are not always applied (IV-8, IV-9)

**IV-8** When modelling clinical practice, do **not** assume relevant guidelines
are actually followed — guideline uptake varies, and demonstrating the cost/
benefit of adherence may be the model's very purpose. **IV-9** Base clinical/
administrative decision algorithms ideally on analyses of observed decisions; if
infeasible, develop them with relevant personnel and validate against routinely
collected data.

## Competing events (IV-10)

When estimating times to competing events, methods that estimate the timing of
competing events **jointly** are preferred to fitting separate time-to-event
curves per event. Two approaches: (1) sample a separate time for each event and
take the earliest — easy to parameterise and fit; (2) sample a single time to
next event, then sample the event type (e.g., multinomial) — harder to fit but
gives a more accurate description of the uncertainty because times are jointly
estimated. (Note: competing-risk models are only needed when the competing risks
are *not* represented in the DES, since a new time can be resampled for
non-first events.) This mirrors TF-1's consolidated IV-5 wording about
representing correlation between competing events.

## Continuous disease parameters (IV-11)

When the likelihood of discrete events depends on a continuous measure (HbA1c →
complications; tumour size → presentation), prefer defining progression and event
likelihood **jointly** to preserve the discrete-event nature: sample the level at
which an event occurs, then sample the time to reach that level — rather than
stepping a continuous variable forward in fixed time checks. The joint approach
keeps time moving event-to-event rather than in fixed cycles.

## Implementation: submodels, structures, blocking, outputs (IV-12–IV-15)

- **IV-12 Submodels.** Group related logic into submodels for transparency and
  easier debugging (each tested separately; identical code not verified twice).
  When comparing strategies within one system, define **common submodels once and
  call them from each strategy** — this also guarantees consistent implementation
  across strategies and eases updating. (Directly analogous to STM III-9.)
- **IV-13 Structural SA.** Implement alternative structures **within a single
  DES**, not as separate models — this reduces programming errors (shared code)
  and nuisance variance (common random numbers on shared submodels).
- **IV-14 Blocking events.** Guard against inadvertently blocking events (e.g.,
  suspending stroke risk while a patient is in hospital for something else);
  ongoing risks must remain active over the relevant horizon.
- **IV-15 Outputs.** Implement only the outputs needed for validation and final
  analyses: store as **attributes** if individual-level data are required,
  otherwise collect **aggregated** values via global variables to reduce the
  simulation burden.

## Software choice (IV-16)

Choose between a **general programming language** (C, R, Fortran — more
flexibility, faster execution, less proprietary dependence, but you code and
debug the basic machinery) and **dedicated DES software** (modelling efficiency,
automated structure, transparency, animation — at some cost in flexibility and
speed). **Spreadsheets are generally inappropriate** for DES (their
calculate-everything-simultaneously model fights the sequential nature of DES)
and should not be used without justification.

## Analysis: stability, optimisation, uncertainty (IV-17–IV-21)

- **IV-17 Stability.** Test output stability across independent runs with
  different random-number seeds; identify the number of entities, replication
  duration, or replications needed so the output distribution is stable (e.g.,
  <5% or <1% difference across runs).
- **IV-18 Variance reduction.** Recommended; balance simple techniques (extending
  runs, matching baseline characteristics, common random numbers) against more
  sophisticated methods, trading coding time against run-time/accuracy gains.
  Common random numbers also aid debugging (a strategy-independent event should
  have identical timing for the same patient across strategies).
- **IV-19 Many strategies / structural assumptions** → **factorial design** and
  **optimum-seeking** approaches (2^k runs; fractional factorial when k is large;
  iterative optimisation with a stopping rule).
- **IV-20 Constrained PSA run time** → estimate empirically the optimal
  combination of run size (per parameter set) and number of parameter sets to
  optimise output precision (ANOVA-based formulae exist).
- **IV-21 Computing time precludes full representation** → **meta-modelling**
  (regression/Gaussian-process emulator of outputs as a function of inputs),
  which also speeds PSA and EVPI.

## Warm-up / preload (IV-22)

If the system is **not empty** at the start (e.g., an established clinic with
patients already waiting), use a **warm-up** period to build the system up to the
starting point — provided key parameters can reasonably be assumed constant over
time, or their history can be incorporated. A warm-up doubles as validation (can
the model create realistic starting conditions?). Otherwise, **preload** entities
with ready-made histories (appropriate when based on an empirical dataset of
current status).

## Representing and reporting (IV-23, IV-24)

- **IV-23 Animation.** Animated representation of events experienced by
  individuals is recommended — humans spot pattern and illogical movement
  visually, which aids user engagement, debugging, and face validation.
- **IV-24 Diagrams.** Report **both** general (flow diagrams / state charts:
  pathways, logic/causal relationships, queues, decision points) **and** detailed
  representations (module/event documentation of actions before/during/after each
  event; variable and attribute lists with update timing) — enough for a reader
  to replicate the model, and a benefit to the modeller returning after a break.
