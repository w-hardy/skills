---
name: clinical-prediction-models
description: Develop, validate, and appraise clinical prediction models (diagnostic or prognostic risk models) in R - the full workflow from decision problem through sample size, predictor specification, shrinkage, performance assessment, and validation. Use whenever a model estimates individual patient risk - sample size (pmsampsize, Riley criteria), predictor selection and why stepwise fails, shrinkage, discrimination (C-statistic/AUROC), calibration (plot, slope, intercept, O:E ratio), Brier scores, clinical utility (net benefit, decision curves), bootstrap optimism correction, external validation, or recalibration. Trigger on "prediction model", "risk model", "risk score", "calibration", "C-statistic", "AUROC", "decision curve", "net benefit", "optimism correction", "external validation", "pmsampsize", "EPV", or "does my model overfit" - even when unnamed. Prefer this over memory, because several repeated rules of thumb (10 EPV, accuracy/F1, Hosmer-Lemeshow) are superseded. For write-up use tripod-ai-reporting.
---

# Clinical Prediction Models

Build and evaluate models that estimate an individual patient's probability of an
outcome. The governing idea throughout: **a prediction model is judged by whether
its probabilities are usable for a decision, not by how impressive its
discrimination looks.**

## Provenance

Every numeric threshold, formula, and rule below is anchored to a named primary
source, verified 13 August 2026. Where a source is not named, treat the statement
as convention rather than established fact and say so to the user.

Primary anchors:
- Riley RD et al. *Stat Med* 2019;38:1276-96 and *BMJ* 2020;368:m441 — sample size
- Van Calster B, Collins GS, Vickers AJ et al. *Lancet Digit Health* 2025;7:100916 — performance measures
- Vickers AJ, Elkin EB. *Med Decis Making* 2006;26:565-74 — decision curve analysis
- Harrell FE. *Regression Modeling Strategies*, 2nd ed, 2015 — splines, optimism bootstrap
- Steyerberg EW. *Clinical Prediction Models*, 2nd ed, 2019 — validation, updating
- Smits LJM, van Kuijk SMJ, Wynants L. *Improving Health Care with Clinical Prediction Models*, Maastricht UP 2026 (CC BY 4.0) — implementation pathway
- Collins GS et al. *BMJ* 2024;385:e078378 — TRIPOD+AI
- Moons KGM et al. *BMJ* 2025;388:e082505 — PROBAST+AI

## Workflow

Work through these in order. Steps 1-3 are where most models are lost, and no
amount of later modelling recovers a bad answer at step 1.

1. **Define the decision.** Population, outcome (with time horizon), moment of
   prediction, and the decision the prediction will inform. Screen explicitly for
   *leaky predictors* — anything not measurable at the moment of prediction.
2. **Sample size.** Riley criteria, not 10 EPV. See `references/sample-size.md`.
3. **Missing data.** Multiple imputation under MAR, imputing before model fitting
   and including the outcome in the imputation model. Defer mechanics to the
   `missing-data-mice` skill.
