---
name: discrete-event-simulation-hta
description: "Design, build, and review discrete event simulation (DES) models for health economic evaluation in R, primarily with the simmer package. Use whenever the person is doing individual-level, continuous-time event-based simulation for cost-effectiveness where event history matters: entities moving through a care pathway via timed events, repeating/competing events, time-to-event sampling, resource/capacity constraints and queues, or a microsimulation that must remember an individual's past. Trigger on phrases like \"discrete event simulation\", \"DES\", \"simmer\", \"event-based simulation\", \"microsimulation with memory\", \"patient pathway simulation\", or \"model that depends on full event history\". Also trigger when deciding between DES and a state-transition / multistate model. For a Markov/multistate cohort where current state plus time-in-state is sufficient, prefer multistate-models-hta or decision-modelling-hta; reach here when the memoryless property is the obstacle, or resources/queues must be modelled."
---

# Discrete event simulation for HTA

Individual-level, continuous-time, event-based simulation for economic evaluation, in R, following R-HTA chapter 12.

> Sources: *R for Health Technology Assessment* (Baio et al., online at <https://gianluca.statistica.it/books/online/r-hta/>) — chapter mapping verified against the live ToC (Ch. 12 = discrete event simulation), accessed 2026-07-03. `simmer` signatures cross-checked against the r-simmer.org reference docs and changelog, accessed 2026-07-03 — including the deprecation of `set_attribute(global = TRUE)` in favour of `set_global()`. DES models a system as a sequence of discrete *events* and the time gaps between them, for individual *entities* (patients), each carrying *attributes* that can record and depend on their full history. The implementation focus is the **`simmer`** package (process-based, C++-backed); base-R, `flexsurv`, `gems`, and `descem` are alternatives.

## When DES is the right tool (and when it isn't)

DES is not automatically better than a state-transition model — it's the right choice for specific reasons, and overkill otherwise. Reach for DES when:

- **Event rates depend on prior history** — the decisive case. State-transition models are memoryless (Markov); a cohort Markov model can't make the rate of event C depend on *when* events A and B happened, only on the current state. DES records prior events per individual, so history-dependent rates are natural. (Semi-Markov multistate models capture time-in-*current*-state; DES captures arbitrary history.) If the memoryless property is your obstacle, that's the signal.
- **Avoiding state explosion** — co-occurring conditions or many attribute combinations would force a Markov model to proliferate states; DES adds an attribute instead of multiplying states, keeping the model parsimonious.
- **Resources and queues matter** — explicit capacity constraints (clinician availability, ward beds, scanner slots) with patients queuing. State-transition models can't represent this; DES (via `simmer`'s `seize`/`release`) can. Most HTA models don't need this (scarcity is proxied by the cost-effectiveness threshold), but when it's the question, DES is one of the few options.
- **Continuous time / time-varying rates** — no discrete-cycle approximation error, no problem of multiple events colliding in one cycle, and a natural fit to time-to-event data.
- **Computational efficiency with sparse events** — DES only computes when an event occurs; a discrete-time microsimulation computes every cycle even when nothing happens, so DES wins as cycles shorten or events are rare.

Don't reach for DES when a cohort Markov or a `hesim` multistate model already captures the structure — DES costs more to build, is slower for regulators to review, and (because it's hand-coded in a specific package) is less transparent. That review/transparency cost is a genuine HTA barrier, not just an inconvenience. Use the simplest model that captures the decision-relevant dynamics. For the state-transition alternatives, see `decision-modelling-hta` (cohort Markov) and `multistate-models-hta` (continuous-time / individual-level multistate via hesim) — the latter is the natural step *below* DES, and the right default unless you specifically need full event history or resources.

## The simmer model: two objects

