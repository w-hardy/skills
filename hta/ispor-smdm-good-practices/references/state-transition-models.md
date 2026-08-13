# State-transition models (TF-3, Siebert et al.)

Source: *Value in Health* 2012;15:812–820. Recommendations III-1 to III-18.
Covers both **cohort ("Markov")** and **individual-level ("first-order Monte
Carlo" / microsimulation)** implementations. For R implementation hand off to
`decision-modelling-hta` (heemod cohort) and `multistate-models-hta`
(continuous-time / individual).

**When an STM is appropriate:** the process can be framed as a set of mutually
exclusive, collectively exhaustive states with transitions among them;
interactions between individuals are not relevant; and (for the cohort form) the
population is a closed cohort. Use an STM rather than a decision tree when you
need time-dependent parameters, time-to-event, or repeated events.

## Contents
- Cohort vs individual-level (III-1)
- Strategy definition; sequential decisions (III-2)
- Starting cohort (III-3)
- Defining states (III-4)
- Capturing the intervention (III-5)
- Homogeneity and heterogeneity bias (III-6)
- Time horizon (III-7)
- Cycle length (III-8)
- Model symmetry / reuse (III-9)
- Data sources (III-10)
- Deriving probabilities: rates vs probabilities, mortality (III-11)
- Intervention effects and confounding (III-12)
- State valuation (III-13)
- Half-cycle correction (III-14)
- Distributions of outcomes (III-15)
- Microsimulation stability (III-16)
- Communicating the model (III-17, III-18)

---

## Cohort vs individual-level (III-1)

**If** the problem fits a *manageable* number of states carrying all relevant
history, **choose a cohort simulation** — it is more transparent, efficient,
easier to debug, and supports specific value-of-information analyses. **If** a
valid representation would need an unmanageable number of states, **use an
individual-level STM.** Crucially: **validity must not be sacrificed for
simplicity.** The trade-offs (from Table 1 of the report): cohort models are
easier to develop/debug/communicate but are memoryless and prone to state
explosion; individual models escape the Markov assumption and handle subgroups
and outcome distributions naturally but cost computation time (which bites during
PSA/VOI) and are harder to debug.

The decisive question is **what must be carried through the model**: all relevant
states *and* all relevant histories (past states, risk factors, time in state,
time since last event) that determine transition probabilities or state values.
Specify these tracker variables before choosing the implementation.

## Strategy definition; sequential decisions (III-2)

Define the strategies clearly. **Sequential decisions must not be embedded inside
the Markov cycle tree** — they belong in the specification of the alternative
strategies that *precede* the Markov tree. (Markov decision processes are the
generalisation that formally embeds sequential decisions; standard STMs do not.)
Dynamic strategies — decision rules to start/stop/switch over time (e.g., switch
drug after first-line failure; lengthen screening interval after repeated
negatives) — are common and usually favour individual-level implementation.

## Starting cohort (III-3)

Define by the demographic and clinical characteristics that affect transition
probabilities or state values (QoL, cost). For a population-based starting
cohort, run per stratum and aggregate.

## Defining states (III-4)

Begin by identifying states reflecting the disease/health process, the
transitions expected *without* intervention, and the intervention's effects on
those. States must be **mutually exclusive** (one state per cycle) and
**collectively exhaustive**. Specification should reflect the biological/
theoretical understanding of the condition.

**History belongs in the state definition** when it matters: if MI risk depends
on prior MI, split into "disease-free, no prior MI" and "disease-free, prior MI".
In an individual STM the same information lives in tracker variables instead, and
transition probabilities are functions of them.

Where natural history can be described by unobservable biological measures (e.g.,
spirometry) *or* by symptomatic/utilisation descriptions, justify the approach or
compare alternatives in SA. Describing natural history purely from health-care
utilisation gives little biological insight and is usually of limited value.

Model competing causes of death without bias (e.g., model probability of death
first, then a conditional distribution over causes).

**Initial / short-term events** are efficiently modelled as a decision tree
preceding the STM, giving the starting cohort appropriate credit for elapsed time
— useful for diagnostic-test pathways, limited-duration treatments, or initial
procedures.

## Capturing the intervention (III-5)

States must adequately capture the intervention *type* (prevention, screening,
diagnosis, treatment) and its benefits and harms. Type-specific notes:
- **Prevention** — represent risk-factor levels as pre-disease states/trackers;
  capture their course and change.
- **Screening** — define states reflecting the underlying disease process
  (do not take an empirical "probability of a positive screen"); distinguish
  screen-detected, incidentally-detected, and symptom-detected cases; describe
  how **lead-time and length bias** were controlled; individualised interval
  screening usually needs an individual STM.
- **Diagnosis** — represent test pathways/outcomes typically in a pre-STM
  decision tree; carry prognostic test results as states/trackers if they change
  over time.
- **Treatment** — make the mechanism explicit (event-risk/mortality reduction,
  slowed progression), specify how harms affect prognosis, use realistic
  adherence assumptions, and handle personalised/dynamic rules via states or
  trackers.

## Homogeneity and heterogeneity bias (III-6)

Each state must be **homogeneous** with respect to both **observed and
unobserved** characteristics that affect transition probabilities. Characteristics
known at decision time and not changing meaningfully can define starting cohorts
rather than states; those that change over time (e.g., accumulating comorbidity)
must enter the state definitions. Variables that affect transitions but are
*unknown* at decision time (genetic mutation, undiagnosed infection) can create
**heterogeneity bias** — consider including them. This is a subtle failure mode
reviewers probe: a state that looks homogeneous but hides an outcome-determining
unobserved variable.

## Time horizon (III-7)

Sufficiently large to capture all relevant health effects and costs. Common
practice: run to age ~120 or until >99.9% dead. If the intervention affects
mortality, use a **lifetime** horizon to capture (quality-adjusted) life-years
from delayed deaths.

## Cycle length (III-8)

Short enough to represent the frequency of clinical events and interventions —
an event should occur **at most once per cycle**. Base the choice on the clinical
problem, remaining life expectancy, and computational efficiency (a monthly-
screening model needs cycles ≤1 month). Shorter cycles give better life-expectancy
approximations, especially for acute disease or older ages; the gain shrinks once
the number of cycles is large.

## Model symmetry / reuse (III-9)

Represent the disease process consistently across strategies. Comparing (say)
catheterisation-guided treatment vs initial medical therapy requires specifying
the *true underlying* disease status even when it is unobserved in one arm —
otherwise SA on the underlying anatomy produces errors. Components reflecting
similar clinical courses should be **built once and linked** throughout, not
recreated per strategy.

## Data sources (III-10)

Transition probabilities and intervention effects from the **most representative**
sources for the decision problem. Natural-history transitions: ideally
population-based epidemiological studies (most representative); trial control arms
are usable but less generalisable; a systematic review / meta-analysis is best
when multiple sources exist. Absent good systematic reviews, provide a detailed
evidence table (including SA ranges) in an appendix.

## Deriving probabilities: rates vs probabilities, mortality (III-11)

Describe all methods and assumptions. Convert transition probabilities between
time units **through rates**, never by rescaling probabilities directly, and
**never present rates as percentages or call probabilities rates**. State the
assumed relationship between disease-specific and background mortality, and
assess the impact — **additive vs multiplicative** hazards can give very
different results.

## Intervention effects and confounding (III-12)

Effectiveness from **observational** sources must be correctly controlled for
confounding (multivariable regression, propensity scoring). **Time-varying
confounding** — confounders that are also intermediate steps on the pathway —
needs special methods (marginal structural models, g-estimation); causal graphs
help state assumptions. RCT efficacy may need adjustment for real-world
compliance. When extrapolating beyond a trial, do **not** apply an all-cause
mortality reduction directly (background mortality rises with age); apply the
relative reduction to disease-specific mortality (conservative) or subtract
life-table mortality from total. Beware **double counting** when both incidence/
event and mortality reductions are applied — validate the model-generated
reductions against clinical estimates.

## State valuation (III-13)

Justify the values assigned to states (utilities for QALYs, costs), preferably on
the basis of theory. This connects to `nice-economic-evaluation` for the value
set / reference-case requirements and to the project's own TOP-to-EQ-5D mapping
choices.

## Half-cycle correction (III-14)

Apply a half-cycle correction to both costs and effectiveness in the **first**
cycle, and also in the **final** cycle when not using a lifetime horizon.
Rationale: if transition timing within a cycle is unknown, assume mid-cycle
transitions; full-reward-at-start overestimates and no-reward underestimates.
**Vintage note:** current practice often prefers within-cycle corrections
(life-table/trapezoidal, or Simpson's rule) or simply shorter cycles; flag this
when the topic is live rather than treating the 2012 wording as the last word.

## Distributions of outcomes (III-15)

For some decisions (e.g., equity), report not just the expected value but the
**distribution** of outcomes — whether a 1-year mean gain is 1 year for everyone
or +3 years for half and −1 for the rest. Distributions come naturally from
individual STMs but can also be derived from cohort models (Markov trace, or
running individuals without trackers).

## Microsimulation stability (III-16)

Simulate enough individuals for **stable** estimates. Assess stability via the
variance across repeated runs at a fixed n — it should be much smaller than the
smallest difference expected between strategies. Variance-reduction techniques
(common random numbers) cut the required n.

## Communicating the model (III-17, III-18)

**III-17** Use non-technical language and clear figures/tables to convey key
structure, assumptions, and parameters. Two diagram types: the **state-transition
("bubble") diagram** and the **Markov cycle tree**. For many-state models, a
single all-states-all-transitions diagram becomes an unreadable tangle — use
simplified or partial diagrams.

**III-18** Present **intermediate outcomes** alongside final ones — 10-year
risks, events per lifetime, share experiencing ≥2 events, mean age at first
event, time spent in key states. These build face validity, aid debugging, and
allow modelled survival/probability curves to be compared directly against
empirical curves (a bridge to external validation in `transparency-and-validation.md`).

## Verification aid specific to STMs

Check that model-building rules (symmetric branches/states) hold, and inspect the
Markov trace with parameters set so the expected trace is predictable (e.g., so
that no individual should ever visit a given state) — a cheap, powerful way to
catch programming errors.