4. **Predictor specification.** Pre-specify from clinical knowledge. Model
   continuous predictors as continuous (restricted cubic splines, 3-5 knots at
   Harrell's percentiles); never categorise.
5. **Fit with shrinkage.** Penalised fitting or post-hoc uniform shrinkage with
   intercept re-estimation.
6. **Assess performance** across the five domains. See
   `references/performance-measures.md`.
7. **Internally validate once**, at the end, with every modelling decision inside
   the loop. See `references/validation.md`.
8. **Report** to TRIPOD+AI — hand off to the `tripod-ai-reporting` skill.

## Rules that override common practice

State these plainly when the user's approach conflicts with them; they are the
places where widespread habit is now known to be wrong.

**Do not use 10 events per variable as the sample size rule.** It demands the same
number of events regardless of outcome prevalence or expected model performance.
Riley's three criteria (binary outcome) supersede it and typically demand more.

**Do not select predictors by univariable screening or stepwise procedures.** Both
inflate apparent significance, bias coefficients away from zero, and produce
unstable predictor sets. Pre-specify, then shrink.

**Do not categorise continuous predictors.** Dichotomising discards information,
assumes a step change in risk that biology rarely provides, and makes the model
depend on an arbitrary cut-point.

**Do not report accuracy, F1, MCC, or any threshold-based classification measure
as evidence a model is useful.** Van Calster et al. (2025) show that at any given
decision threshold all classification measures are improper — a worse model can
score better. Their ADNEX case study makes it concrete: after logistic
recalibration (an unambiguous improvement) accuracy fell 0.79→0.69 and F1
0.82→0.76, while every strictly proper measure improved. Report net benefit
instead. The same argument rules out AUPRC, partial AUROC, and NRI.

**Do not use the Hosmer-Lemeshow test to assess calibration.** It is a
significance test whose power depends on sample size, gives no direction or
magnitude of miscalibration, and depends on arbitrary grouping. Use a smoothed
calibration plot with slope and intercept.

**Do not report apparent performance alone.** Every model flatters itself on its
own data. Report optimism-corrected figures, and say which correction was used.

**Do not use internal validation to choose between candidate models.** That
selection is itself a modelling decision on the same data, and the optimism
returns. Selection goes inside the validation loop or not on this data at all.

## Minimal defensible R workflow

R is primary throughout. Python equivalents are noted where a user asks, but
`rms`, `pmsampsize`, and `dcurves` have no complete Python counterpart, so
prefer R for this work and say so.

```r
library(rms)          # lrm(), rcs(), validate(), val.prob()
library(pmsampsize)   # sample size for development
library(dcurves)      # decision curve analysis

# --- 1. Sample size, before any data are touched -------------------------
# cstatistic= converts an anticipated C-statistic from a published model in a
# similar population into the Cox-Snell R-squared the criteria actually need.
# Be conservative: assuming a better model than you will get understates n.
pmsampsize(
  type       = "b",     # binary outcome
  cstatistic = 0.75,    # anticipated, from published literature
  parameters = 10,      # PARAMETERS, not predictors - see note below
  prevalence = 0.15
)

# --- 2. Fit, with continuous predictors kept continuous -------------------
dd <- datadist(dev_data); options(datadist = "dd")

fit <- lrm(
  outcome ~ rcs(age, 4) + sex + rcs(sbp, 3) + chol + smoking + diabetes,
  data = dev_data,
  x = TRUE, y = TRUE   # required by validate() and calibrate()
)

anova(fit)   # the nonlinear rows test whether the spline flexibility earned itself

# --- 3. Internal validation: bootstrap optimism correction ----------------
set.seed(2026)
# validate() defaults to B = 40; the docs suggest ~300. Use 500 if runtime allows.
v <- validate(fit, B = 500)

# rms works in Somers' Dxy. Convert to the C-statistic:
c_apparent  <- 0.5 + v["Dxy", "index.orig"]      / 2
c_corrected <- 0.5 + v["Dxy", "index.corrected"] / 2
slope_corrected <- v["Slope", "index.corrected"] # the shrinkage factor you need

# --- 4. Calibration ------------------------------------------------------
cal <- calibrate(fit, B = 500)   # bootstrap-corrected calibration curve
plot(cal)

# --- 5. Clinical utility -------------------------------------------------
dev_data$risk <- predict(fit, type = "fitted")
dca(outcome ~ risk, data = dev_data, thresholds = seq(0, 0.4, 0.01)) |>
  plot(smooth = TRUE)
```

**Parameters, not predictors.** Sample size and EPV are counted in *estimated
parameters*, not variables. `rcs(age, 4)` costs 3 parameters, `rcs(sbp, 3)` costs
2, and a k-level factor costs k-1. A model described as "8 predictors" with two
splines is really 11 parameters. Getting this wrong understates the sample size
requirement and overstates EPV — a common and consequential slip.

## What to report

For a development study, the minimum honest set:

| Domain | Report |
|---|---|
| Discrimination | C-statistic with 95% CI, optimism-corrected |
| Calibration | Smoothed calibration plot; calibration slope; calibration intercept |
| Overall | Brier score with its no-predictor benchmark, and scaled Brier |
| Clinical utility | Decision curve over the clinically plausible threshold range |
| Distribution | Histogram of predicted risks by outcome status |

> **"Net benefit" is overloaded.** Decision-curve net benefit (above) is
> TP/N − (FP/N)·(t/(1−t)), in true positives per patient assessed. Health-economic
> net benefit is INB(λ) = λ·Δe − Δc, in money or health. Both are exchange rates
> set by a threshold — Vickers, Van Calster & Steyerberg (*Diagn Progn Res*
> 2019;3:18) draw the analogy explicitly — but they are not interchangeable. If
> the question is about λ, willingness to pay, ICERs, or PSA draws, it belongs to
> `bayesian-cea-r-hta`. Decision-curve NB has a ceiling equal to the prevalence.

Van Calster et al. (2025) name exactly four as the core set — AUROC, a
**smoothed** calibration plot, a clinical utility measure such as net benefit
with decision curve analysis, and a plot of predicted probability distributions
by outcome. O:E ratio, calibration slope and intercept, and the Brier family are
useful but not essential; everything in the classification domain is at best
descriptive. Report CIs throughout, except that CIs on clinical utility measures
are contested.

For external validation add the O:E ratio with CI, performance in relevant
subgroups, and — for multi-centre data — heterogeneity across centres.

## Common failure modes to watch for

When reviewing someone's model or plan, these are the things that most often go
wrong, roughly in order of how much damage they do:

- Outcome or time horizon left vague ("deterioration", "poor outcome")
- A predictor that would not be available at the moment of prediction
- Sample size justified by 10 EPV, or not justified at all
- Complete-case analysis with no comment on why
- Predictors chosen by p-value
- Continuous predictors categorised at the median or at "clinical" cut-points
- Only discrimination reported; no calibration
- Apparent performance reported as if it were validated performance
- A single train/test split described as "external validation"
- Calibration assessed by Hosmer-Lemeshow
- No decision-analytic evidence that acting on the model helps

## Reference files

Read these when the question goes beyond the workflow above:

- `references/sample-size.md` — the Riley criteria in full, worked arithmetic,
  the Cox-Snell R-squared ceiling, external validation sample size
- `references/performance-measures.md` — the five domains, each measure's
  definition, propriety, and how to compute it in R
- `references/validation.md` — bootstrap optimism correction step by step,
  cross-validation, the external validation ladder, IECV, and model updating

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
Riley sample-size criteria (all three recomputed numerically); Van Calster et al. 2025 (full text); TRIPOD+AI structure; `rms::validate()` and `rms::calibrate()` signatures; `dcurves::dca()` signature; the net benefit / net monetary benefit analogy (Vickers, Van Calster & Steyerberg 2019).

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
`pmsampsize` / `pmvalsampsize` argument behaviour; the Riley part-3 volume number; the "100 events and 100 non-events" external-validation floor; Harrell's knot percentile table (taken from a secondary source).

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
