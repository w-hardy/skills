---
name: continuous-predictors-splines
description: Model continuous predictors properly in R - restricted cubic splines, fractional polynomials, knot placement and count, testing and reporting non-linearity - and make the case against categorising. Use whenever a continuous variable enters a regression or prediction model and the question is how to specify it, or when reviewing work that has dichotomised at a median, tertile, or "optimal" cut-point. Trigger on "spline", "restricted cubic spline", "natural spline", "rcs", "ns()", "fractional polynomial", "mfp", "knots", "non-linearity", "categorise", "dichotomise", "cut-point", "tertiles", "quartiles", "U-shaped", "J-shaped", "loess", or "should I categorise this variable" - even when unnamed. Prefer this over memory, because knot percentiles, the degrees-of-freedom arithmetic, and whether to test-then-simplify are commonly got wrong. For the wider model-building workflow use clinical-prediction-models; for penalised fitting use penalised-regression.
---

# Continuous Predictors: Splines and Fractional Polynomials

The default should be: **keep continuous variables continuous, and let the shape
bend.** Categorising is the single most common avoidable error in clinical
regression, and a linear term is the second.

## Provenance

Verified 13 August 2026.

- Harrell FE. *Regression Modeling Strategies*, 2nd ed, 2015 — splines, knot placement, df budgeting
- Royston P, Altman DG. *Applied Statistics* 1994 — fractional polynomials
- Royston P, Altman DG, Sauerbrei W. *Stat Med* 2006 — dichotomising continuous predictors is a bad idea
- Sauerbrei W, Royston P, Binder H. *Stat Med* 2007 — MFP
- Lopez-Ayala P et al. *BMJ* 2025 — practical guidance on continuous variables in clinical research
- Steyerberg EW. *Clinical Prediction Models*, 2nd ed, 2019

## The case against categorising

Categorising imposes three assumptions, all of them usually false: that risk is
flat within a category, that it jumps at the boundary, and that the boundary is
biologically meaningful. A BMI of 24.9 and one of 25.0 become different kinds of
patient; a BMI of 18.6 and one of 24.8 become the same kind.

Consequences worth naming to a collaborator, in the order they usually land:

- **Lost power.** Dichotomising at the median costs roughly the equivalent of
  discarding a third of the data (Royston, Altman & Sauerbrei 2006).
- **Biased estimates**, in a direction that depends on where the cut-points fall.
- **Residual confounding** when a categorised variable is used for adjustment —
  the true confounding varies smoothly and you have adjusted in steps.
- **Researcher degrees of freedom.** Different cut-points give different, sometimes
  contradictory, conclusions from the same data. "Optimal" cut-point searching is
  the worst version: it inflates false positives badly and the cut-point does not
  replicate.
- **Worse prediction.**

The usual defence — "clinicians think in categories" — confuses *how a result is
communicated* with *how a model is fitted*. Fit continuously; then, if a
threshold is genuinely needed for a decision, derive it from the fitted curve and
the decision problem. That way the threshold is a conclusion, not an assumption.

## Choosing a specification

| Situation | Specification |
|---|---|
| Default, adequate sample | Restricted cubic spline, 4 knots (3 df) |
| Small sample, or simple expected shape | RCS, 3 knots (2 df) |
| Large sample, complex expected shape | RCS, 5 knots (4 df) |
| Want a compact closed-form equation | Fractional polynomial (FP1 or FP2) |
| Predictor bounded at zero with plausible power shape | FP often fits naturally |
| Very large n, want maximum flexibility with automatic smoothing | Penalised spline in a GAM (`mgcv`) |

**Restricted cubic splines** (= natural splines) are cubic between the outer
knots and **linear beyond them**. That tail constraint is the point: it stops the
model inventing dramatic bends where there are few patients. An RCS with *k*
knots costs **k − 1 parameters**, so a 4-knot spline adds only 2 beyond a linear
term — economical for what it buys. An unrestricted cubic spline with *k* knots
costs k + 3; the four saved parameters are the squared and cubic terms removed
from the two tails.

**Knot placement** follows fixed percentiles of the predictor's own distribution,
not equally spaced values, so knots land where the patients are:

