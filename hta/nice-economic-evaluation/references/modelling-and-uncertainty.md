# Modelling methods and uncertainty (4.6–4.7)

*Source: PMG36 — NICE technology appraisal and highly specialised technologies guidance:
the manual, as amended 31 March 2026, chapter 4, sections 4.6–4.7.
<https://www.nice.org.uk/process/pmg36>. Verified 3 July 2026 at section level; individual
sub-clause numbers within 4.6–4.7 (other than 4.6.1–4.6.2) could not be re-verified against
the live manual, so this file cites the section and names the topic — confirm the exact
sub-clause in the live manual before quoting one in a submission.*

These methods are not in Table 4.1 but are part of what makes an analysis acceptable to a
NICE committee. Weak handling of uncertainty is one of the most common reasons a committee
discounts an otherwise reference-case-aligned model.

> Most issues here are **method-choice** issues with a specific DSU TSD behind them —
> survival extrapolation (TSD 14, 21), treatment switching (TSD 24), surrogates (TSD 20),
> model structure (TSD 13, 19, 15), evidence synthesis / indirect comparison (TSD 1–7, 17,
> 18). When flagging one, name the TSD from `tsd-index.md` so the user has the route to fix it.

## Modelling methods (4.6)

- **Documentation and justification.** Structural assumptions and data inputs must be fully
  justified and clearly documented; alternative plausible assumptions/inputs require
  sensitivity analyses (4.6.1). It is not enough to say a structure was used in a previous
  published model (section 4.6).
- **Conceptual model.** The process used to choose the model structure should be
  transparent, including how clinical experts were involved (number, how chosen, nature of
  involvement) (section 4.6).
- **Quality assurance and validation.** Describe QA methods and present model validation
  (face, internal/technical, external, cross-validation where possible) (section 4.6).
- **Endpoints and surrogates (section 4.6).** Prefer final clinical endpoints reflecting
  how a patient feels, functions or survives. Where a surrogate is used, establish the
  surrogate-to-final relationship with appropriate evidence (ideally meta-analytic /
  trial-level association, e.g. TSD 20 bivariate methods), show biological plausibility,
  and justify any extrapolation of a surrogate relationship to a different
  population/technology. Surrogate validity is specific to population and intervention.
- **Survival / time-to-event modelling (section 4.6).** Synthesis of survival outcomes
  needs individual patient data; where only published curves exist, reconstruction methods
  (e.g. Guyot et al. 2012) can be used. Do not assume proportional hazards — test it; where
  it does not hold, fit and compare alternative parametric models and justify the chosen
  extrapolation against external/long-term evidence and plausibility.
- **Treatment switching / crossover (section 4.6).** Where control-group patients switch to the
  active treatment and ITT is inappropriate, use recognised statistical adjustment methods
  (e.g. RPSFT, IPCW, two-stage) rather than naive censoring/exclusion; justify the choice.
- **Evidence synthesis (section 4.6).** Methods to identify and synthesise data should be
  systematic and justified; where outcomes are related, consider joint/structured synthesis.
  Validate model assumptions with clinical experts where appropriate.

## Exploring uncertainty (4.7)

A reference-case-aligned analysis quantifies **decision uncertainty** — the probability that
a different decision would be made if the true cost effectiveness were known (section 4.7). Three
distinct sources of uncertainty must each be addressed:

1. **Structural uncertainty.** Assumptions about how the model is built
   (health-state definitions, care pathways, extrapolation form). Document them and explore
   with **scenario analyses** over a representative range of plausible alternatives. Where
   feasible, parameterise structural uncertainty within the probabilistic model (e.g. model
   averaging), documenting any weights/expert input. Implausible scenarios are only useful
   to show robustness.
2. **Source / data-choice uncertainty.** Which dataset feeds key parameters
   (costs, utilities, relative effect, its duration). Re-run with alternative sources or
   excluding doubtful studies, and report separately. Use this where alternative utility
   sets exist, costs vary between sites, or a study's quality/relevance in a meta-analysis
   or NMA is doubtful.
3. **Parameter precision.** Uncertainty around the mean inputs, handled with
   **probabilistic sensitivity analysis (PSA)**: assign evidence-justified distributions
   (not arbitrary) to mean parameters; use formal elicitation where data are lacking.

### What a committee expects to see
- A base-case PSA with mean results and a measure of decision uncertainty
  (cost-effectiveness acceptability curve / probability cost-effective at £20k–£30k... i.e.
  at the relevant thresholds; scatter on the cost-effectiveness plane).
- **One-way / deterministic sensitivity analyses** identifying the drivers (tornado).
- **Scenario analyses** for structural and key-assumption uncertainty, each with a clear
  purpose.
- For lifetime models: explicit **extrapolation scenarios**, including a "no continued
  benefit after treatment" scenario alongside more optimistic ones (4.2.24).
- Where uncertainty is large and material, the committee may consider managed access /
  data collection / research recommendations (see decision-making.md, 6.2.30).

### Common review findings
- PSA distributions stated but not justified, or correlations ignored.
- Only deterministic results presented; no decision-uncertainty quantification.
- Survival extrapolation by a single parametric fit chosen on in-trial AIC/BIC alone,
  with no external validity check or alternative scenarios.
- Proportional hazards assumed without testing.
- Crossover handled by naive censoring.
- Scenario analyses present but with no stated purpose, so the committee can't tell which
  uncertainties are material.
