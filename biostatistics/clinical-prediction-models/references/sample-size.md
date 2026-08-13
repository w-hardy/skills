# Sample Size for Prediction Model Studies

Contents:
1. Why 10 EPV is not enough
2. The Riley criteria (binary outcome)
3. The Cox-Snell R-squared, and where to get one
4. Worked arithmetic (verified)
5. Continuous and time-to-event outcomes
6. Sample size for external validation
7. What to do when the requirement is unaffordable

---

## 1. Why 10 EPV is not enough

The 10-events-per-variable rule asks for the same number of events whether the
outcome is common or rare, and whether the model is expected to predict well or
badly. It has no target: it does not say *what* it is protecting against. Riley
and colleagues replaced it with criteria that each guard a named failure.

EPV remains useful as a *description* of a fitted model, but it is not a design
criterion. Count it in estimated parameters, not variables.

## 2. The Riley criteria (binary outcome)

Source: Riley RD, Snell KIE, Ensor J, et al. Minimum sample size for developing a
multivariable prediction model: PART II — binary and time-to-event outcomes.
*Stat Med* 2019;38:1276-96. Practical summary: Riley RD, Ensor J, Snell KIE, et
al. Calculating the sample size required for developing a clinical prediction
model. *BMJ* 2020;368:m441.

Three criteria must be satisfied simultaneously; the required *n* is the largest.

**Criterion 1 — small overfitting, expressed as shrinkage.** The expected uniform
shrinkage factor should be at least **0.9**: predictor effects need scaling back
by no more than about 10%.

$$n_1 = \frac{P}{(S - 1)\,\ln\!\left(1 - \frac{R^2_{CS}}{S}\right)}$$

where $P$ is the number of estimated parameters, $S = 0.9$, and $R^2_{CS}$ is the
anticipated Cox-Snell R-squared. This criterion usually drives the answer.

**Criterion 2 — small optimism in apparent fit.** The absolute difference between
apparent and adjusted Nagelkerke R-squared should be at most **0.05**.

$$S_2 = \frac{R^2_{CS}}{R^2_{CS} + 0.05 \times R^2_{CS,\max}}, \qquad
n_2 = \frac{P}{(S_2 - 1)\,\ln\!\left(1 - \frac{R^2_{CS}}{S_2}\right)}$$

**Criterion 3 — precise estimate of the overall risk.** Margin of error on the
outcome proportion of at most **0.05**.

$$n_3 = \left(\frac{1.96}{0.05}\right)^2 \phi\,(1 - \phi)$$

where $\phi$ is the anticipated prevalence.

## 3. The Cox-Snell R-squared, and where to get one

Criteria 1 and 2 need an advance guess at model performance as $R^2_{CS}$. Two
things matter.

**Its maximum is not 1.** With a binary outcome the attainable ceiling depends on
prevalence:

$$R^2_{CS,\max} = 1 - \exp\!\big(2[\phi\ln\phi + (1-\phi)\ln(1-\phi)]\big)$$

At 15% prevalence this is 0.571. So $R^2_{CS} = 0.10$ is 18% of the attainable
maximum, not 10% of anything. Nagelkerke R-squared is exactly $R^2_{CS} /
R^2_{CS,\max}$ — the rescaled version that does run 0 to 1. **The sample size
formulas take Cox-Snell; Nagelkerke is the one to report.**

**Get it from a published C-statistic.** `pmsampsize(cstatistic = ...)` performs
the conversion. Take the C-statistic from a model in a similar population and
**be conservative** — assuming a better model than you will achieve makes the
required sample size look smaller than it is.

```r
pmsampsize(type = "b", cstatistic = 0.75, parameters = 10, prevalence = 0.15)

# If you already have an R-squared in mind, supply it directly. Exactly one of
# cstatistic, csrsquared or nagrsquared should be given.
pmsampsize(type = "b", csrsquared = 0.10, parameters = 10, prevalence = 0.15)
```

## 4. Worked arithmetic (verified 13 August 2026)

$P = 10$ parameters, prevalence $\phi = 0.15$, anticipated C-statistic 0.75,
which converts to $R^2_{CS} = 0.1028$.

| Criterion | Required n |
|---|---|
| 1 — shrinkage ≥ 0.9 | **825** |
| 2 — R-squared optimism ≤ 0.05 | 327 |
| 3 — risk within ±0.05 | 196 |

Requirement: **n = 825**, giving 124 events and 12.4 events per parameter — above
the 100 events the 10-EPV rule would have accepted. Criterion 1 binds, as it
usually does.

These figures were reproduced independently from the formulas above, so they can
be used to sanity-check a `pmsampsize` installation.

## 5. Continuous and time-to-event outcomes

**Continuous outcome** (`type = "c"`): four criteria, the extra one targeting
precise estimation of the residual variance. Requires the anticipated R-squared
and the outcome SD.

**Time-to-event** (`type = "s"`): the criteria are expressed via the event rate,
mean follow-up, and the timepoint of interest, and the shrinkage criterion works
on the Cox-Snell R-squared for survival. Supply `rate`, `timepoint`, and
`meanfup`.

## 6. Sample size for external validation

Different question, different package: `pmvalsampsize`. Riley RD, Snell KIE,
Archer L, et al. Evaluation of clinical prediction models (part 3): calculating
the sample size required for an external validation study. *BMJ*
2024;384:e074821.

The targets are precision of the *validation* estimates — typically the
calibration slope, the O:E ratio, and the C-statistic — not shrinkage. A rough
floor often quoted is 100 events and 100 non-events, but compute it properly;
precise calibration assessment usually needs more.

## 7. When the requirement is unaffordable

The levers, in order of preference:

1. Reduce the number of candidate parameters (fewer predictors, fewer knots)
2. Find a larger or additional data source, or pool centres
3. Use penalised estimation, and say so — but note that penalisation reduces the
   consequences of a small sample, it does not remove the requirement, and the
   tuning parameter is itself unstable in small samples
4. Reconsider whether the study should proceed

Proceeding underpowered and hoping is not on the list. An underpowered model
looks impressive in development and fails in validation, and discovering that
before recruitment is far cheaper than after.
