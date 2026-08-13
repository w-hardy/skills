# Performance Measures: The Five Domains

Framework and terminology follow Van Calster B, Collins GS, Vickers AJ, Wynants
L, Kerr KF, Barrenada L, Varoquaux G, Singh K, Moons KGM, Hernandez-Boussard T,
Timmerman D, McLernon DJ, van Smeden M, Steyerberg EW. Evaluation of performance
measures in predictive artificial intelligence models to support medical
decisions: overview and guidance. *Lancet Digit Health* 2025;7:100916 (CC BY 4.0).
That paper discusses 32 measures across five domains. Verified 13 August 2026.

Domains 1-4 are statistical performance. Domain 5 is decision-analytic
performance, and it is the only one that answers "should this model be used".

Contents:
1. Propriety — the idea that organises everything else
2. Discrimination
3. Calibration
4. Overall performance
5. Classification
6. Clinical utility
7. R implementation

---

## 1. Propriety — the idea that organises everything else

A performance measure is **proper** if its expected value is optimised when the
correct probabilities are used — no incorrect model can beat the correct one in
expectation. **Strictly proper** means the correct probabilities are the *only*
maximiser. **Semi-proper** means the correct model is among the maximisers.
**Improper** means an incorrect model can score better.

Van Calster et al. classify all 32 measures on two characteristics: propriety,
and whether the measure has a clear focus on either statistical *or*
decision-analytic performance. Seventeen measures satisfy both; fifteen do not
and are advised against. Only one measure — F1 — fails both.

The consequence that most often surprises people: **at any given decision
threshold, all classification measures are improper.** Some are semi-proper at a
threshold of exactly 0.5 (classification accuracy) or exactly the prevalence
(balanced accuracy, Youden, F1) — but those are rarely the clinically relevant
thresholds. A model can be made to look better on F1 by being worse.

**The cleanest demonstration.** In the paper's ADNEX case study, the model was
logistically recalibrated — an unambiguous improvement. Every strictly proper
measure improved. Semi-proper measures improved or stayed the same. The improper
classification summaries *worsened markedly*: accuracy fell from 0.79 to 0.69,
F1 from 0.82 to 0.76, MCC from 0.63 to 0.48. If a metric penalises a model for
becoming better calibrated, it cannot be used to choose models.

Quick reference:

| Measure | Status | Verdict |
|---|---|---|
| Brier, scaled Brier, log-loss, R² variants | Strictly proper | Fine; best for model comparison |
| AUROC, O:E, calibration intercept and slope, net benefit | Semi-proper, clear focus | Recommended |
| AUPRC, partial AUROC | Proper but conflated focus | **Inadvisable** — ignoring true negatives or restricting the curve smuggles in misclassification costs |
| Accuracy, balanced accuracy, Youden, kappa, DOR, F1, MCC | Improper at t | **Inadvisable** |
| Discrimination slope, MAPE | Improper | **Inadvisable** |
| Net reclassification improvement (NRI) | Improper | **Invalid** — do not use for incremental value |

Sensitivity/specificity and PPV/NPV are improper individually but may be reported
descriptively *in pairs*, as an addition to the core set — never in place of it.
PPV and NPV are the more clinically useful pair, because they condition on the
model's classification rather than on an outcome not yet known.


## 2. Discrimination

**C-statistic / AUROC.** For a randomly chosen patient with the outcome and one
without, the probability that the model assigned the higher risk to the one who
had it. 0.5 is chance; 1.0 is perfect ranking.

Four limitations to state whenever a C-statistic is reported:

- **Insensitive to calibration.** A model can rank perfectly and attach entirely
  wrong probabilities.
- **Context-blind.** It averages ranking ability over every possible threshold,
  weighting equally the ones no clinician would ever use.
- **Hard to move.** A genuinely valuable new biomarker may barely shift it.
- **Not comparable across populations.** A wider case-mix inflates it. Two
  studies both reporting 0.75 have not shown equivalent performance.

Report with a 95% CI, and optimism-corrected in a development study.

