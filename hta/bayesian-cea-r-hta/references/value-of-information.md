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

## EVSI — expected value of sample information

The value of a *specific study* of size n: simulate study data from the model, update, and value
the updated decisions (R-HTA §1.8.3). Costly to compute (moment-matching and regression
shortcuts exist — Heath et al.); R-HTA §1.8.5 points to the **`voi`** package (Heath, Kunst &
Jackson; <https://chjackson.github.io/voi/>) as the current implementation for EVPPI and EVSI.
In practice reserve EVSI for when EVPI/EVPPI have already shown material value and a concrete
study design is on the table. For most reports, EVPI + EVPPI is the right depth.

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

## Review checklist

- Draws paired and on the NB scale before any max/mean; imputation blocks kept intact.
- max-then-mean vs mean-then-max order correct (the single most common EVPI bug: swapping them
  gives 0 or a negative number).
- EVPPI: smoother flexibility justified (GAM defaults are fine for 1–2 φ; GP or INLA-based for
  groups); reported per parameter *group*, not only single parameters.
- Population scaling stated with horizon, incidence and discount rate; not silently lifetime.
- VOI computed at the decision-relevant λ (or a small set), not only at the CEAC's prettiest
  point.
