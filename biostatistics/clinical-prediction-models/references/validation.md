# Validation and Model Updating

Contents:
1. When internal validation happens
2. Bootstrap optimism correction
3. Cross-validation, and why it is second choice here
4. The external validation ladder
5. Internal-external cross-validation
6. Model updating and recalibration

Sources: Steyerberg EW, *Clinical Prediction Models*, 2nd ed, 2019; Harrell FE,
*Regression Modeling Strategies*, 2nd ed, 2015; Van Calster et al., *Lancet Digit
Health* 2025;7:100916. Verified 13 August 2026.

---

## 1. When internal validation happens

**Once, at the end of development, after every modelling decision is fixed, and
before any performance number is reported.**

Two mistakes are worth naming because both are common and both silently reinstate
the optimism:

- **Treating it as a final polish** once you are already happy with the model.
  The apparent performance that made you happy is precisely the number internal
  validation exists to correct.
- **Using it to choose among candidate models.** Running bootstrap validation on
  five variants and keeping the best-looking one is a modelling decision made on
  the same data. Selection must sit *inside* the validation loop, or not happen
  on this data at all.

Sequence: develop → internally validate → report corrected performance → then,
as a separate study on separate data, externally validate.

Internal validation answers "how will this do on patients like the ones I have?"
It cannot answer whether the model travels.

## 2. Bootstrap optimism correction

The recommended internal validation method. Steps:

1. Draw a bootstrap sample with replacement from the original data.
2. Develop the model in that sample, **repeating every modelling decision** —
   including predictor selection, spline placement, and tuning.
3. Measure performance in the bootstrap sample (apparent bootstrap performance).
4. Apply that bootstrap model to the original data (test performance).
5. Optimism = step 3 − step 4.
6. Repeat 200+ times; 500 or more if runtime allows.
7. Average the optimism.
8. Corrected performance = original apparent performance − average optimism.

```r
set.seed(2026)
v <- validate(fit, B = 500)   # default is B = 40; the docs suggest ~300

# rms reports Somers' Dxy. Convert:  C = 0.5 + Dxy/2
c_apparent  <- 0.5 + v["Dxy", "index.orig"]      / 2
c_corrected <- 0.5 + v["Dxy", "index.corrected"] / 2
optimism_c  <- v["Dxy", "optimism"] / 2

# The corrected slope is the uniform shrinkage factor to apply
shrinkage <- v["Slope", "index.corrected"]
```

**If predictor selection was part of development**, set `bw = TRUE` so the
selection is repeated inside each bootstrap via `fastbw()`. Bare `bw = TRUE`
defaults to `rule = "aic"`; to mirror a p-value-based stepwise procedure, say so:

```r
validate(fit, B = 500, bw = TRUE, rule = "p", sls = 0.10, type = "individual")
```

Using plain `validate()` after
selecting predictors by hand understates the optimism, sometimes badly. This is
the single most common way a bootstrap validation gives a falsely reassuring
answer.

**Applying the shrinkage.** Multiply the coefficients by the corrected slope,
then re-estimate the intercept so mean predicted risk matches the observed event
rate. Shrinking everything without re-fitting the intercept drags the overall
risk level down and breaks calibration-in-the-large.

**Reading the result.** A large apparent-to-corrected drop (0.85 → 0.72) signals
serious overfitting and means the apparent figure should never have been reported
alone. A small drop means the model is reasonably stable — it does *not* mean the
model is good, only that it is not lying to itself.

## 3. Cross-validation, and why it is second choice here

Split into $k$ folds (10 is the usual default); hold each out in turn; average
the held-out results. As with the bootstrap, **every modelling decision must
happen inside the loop** — selecting predictors on the full dataset and then
cross-validating contaminates every fold.

For clinical prediction models the bootstrap is generally preferred because
cross-validation does not hand you a single final model and gives no clean
correction for the calibration slope. Cross-validation is more natural when
tuning a machine-learning model, where the tuning is the thing being validated.

Leave-one-out is the most expensive and often the noisiest; it is rarely the
right choice here.

## 4. The external validation ladder

Internal validation reuses your own data. External validation applies the
finished model to genuinely separate data and asks whether it still works. The
further the new setting sits from the original, the more stringent the test.

| Rung | What differs | What it tests |
|---|---|---|
| Temporal | Same setting, later period | Drift in practice and case-mix over time |
| Geographical | Different hospital or region | Transportability across settings |
| Domain | Different clinical context entirely | The most demanding test |

A single random train/test split of one dataset is **not** external validation.
It is a weaker form of internal validation, and describing it otherwise is one of
the most common overclaims in the literature.

There is also no such thing as a permanently "validated" model — validation is
evidence about a specific population at a specific time, not a certificate.

## 5. Internal-external cross-validation (IECV)

For multi-centre data, hold each centre out in turn: build on all the others,
test on the one left out. This uses every centre as both development and
validation data, and the spread of performance across held-out centres is direct
evidence about how the model is likely to transport.

Report the per-centre estimates and their heterogeneity, not just the pooled
average — a good average can hide a centre where the model fails.

## 6. Model updating and recalibration

External validation frequently shows degraded performance. That usually means the
model is mis-tuned for the new population, not useless. Updating is cheaper and
more stable than rebuilding, which would need a large dataset of its own.

From least to most data-hungry:

1. **Recalibration-in-the-large.** Re-estimate the intercept only. Shifts every
   predicted risk by the same amount on the log-odds scale; leaves the ranking of
   patients — and therefore the C-statistic — completely unchanged. Corrects a
   different baseline risk in the new population.

2. **Logistic recalibration.** Re-estimate intercept and apply an overall slope
   correction to the linear predictor. Corrects both level and spread.

3. **Model revision.** Re-estimate some or all coefficients, or add predictors.
   Needs a substantial sample in the new population, and at that point the
   sample-size criteria apply again.

```r
lp_new <- predict(original_fit, newdata = val_data)   # log odds

# 1. Recalibration-in-the-large
recal_1 <- glm(outcome ~ offset(lp_new), data = val_data, family = binomial)

# 2. Logistic recalibration
recal_2 <- glm(outcome ~ lp_new, data = val_data, family = binomial)
```

**Monitoring.** Models degrade as populations and practice change — *calibration
drift*, where predicted risks gradually stop matching observed rates. A
deployment plan without a monitoring and updating schedule is incomplete, and
TRIPOD+AI expects one to be described.