| Knots | Percentiles |
|---|---|
| 3 | 10, 50, 90 |
| 4 | 5, 35, 65, 95 |
| 5 | 5, 27.5, 50, 72.5, 95 |

Exact placement matters far less than the *number* of knots. Do not agonise over
it; do think about the count, which is a degrees-of-freedom decision.

**Fractional polynomials** extend ordinary polynomials to fractional and negative
powers from {−2, −1, −0.5, 0, 0.5, 1, 2, 3}, with x⁰ ≡ log(x). FP2 searches 36
candidate models: C(8,2) = 28 distinct pairs plus 8 repeated-power forms
x^p·log(x). Strengths: parsimonious, closed-form, good at monotone and simple
U/J shapes, well-suited to modest samples. Weaknesses: erratic at the extremes
because the functions are global, and unable to represent local features. FPs and
splines are complementary and usually agree; RCS is the better default in
clinical work because of its boundary behaviour.

## The decision that is usually made wrongly

**Do not fit a spline, test non-linearity, and drop back to a linear term if the
test is non-significant.** This is the step most workflows get wrong, and it is
in tension with Harrell's own advice, which is to **pre-specify the degrees of
freedom** from sample size and the predictor's expected importance, then keep
them.

Two reasons:

1. **The test-then-simplify step is data-driven model selection.** Everything
   downstream — standard errors, confidence intervals, p-values — is then
   computed as though the specification had been fixed in advance. It was not.
   The "phantom degrees of freedom" spent on the test are never paid for.
2. **The test is underpowered where it matters.** A non-significant test for
   non-linearity is weak evidence of linearity, especially at the sample sizes
   most clinical studies have.

The cost of a spline on a truly linear relationship is small — you lose a couple
of degrees of freedom. The cost of a linear term on a truly curved relationship
is bias and a wrong clinical conclusion. The asymmetry says: keep the spline.

Report the non-linearity test as a *description* of what the data show if you
like. Do not use it as a *gate* on the model you report.

## Implementation

```r
library(rms)

dd <- datadist(dat); options(datadist = "dd")

fit <- lrm(outcome ~ rcs(age, 4) + rcs(crp, 3) + sex + comorbidity,
           data = dat, x = TRUE, y = TRUE)

anova(fit)   # "Nonlinear" rows describe curvature; do not use them as a gate

# The output that actually communicates the result: a plot on the risk scale
plot(Predict(fit, age, fun = plogis), ylab = "Predicted risk")
```

Base R alternative when `rms` is unavailable: `splines::ns(age, df = 3)` gives a
natural spline with knots at quantiles. Fractional polynomials: `mfp::mfp()`.
Penalised splines: `mgcv::gam(outcome ~ s(age), family = binomial)`.

## Reporting

- **Do not tabulate spline coefficients.** They are not interpretable
  individually and invite readers to misread them. Report the overall test for
  the predictor, optionally the non-linearity test, and a figure.
- **The figure is the result.** Predicted outcome across the predictor's range,
  on the scale a clinician uses (risk, not log-odds), with a confidence band and
  a rug or histogram showing where the patients actually are. Treat the flared
  ends of the band with suspicion.
- **State the reference values.** A partial-effect plot is drawn for one
  reference patient; changing them shifts the curve vertically. That note is not
  fine print.
- If contrasts are wanted, report specific comparisons (risk or odds ratio at
  value A versus value B) rather than a single slope.

**One trap.** On the risk scale a straight-line effect looks *bent*, because the
logistic link compresses near 0 and 1. A curved-looking risk plot is therefore
not evidence of non-linearity. Judge curvature on the linear-predictor scale or
from the model, not from the shape of the risk plot.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
The fractional polynomial power set and the 36 FP2 candidates (arithmetic checked); the case against categorisation as set out by Royston, Altman & Sauerbrei.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
**Harrell's knot percentile table — taken from the source textbook, not from Harrell directly. Check before relying on it.** `mfp::mfp()`, `splines::ns()` and `mgcv::gam()` signatures; the pre-specify-df argument is a reading of Harrell's position, not a quotation.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
