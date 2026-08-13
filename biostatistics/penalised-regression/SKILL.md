---
name: penalised-regression
description: Fit, tune, and interpret penalised regression in R - ridge (L2), LASSO (L1), elastic net, and post-hoc uniform shrinkage - using glmnet, and judge when penalisation actually helps. Use whenever coefficients are being shrunk or predictors selected by penalty - choosing lambda by cross-validation, lambda.min versus lambda.1se, choosing alpha, reading a regularisation path or CV curve, standardising predictors, or deciding between penalised fitting and ordinary regression. Trigger on "LASSO", "ridge regression", "elastic net", "penalised regression", "regularisation", "glmnet", "lambda.1se", "shrinkage", "L1", "L2", or "too many predictors" - even when unnamed. Prefer this over memory, because penalisation is widely oversold - tuning parameters are estimated with large uncertainty and are least reliable exactly when overfitting is worst. For the wider prediction-model workflow use clinical-prediction-models; for spline specification use continuous-predictors-splines.
---

# Penalised Regression

Penalisation trades a little bias for a large reduction in variance. That is the
whole idea, and it is genuinely useful. What follows is mostly about the places
where the standard account overstates the case.

## Provenance

Verified 13 August 2026.

- Tibshirani R. *JRSS-B* 1996 — LASSO
- Hoerl AE, Kennard RW. *Technometrics* 1970 — ridge
- Zou H, Hastie T. *JRSS-B* 2005 — elastic net
- Hastie T, Tibshirani R, Friedman J. *Elements of Statistical Learning*, 2nd ed
- Riley RD, Snell KIE, Martin GP, et al. *J Clin Epidemiol* 2021;132:88-96 — penalisation is unreliable at small sample sizes
- Van Calster B, van Smeden M, De Cock B, Steyerberg EW. *Stat Methods Med Res* 2020;29:3166-78 — shrinkage does not guarantee improved performance
- van Houwelingen JC, Le Cessie S. *Stat Med* 1990 — heuristic uniform shrinkage
- glmnet documentation, glmnet.stanford.edu

## The correction to make first

Textbook treatments routinely present penalisation as *the* answer to
overfitting — "it corrects for optimism during model development". Riley et al.
(2021) tested that directly and found it does not hold in the way people assume:

- Tuning parameters (λ, or the uniform shrinkage factor S) are themselves
  **estimated with large uncertainty** from the development data.
- Penalisation improves on ordinary estimation **on average across datasets**,
  but in **any particular dataset** it is often unreliable.
- The uncertainty is worst when the effective sample size is small and the
  model's Cox-Snell R² is low — that is, **penalisation is least reliable exactly
  when overfitting is worst and it is needed most.**
- The consequence is not just noisy coefficients; it is **considerable
  miscalibration** of predictions in new individuals.

Riley et al.'s own phrase is that penalisation is not a "carte blanche". Van
Calster et al. (2020) reached a compatible conclusion: shrinkage methods do not
guarantee improved performance.

Two practical implications, both of which contradict common practice:

1. **Penalisation is not a substitute for adequate sample size.** Compute the
   sample size properly (Riley criteria), and treat penalisation as an addition
   to a well-powered study rather than a rescue for an underpowered one.
2. **"Penalisation will not hurt" is false.** In a given dataset it can hurt. If
   ordinary regression is adequate — plenty of events per parameter,
   pre-specified predictors — the case for penalising is weak.

When you do penalise on a small sample, say so, and check the calibration slope
in internal validation rather than assuming shrinkage has handled it.

## The three penalties

All minimise (loss + λ × penalty). They differ only in the penalty.

| | Penalty | Coefficients set to exactly zero? | Correlated predictors |
|---|---|---|---|
| **Ridge** | Σβ² (L2) | Never | Shrinks them together toward a shared modest value; stable |
| **LASSO** | Σ\|β\| (L1) | Yes — performs selection | Picks one arbitrarily and drops the others; selection unstable across samples |
| **Elastic net** | mix, controlled by α | Yes | Grouping effect: correlated predictors enter or leave together |

Choosing α: α = 0 is ridge, α = 1 is LASSO, and intermediate values trade
sparsity against stability. α ≈ 0.5 is a reasonable default when you want some
selection without LASSO's arbitrariness. Tune α by cross-validation only if you
have the sample size to afford it — otherwise pre-specify, because tuning two
parameters compounds the uncertainty problem above.