**On class imbalance.** There is a persistent claim that AUROC is misleading
when events are rare and that AUPRC should replace it. Van Calster et al. reject
this: class imbalance is a property of the population, whereas misclassification
costs are a property of the decision, and conflating them is the error. AUPRC
ignores true negatives and its value depends on prevalence; partial AUROC
discards the interpretation. Both are inadvisable for clinical models. If the
worry behind the request is really "do the costs of errors differ?", the answer
is a decision curve, not a different discrimination metric.

## 3. Calibration

Whether the numbers are right: when the model says 20%, do about 20 in 100 such
patients have the event? This is what makes risk-threshold treatment decisions
safe, and it is the property most often omitted.

**Calibration-in-the-large / O:E ratio.**

$$\text{O:E} = \frac{\text{observed event rate}}{\text{mean predicted probability}}$$

1 is ideal. Above 1, the model underestimates risk. Below 1, it overestimates.
Report with a CI.

**Calibration intercept.** Fit a logistic regression of the outcome on the linear
predictor **as an offset** — that is, with the slope fixed at 1:

```r
cal_int <- glm(y ~ offset(lp), family = binomial)   # lp = qlogis(predicted risk)
coef(cal_int)[1]
```

0 is ideal; negative means systematic overprediction.

> **Correction worth knowing.** A common shortcut reports the intercept from the
> free-slope model `glm(y ~ lp)` as "the calibration intercept". That quantity is
> conditional on the estimated slope and is *not* calibration-in-the-large. If you
> report both an intercept and a slope, they should come from the two models
> above, or you should state explicitly that both came from the joint model.

**Calibration slope.** Fit a logistic regression of the outcome on the linear
predictor, slope free:

```r
cal_slope <- coef(glm(y ~ lp, family = binomial))[2]
```

- **1** — predictions spread by the right amount.
- **< 1** — predictions too extreme; high risks too high, low risks too low. The
  fingerprint of overfitting, and the quantity that uniform shrinkage corrects.
- **> 1** — predictions too bunched toward the middle; usually over-shrinkage.

**Calibration plot.** The most informative single output. Prefer a *smoothed*
curve (loess or spline) over decile grouping — grouping depends on an arbitrary
number of bins and hides shape. Plot the distribution of predicted risks
underneath, because a curve is only meaningful where patients actually are.

**Internal versus external.** Calibration matters most in *external*
validation, where the population differs. In internal validation, development and
validation target the same population, so an optimism-corrected calibration plot
is useful but the O:E ratio and calibration slope alone can suffice — and O:E
will usually sit close to 1 by construction. Do not read that as evidence the
model is well calibrated elsewhere.

**Do not use the Hosmer-Lemeshow test.** Its power tracks sample size rather than
the size of the problem, it gives neither direction nor magnitude, and it depends
on arbitrary grouping.

## 4. Overall performance

**Brier score** — mean squared difference between predicted probability and
observed outcome. Proper. Lower is better.

$$\text{Brier} = \frac{1}{N}\sum_{i=1}^{N}(p_i - y_i)^2$$

Uninterpretable alone, because its scale depends on prevalence.

**Scaled Brier (Brier skill score)** — expresses the score against the
no-predictor benchmark:

$$\text{Scaled Brier} = 1 - \frac{\text{Brier}}{\bar{y}(1 - \bar{y})}$$

The benchmark $\bar{y}(1-\bar{y})$ is exactly the Brier score of a model that
announces the overall event rate to everyone. Read the scaled version as the
proportion of the way from useless to perfect: 0.12 means the model closed 12% of
that gap. Useful antidote to a flattering C-statistic — scaled Brier values are
typically far more modest than AUROCs suggest.

**Nagelkerke R-squared** — Cox-Snell rescaled by its prevalence-dependent
maximum. Report Nagelkerke; use Cox-Snell for sample size formulas.

## 5. Classification

Sensitivity, specificity, PPV, NPV, accuracy, F1. All depend entirely on a chosen
threshold, and all are improper at clinically relevant thresholds (see §1).

