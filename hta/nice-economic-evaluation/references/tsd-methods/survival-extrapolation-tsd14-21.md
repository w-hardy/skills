# TSD 14 & 21 — Survival analysis and extrapolation (methods)

*Supports PMG36 4.2.24 and the section 4.6 survival-modelling clauses. Use alongside `../modelling-and-uncertainty.md`
and the tool `scripts/survival_extrapolation.R`.*
TSD 14 (standard parametric extrapolation): https://sheffield.ac.uk/media/34225/download —
TSD 21 (flexible methods): https://sheffield.ac.uk/media/34188/download

## The TSD 14 process (the one NICE expects to see)
Survival extrapolation should follow a transparent, justified process — not "pick the lowest
AIC". The expected steps:

1. **Inspect the data** — Kaplan–Meier, number at risk, and the **smoothed hazard** over
   time. The shape of the hazard (monotonic, peaked, turning, bathtub) tells you which
   distributions are even plausible.
2. **Test proportional hazards** between arms (log-cumulative-hazard plot; Schoenfeld
   residuals / `cox.zph`). If PH holds, a single distribution with a treatment covariate may
   be reasonable; if not, **fit arms separately** rather than forcing a shared shape.
3. **Fit the standard parametric set** — exponential, Weibull, Gompertz, log-normal,
   log-logistic, generalised gamma. Compare on **AIC/BIC together with visual fit to the KM**
   and, crucially, **external plausibility** of the extrapolated tail.
4. **Assess external validity** — does the extrapolation agree with long-term registry/trial
   data, expected general-population mortality, and clinical expectation? A fit that implies
   implausible long-term survival (e.g. cure where none exists, or survival exceeding the
   general population) is rejected however good its in-trial AIC.
5. **Apply a background-mortality constraint** — modelled mortality should not fall below
   general-population mortality (cap the hazard at the population life-table hazard). Omitting
   this is a common error that overstates long-term survival.
6. **Carry uncertainty forward** — present several plausible distributions as scenarios (not
   just the best-fit), including a **"no continued treatment benefit"** scenario where curves
   converge after treatment stops (4.2.24), and reflect parameter uncertainty in the PSA.

## When standard parametric models aren't enough (TSD 21)
If the hazard is complex (turning points, long-term survivors / cure, delayed effects) the
six standard distributions may all fit poorly. TSD 21 covers the flexible alternatives:
- **Flexible parametric / spline (Royston–Parmar)** models — splines on the
  log-cumulative-hazard, odds, or normal scale; more knots capture complex hazards.
- **Mixture-cure and non-mixture-cure** models — where a fraction is effectively cured (e.g.
  some immuno-oncology), so survival plateaus toward background mortality.
- **Landmark / piecewise** approaches and **mixture** models for changing hazards.
Justify the added flexibility (don't over-fit), and still check external validity and the
background-mortality floor.

## Things a committee / EAG checks (and common errors)
- **AIC-only selection** with no visual/external check — the single most common criticism.
- **Pooling arms / assuming PH** without testing it.
- **No background-mortality cap**, giving implausible tails.
- **A single chosen curve** with no scenario range and no "no continued benefit" case.
- **Standard distributions forced** onto a plateauing/curing hazard where a cure or spline
  model is indicated.
- **Restricted mean survival** not reported — useful and less assumption-laden than a point
  on the tail for comparing fits.
- Choosing the curve that maximises the technology's benefit without justification.

## Reporting
Hazard and KM-vs-fit plots per arm; AIC/BIC table; the PH assessment; the external-validity
argument and data used; the background-mortality treatment; and the set of extrapolation
scenarios taken to the model.