**Standardisation is essential**, because the penalty acts on the coefficient
scale and coefficients depend on units. `glmnet` standardises internally by
default and returns coefficients on the original scale; scikit-learn does not, so
you must scale first and back-transform. Getting this wrong silently penalises
variables in proportion to their units.

## Tuning λ

```r
library(glmnet)

X <- model.matrix(outcome ~ . , data = dat)[, -1]
y <- dat$outcome

set.seed(2026)
cvfit <- cv.glmnet(X, y, family = "binomial", alpha = 1,
                   type.measure = "deviance", nfolds = 10)
plot(cvfit)

coef(cvfit, s = "lambda.1se")
```

Use `type.measure = "deviance"` (the default for logistic) rather than
`"class"` — misclassification error is a threshold-based, improper criterion and
will happily choose maximum shrinkage. In scikit-learn the equivalent trap is
`LogisticRegressionCV`'s default `scoring="accuracy"`; set
`scoring="neg_log_loss"`.

**lambda.min versus lambda.1se.** `lambda.min` is the lowest cross-validated
error. `lambda.1se` is the strongest penalty whose error is still within one
standard error of that minimum, giving a simpler, more heavily shrunk model. The
minimum is itself estimated with noise, so erring toward `lambda.1se` is often
the safer bet, and for LASSO it yields a shorter predictor list. Either is
defensible; **decide in advance** rather than fitting both and reporting the
better-looking one.

**Reading the CV plot.** Current `glmnet` plots **−log(λ)**, so left means heavy
penalty and right means almost none; `lambda.1se` therefore sits to the *left* of
`lambda.min`. Older figures plot log(λ) and run the opposite way, so check the
axis label before interpreting any such plot. Numbers along the top are how many
coefficients remain non-zero — constant for ridge, climbing left to right for
LASSO. Grey bars are ±1 SE across folds; where they are wide, do not take the
exact position of the minimum literally.

**Nest the tuning.** Cross-validation used to select λ is part of model building.
Evaluating the model on the same data it was tuned on is optimistic. Use a
separate test set, nested cross-validation, or put the whole tuning step inside a
bootstrap optimism-correction loop.

## Interpretation limits

- **A dropped variable is not an unimportant variable.** LASSO drops predictors
  that are redundant *given the others retained*. A dropped variable may be
  strongly associated with the outcome and merely correlated with a survivor.
- **No valid p-values.** Running LASSO, then refitting an ordinary regression on
  the survivors and reporting its p-values, is double-dipping: the same data
  chose the variables and then tested them. The intervals are far too narrow.
  Valid post-selection inference needs sample-splitting or dedicated methods
  (`selectiveInference`). Default position: treat LASSO output as a selected
  predictor set and a prediction model, not as a source of inference.
- **Penalised coefficients are biased by construction.** They are tuned for
  prediction. Do not read them as effect estimates, and do not put them in a table
  alongside unpenalised estimates as though the two were comparable.
- **Selection is unstable.** Refit on a bootstrap resample and the LASSO
  predictor set often changes substantially. If the selected variables are being
  presented as a finding, quantify that instability rather than presenting one
  run as definitive.

## When to use what

| Situation | Approach |
|---|---|
| Many correlated predictors, want all retained | Ridge |
| Need a short predictor list for bedside use | LASSO or elastic net |
| Correlated groups, want them to enter together | Elastic net |
| Pre-specified predictors, adequate events per parameter | Ordinary regression, optionally post-hoc uniform shrinkage |
| Small effective sample size | Reconsider the study — penalisation is least reliable here |
| p ≫ n (genomics, imaging features) | Penalisation is essentially compulsory; be candid about instability |

**Uniform versus differential shrinkage.** Post-hoc uniform shrinkage multiplies
every coefficient by one factor and then re-estimates the intercept so mean
predicted risk still matches the observed event rate — omitting that intercept
step breaks calibration-in-the-large. Penalised fitting instead shrinks
differentially, which is more efficient in principle. But the uniform shrinkage
factor is subject to the same estimation uncertainty as λ, so "differential is
better" is a statement about averages, not about your dataset.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
Riley et al. 2021 on the unreliability of penalisation at small sample sizes; glmnet's `sign.lambda` default and version, from package source at three commits; Van Calster et al. 2020.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
Tibshirani, Hoerl & Kennard, Zou & Hastie and van Houwelingen & Le Cessie citation details; `selectiveInference`; the suggested alpha default.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