A `simmer` DES is built from a **trajectory** (what can happen to an individual) and a **simulation environment** (who enters, when, and what's monitored). See `references/simmer-implementation.md` for the full worked pattern; the essentials:

**Trajectory** (`trajectory()`), built from five blocks:
- **Attributes** (`set_attribute`/`get_attribute`, `set_global`/`get_global`) — per-individual (or global) numeric storage: characteristics, sampled time-to-events, accumulating costs/QALYs. This is the "memory" that distinguishes DES.
- **Timeouts** (`timeout`, `timeout_from_attribute`) — the delay to the next event, i.e. a sampled time-to-event.
- **Branches** (`branch`) — fork into sub-trajectories, the standard way to implement competing events and decisions.
- **Rollbacks** (`rollback`) — jump back N steps to repeat a section (e.g. treatment cycles).
- **Resources** (`seize`/`release`, with `add_resource`) — capacity-constrained assets; only needed when modelling queues.

**Environment** (`simmer()`): `add_generator()` creates the cohort (use `at(rep(0, n))` to start everyone at t=0, as is usual for HTA), `mon = 2` enables attribute monitoring, `run()` executes, and `get_mon_attributes()` / `get_mon_arrivals()` extract long-format logs to summarise into per-individual costs and QALYs.

One `simmer` gotcha worth stating up front: the trajectory often references the environment object by a hard-coded name (e.g. `sim`), so the environment must be named to match; and `set_attribute(global=TRUE)` is deprecated — use `set_global()`.

## Competing events — a real modelling decision, not a default

When several events compete (recurrence vs death, cancer death vs other-cause death), how you simulate them is a substantive choice that must match how the data were analysed. Four strategies (Barton et al., Karnon et al.):

1. **Simulate a time for every competing event, take the earliest** — sample t for each event, the minimum wins and determines which event occurred. Robust with censored data. *(The book's colon case study uses this.)*
2. **Sample the event first, then its time** — event-specific probabilities pick the event, then draw from that event's time distribution. Simple and good performance on uncensored data, but awkward under censoring.
3. **Sample the time first, then the event** — draw from a *combined* all-events time distribution, then pick which event via (e.g.) multinomial logistic. The general recommendation — but only valid if the combined distribution properly captures any **multimodality** from differing event timings (use a mixture or spline, not a naive single parametric).
4. **Discretised cyclic probabilities** — mimic a discrete-time Markov model; available but forfeits DES's continuous-time advantage.

The choice is driven by **censoring and data characteristics**, and it dictates how the input data must be analysed — decide it *before* fitting the time-to-event models, not after. See `references/competing-events-and-uncertainty.md`.

## The four kinds of variation — keep them distinct

Individual-level models expose four types of variation/uncertainty that must not be conflated (Briggs et al.):

- **Heterogeneity** — differences *explained by* individual characteristics (age, stage, biomarker). Modelled by varying attributes/distribution parameters across individuals. The main *reason* to use individual-level modelling.
- **Stochastic (first-order) uncertainty** — random variation between *identical* individuals (two patients with the same parameters still get different sampled event times). Specific to individual-level models; requires *enough simulated individuals* for the mean to converge.
- **Parameter (second-order) uncertainty** — uncertainty in the estimated parameter values themselves (finite samples). Handled by probabilistic analysis: resample parameters from their distributions. Correlated distribution parameters (e.g. Gompertz shape/rate) must be sampled *jointly* (MVN or bootstrap), exactly as in the survival/multistate skills.
- **Structural uncertainty** — uncertainty from modelling assumptions (structure, chosen distributions). No gold standard; explore via scenario analysis.

The trap is mixing the first two: enough individuals kills *stochastic* noise but does nothing for *parameter* uncertainty — you need PSA-style resampling for that, *and* enough individuals within each PSA iteration. Two nested loops. See `references/competing-events-and-uncertainty.md`.

## Discounting in continuous time

DES handles discounting either way, and you can mix within one model: discrete discounting for things that occur at points (`NPV = V/(1+r)^t`), continuous discounting integrated over a period for things that accrue (`cNPV = ∫ V/(1+r)^x dx`) — QALYs accruing over a sojourn are naturally continuously discounted, while a one-off treatment cost is discounted at its time point. Continuous is the more natural default in DES since membership isn't simulated over cycles. Differential rates for costs vs effects are supported (the book uses 4%/1.5% for a Dutch example). For the rates and conventions a given HTA body expects, defer to the **`nice-economic-evaluation`** skill.

## Reproducibility

DES is random-number-heavy. `set.seed()` before each strategy's run gives reproducibility *and* reduces unwarranted between-strategy variation (common random numbers). But seeding must not kill the variation you *want* — e.g. between PSA iterations. Be deliberate about where seeds go.

## Feeding DES from the other skills

DES consumes the same upstream inputs as the state-transition models: time-to-event distributions fitted per event (the `survival-analysis-hta` skill — splines, cure models, and the joint-parameter sampling for PSA all apply), and relative effects from a network synthesis (the `network-meta-analysis-hta` skill). The difference is purely on the simulation side: DES samples individual event times from those distributions and lets history accumulate, rather than converting them to cohort transition probabilities. Outcomes feed a CEA the same way (e.g. `calculate_icers` / BCEA), with the same probabilistic-base-case expectation from `nice-economic-evaluation`.

## Common pitfalls

- **Using DES when a multistate model would do.** The added build cost and reduced transparency are real HTA review burdens; justify DES by a concrete need (history dependence, resources, state explosion), not preference.
- **Conflating stochastic and parameter uncertainty.** More individuals ≠ parameter uncertainty handled. You need both: enough individuals (stochastic) *and* parameter resampling (PSA), nested.
- **Too few simulated individuals.** Stochastic noise leaves the mean outcomes unconverged; non-linear models still need the expectation to be stable. Check convergence of mean costs/QALYs as n grows.
- **Picking a competing-events strategy after fitting the survival models.** The strategy dictates how the data must be analysed (combined vs event-specific distributions, multimodality handling) — choose it first, driven by censoring.
- **Naive single distribution for the combined time in strategy 3.** If event timings differ, the combined distribution is multimodal; a single parametric misfits it — use a mixture or spline.
- **Seeding away wanted variation.** Common random numbers across strategies is good; the same seed collapsing PSA iterations is a bug.
- **Forgetting correlation when resampling distribution parameters.** Shape/rate (etc.) are correlated; sample jointly, as in the survival/multistate skills.
- **Opaque, package-locked models.** A DES is only as useful to a reviewer as it is readable; document the trajectory logic and custom functions, and validate (e.g. record overall survival independently and check it against the component event times).

## Validating model decisions before building

`scripts/check_des_setup.R` is a decision/structure checker rather than a data validator (the model is hand-built code, not a single object): given the events, whether they're competing, the censoring situation, the chosen competing-events strategy, the number of simulated individuals, and the uncertainty handling, it flags mismatches — e.g. a competing-events strategy that's a poor fit for censored data, strategy 3 without a multimodality-capable combined distribution, parameter uncertainty declared "handled" with no PSA loop, an individual count that's likely too low, or DES chosen where the stated dynamics don't actually need it. Run it at the design stage, before writing the trajectory.