If reported at all: state the threshold, justify it clinically, and never present
these as the primary evidence of usefulness. If the reason for wanting them is
"we need to show the model is accurate", the honest answer is a decision curve.

## 6. Clinical utility

**Net benefit** at threshold probability $p_t$ — the risk level above which you
would act:

$$\text{NB} = \frac{TP}{N} - \frac{FP}{N} \times \frac{p_t}{1 - p_t}$$

The factor $p_t/(1-p_t)$ is the **exchange rate** between false and true
positives, set by the threshold. A 10% threshold says you would accept treating 9
patients unnecessarily to catch 1 who needs it.

Units are true positives per patient assessed. Multiply by 100 for "events
correctly identified per 100 patients assessed, net of the unnecessary
treatments". The **maximum attainable net benefit is the prevalence** — useful
for judging whether a value is respectable. Standardised net benefit divides by
prevalence so the ceiling is 1, which eases comparison across populations, though
decision scientists object that prevalence is part of what makes utility
meaningful.

Miscalibration reduces net benefit and can make a model actively **harmful** —
net benefit below a default strategy. This is the concrete reason calibration is
not an aesthetic concern.

**Confidence intervals.** Report CIs for everything else, but note that whether
CIs and p-values belong on clinical utility measures is contested: they arguably
contradict decision-analytic principles, since the decision is to act on the
best available estimate.

**Decision curve analysis** plots net benefit against threshold for three
strategies: the model, treat-all, treat-none. The model is useful where its curve
sits above *both* defaults across thresholds clinicians would actually use.

Two reading rules:

- Net benefit falls as the threshold rises for every strategy, because fewer
  patients qualify. A declining curve is not a deteriorating model. Only the
  *ranking* of the three curves matters.
- Choose the threshold range from clinical reasoning before looking at the plot,
  not from where the model happens to win.

## 7. R implementation

```r
library(rms); library(dcurves)

lp   <- predict(fit)                  # linear predictor (log odds)
risk <- plogis(lp)
y    <- dev_data$outcome

# Discrimination
c_stat <- rcorr.cens(risk, y)["C Index"]

# Calibration: intercept from the offset model, slope from the free model
cal_intercept <- coef(glm(y ~ offset(lp),  family = binomial))[1]
cal_slope     <- coef(glm(y ~ lp,          family = binomial))[2]
oe_ratio      <- mean(y) / mean(risk)

# Smoothed, bootstrap-corrected calibration curve
plot(calibrate(fit, B = 500))

# Overall
brier        <- mean((risk - y)^2)
brier_bench  <- mean(y) * (1 - mean(y))
brier_scaled <- 1 - brier / brier_bench

# Clinical utility
# Default thresholds are seq(0, 0.99, 0.01). Restrict to the clinically
# plausible range, decided before looking at the plot.
dca(outcome ~ risk, data = dev_data, thresholds = seq(0, 0.4, 0.01)) |>
  plot(smooth = TRUE)
```

Also in `dcurves`: `harm =` to charge a fixed cost for testing, `time =` for
time-to-event outcomes, `prevalence =` when the data are case-control, and
`standardized_net_benefit()` / `net_intervention_avoided()`.

**Avoid `as_probability =`.** It converts a raw marker to a probability by
fitting a logistic (or Cox) model inside `dca()`, assuming linearity on the
log-odds scale. Where that fails it induces miscalibration — and miscalibration
degrades net benefit directly, which is the one thing a decision curve is
supposed to detect. Model the marker properly outside `dca()`, with splines if
needed, and pass the fitted risks.

**Python note.** `sklearn.metrics.roc_auc_score` and `brier_score_loss` cover
domains 1 and 3; `sklearn.calibration.calibration_curve` gives grouped (not
smoothed) calibration. There is no mature Python equivalent of `rms::calibrate`
or `dcurves::dca`, so net benefit generally has to be written out from the
formula above. For this work, R is the better environment.
