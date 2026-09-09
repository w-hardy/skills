# Value of information: EVPI, EVPPI, EVSI

> Sources: *R for Health Technology Assessment* (Baio et al., online at
> <https://gianluca.statistica.it/books/online/r-hta/>) — Ch. 1 §1.8 (VOI): §1.8 EVPI defined
> max-then-mean as `E_θ[max_d NB_d(θ)] − max_d E_θ[NB_d(θ)]`; §1.8.2 EVPPI; §1.8.3 EVSI; §1.8.4
> ENBS and population VOI (per-year incident population discounted at ~3.5%, 5/10/20-year
> horizons; ENBS = population EVSI − study cost, Conti & Claxton); §1.8.5 recommends the `voi`
> package (Heath, Kunst & Jackson — <https://chjackson.github.io/voi/>). Regression-based EVPPI
> is due to Strong, Oakley & Brennan (2014, *Medical Decision Making*); the EVSI regression
> shortcut to Strong et al. (2015) and Heath et al. *Bayesian Value of Information* methods.
> *Bayesian Cost-Effectiveness Analysis with BCEA* (Baio, Berardi & Heath 2017). Accessed
> 2026-07-03; anchors are section-level.
> Also *Bayesian Models in Health Technology Assessment* — Baio (CRC Press, published 7 August
> 2026), Ch. 12, read and verified against the online edition
> <https://gianluca.statistica.it/books/online/bmhta/> on 2026-09-09 — §12.3 (EVPI and opportunity
> loss, Eq 12.2, Table 12.1), §12.4 (EVPPI, Eq 12.3; GAM/GP/BART; the Info Rank plot), §12.5 with
> Example 12.2 (EVSI, ENBS and the chemotherapy sample-size comparison). Earlier anchor:
> which supplies the EVPPI method comparison (GAM/GP/BART), the Info Rank plot, and the ENBS-based
> sample-size material below; anchored to the companion code at
> <https://github.com/giabaio/bmhta-examples> (MIT) commit `d2a6298`, file `12-voi/voi.R`, accessed
> 2026-09-09. CRAN was not reachable from the authoring environment, so `voi`/`BCEA` argument names
> below are as observed in that working code — check against the installed version.

VOI answers the question the CEAC raises but cannot answer: **is the decision uncertainty worth
paying to reduce?** A CEAC of 0.6 does not say whether more research is valuable — a decision
can be uncertain but insensitive (any plausible resolution picks the same strategy) or nearly
certain but hugely consequential. VOI puts a monetary ceiling on research value.

## EVPI — expected value of perfect information

Per-draw opportunity loss: with NB_s(θ_i) the net benefit of strategy s at draw i,

- decision under uncertainty: pick s* = argmax_s mean_i NB_s(θ_i);
- perfect information: at each draw pick the best strategy for that draw.

**EVPI(λ) = mean_i [ max_s NB_s(θ_i) ] − max_s [ mean_i NB_s(θ_i) ]**

This is the max-then-mean minus mean-then-max orientation stated in R-HTA §1.8. Three lines of
R on the draws matrix; no refitting. Properties worth remembering: EVPI ≥ 0
always; it peaks near the λ where the CEAF switches strategy; per-person EVPI in £ is only
interpretable after population scaling (below).

**The opportunity-loss route is the same number, and often the more useful one to show.** For each
draw, the loss from having acted on current information rather than perfect information is

```
OL_i = max_s NB_s(θ_i) − NB_{s*}(θ_i)
```

where `s*` is the strategy chosen under current information (fixed across draws — that is the
point). Then `EVPI = mean_i OL_i`, numerically identical to the formula above. Computing both is a
cheap check that the implementation is right. The OL decomposition is also more interpretable: it
is zero on every draw where the current choice happens to be optimal, so `mean(OL > 0)` is the
probability of making the wrong decision, and the size of the non-zero losses says how much that
error costs. A decision can be frequently wrong but cheaply wrong, which is exactly the case where
the CEAC looks alarming and research is not worth funding.

## EVPPI — which parameters drive the uncertainty

EVPPI for a parameter subset φ is the value of learning φ perfectly while the rest stays
uncertain: mean over φ of the max over strategies of the conditional expected NB, minus the
current-information maximum. The naive computation is a nested Monte Carlo; the standard
practical estimator is **regression-based** (Strong–Oakley–Brennan): regress per-draw NB (or
per-draw incremental NB, for two strategies) on the φ draws with a flexible smoother (GAM for
1–2 parameters; GP regression for larger sets), and read EVPPI from the fitted values:

EVPPI ≈ mean_i [ max_s ĝ_s(φ_i) ] − max_s [ mean_i ĝ_s(φ_i) ]

where ĝ_s is the regression fit of NB_s on φ. This needs only the existing PSA draws — one
reason to store parameter draws alongside cost/effect draws. BCEA (`evppi()`) and the `voi`
package implement it. Use EVPPI to *rank* parameter groups (e.g. relapse probabilities vs
utilities vs unit costs): it tells you which research design (RCT extension, utility study,
costing study) attacks the uncertainty that matters.

The PSA parameter matrix that the regression needs is extracted with `BCEA::createInputs()`, which
returns the S × Q matrix of parameter draws alongside the model object — the step people miss when
they have a `bcea` object but no parameter draws to regress on. (That signature comes from BCEA's own
documentation rather than Ch. 12, which says only that a `bcea` object is already in the right shape
to hand to `voi::evppi()`.)

### Choosing the regression method

The smoother is not a detail; it is what the estimate *is*. Three are in common use and they suit
different situations:

| Method | Suits | Watch for |
|---|---|---|
| **GAM** (`gam`) | 1–4 focal parameters, smooth response surface | Degrades quickly as the number of parameters grows — the tensor-product basis explodes and the fit oversmooths |
| **Gaussian process** (`gp`) | Moderate numbers of parameters, strongly non-linear surfaces | Cost is roughly cubic in the number of draws; usually fitted on a subsample, so check the answer is stable across subsamples |
| **BART** (`bart`, via `dbarts`) | Many focal parameters, interactions, no assumed smoothness | An ensemble of shallow trees, so the fitted surface is piecewise constant; needs enough draws for the ensemble to average out |

The practical rule: start with GAM for a handful of parameters, move to GP or BART when the group is
large or the EVPPI comes back implausibly close to zero or to the EVPI. Both failures are usually
the smoother, not the model — an oversmoothed fit flattens `ĝ_s` and drives EVPPI toward zero, while
an overfitted one chases noise and drives it toward EVPI. **EVPPI is bounded above by EVPI and below
by zero; a result at either boundary is a diagnostic, not a finding.** Where the choice matters,
report EVPPI under more than one smoother rather than picking silently.

### Info Rank

`BCEA::info.rank()` computes single-parameter EVPPI for *every* parameter and plots them as a ranked
bar chart. It is the right first move in a VOI analysis: cheap, and it tells you which handful of
parameters are worth a proper grouped EVPPI. Two cautions that must be stated whenever it is shown:

- **EVPPI is not additive.** The EVPPI of a group is not the sum of its members' individual EVPPIs,
  and can be larger or smaller depending on how the parameters interact in the net benefit. Info
  Rank orders candidates; it does not decompose the EVPI into shares.
- A parameter can rank low individually and matter a great deal jointly with another. Use the
  ranking to choose groups to test, then compute grouped EVPPI properly.

## EVSI — expected value of sample information

The value of a *specific study* of size n: simulate study data from the model, update, and value
the updated decisions (R-HTA §1.8.3). Costly to compute (moment-matching and regression
shortcuts exist — Heath et al.); R-HTA §1.8.5 points to the **`voi`** package (Heath, Kunst &
Jackson; <https://chjackson.github.io/voi/>) as the current implementation for EVPPI and EVSI.
In practice reserve EVSI for when EVPI/EVPPI have already shown material value and a concrete
study design is on the table. For most reports, EVPI + EVPPI is the right depth.

EVSI is computed for a *specific* design — which parameters the study would inform, and with what
sample size — so it is naturally evaluated over a grid of candidate sizes. Plotted two ways it
answers two different questions: EVSI against the willingness-to-pay threshold, with EVPPI and EVPI
overlaid, shows the bounds (`EVSI(n) ≤ EVPPI ≤ EVPI`, with EVSI rising toward the EVPPI of the
parameters the study informs as n grows); EVSI against sample size at a fixed threshold shows the
diminishing marginal return that makes the design question interesting.

The `voi` package is the current implementation for both EVPPI and EVSI. Its EVSI objects carry the
value across the sample-size grid, which is what the ENBS step below consumes.

## Population scaling — where VOI becomes a decision

Per-person EVPI is compared to research costs only after scaling to the population the decision
covers:

**Population EVPI = per-person EVPI × Σ_t I_t / (1+r)^t**

with I_t the incident/prevalent population affected in year t over the decision's relevant
horizon (how long the information stays useful — typically until the technology or evidence
base changes), discounted at rate r. R-HTA §1.8.4 works this with the per-year incident
population discounted at the ~3.5% NICE rate over 5/10/20-year horizons, and defines the
**expected net benefit of sampling (ENBS) = population EVSI − study cost** (Conti & Claxton).
State I_t, the horizon and r explicitly; they usually move the answer more than the per-person
number does. Decision rule: research is potentially worthwhile only if population EVPI (and then
the relevant EVPPI/EVSI, net of study cost via ENBS) exceeds its cost — otherwise "more research
is needed" is not a defensible conclusion of the CEA.

## Designing the study: ENBS and sample size

This is where VOI stops being a diagnostic and becomes a design tool, and it is the most
decision-relevant thing in the whole VOI ladder.

**Expected net benefit of sampling** nets the value of the information against what it costs to get:

```
ENBS(n) = population EVSI(n) − cost of the study at size n
```

with study cost typically a fixed setup component plus a per-patient component, and the population
scaling exactly as above (incident population, horizon, discount rate). `voi::enbs()` takes an EVSI
object plus the cost assumptions and returns ENBS across the sample-size grid, with intervals.

**Choose n to maximise ENBS, not to hit 80% power.** These give different answers, and the
difference is the point:

- A power calculation asks: how many patients make a statistical error rate acceptable? It is framed
  in Type I/II error, has no notion of what the decision is worth, and is indifferent to whether the
  treatment costs £200 or £200,000 per patient.
- ENBS asks: how many patients maximise the expected monetary value of the decision, net of what the
  trial costs? It is framed in the same currency as the decision itself.

In the source's chemotherapy example (§12.5.1, Ex 12.2) the power-based design — ~190 per arm for
80% power — is well short of the ENBS-maximising size of ~450 per arm; at a £20,000 threshold the
two are worth about 77.1m and 84.1m, so the conventional calculation gives away roughly 7m of
expected value. The extra patients are worth funding because the decision is valuable enough to
justify them. The gap runs the other way just as often: where the
decision has low value, ENBS can be **negative at every sample size**, which is the defensible way to
say a trial should not be run at all. A power calculation can never return that answer.

Report ENBS with its uncertainty (the `voi` output carries intervals), and report the ENBS-optimal n
alongside the power-based n rather than instead of it — reviewers and funders expect the power
number, and the comparison is the argument.

Two honest caveats. ENBS is only as good as the study-cost assumptions and the population scaling,
both of which are usually cruder than the health-economic model itself, so present it across a range
of cost assumptions. And the ENBS-optimal design is optimal *given the current model*: it inherits
every structural assumption the model makes, including the ones the proposed study is meant to test.

## Review checklist

- Draws paired and on the NB scale before any max/mean; imputation blocks kept intact.
- max-then-mean vs mean-then-max order correct (the single most common EVPI bug: swapping them
  gives 0 or a negative number).
- EVPPI: smoother flexibility justified (GAM defaults are fine for 1–2 φ; GP or INLA-based for
  groups); reported per parameter *group*, not only single parameters.
- Population scaling stated with horizon, incidence and discount rate; not silently lifetime.
- VOI computed at the decision-relevant λ (or a small set), not only at the CEAC's prettiest
  point.
- EVPPI smoother named (GAM/GP/BART) and a result at 0 or at the EVPI treated as a diagnostic
  rather than reported as a finding.
- Info Rank, if shown, accompanied by the non-additivity caveat.
- ENBS, if used for a design recommendation, reported with its study-cost assumptions, its
  population scaling, and the power-based n for comparison.
