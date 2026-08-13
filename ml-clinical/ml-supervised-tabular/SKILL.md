---
name: ml-supervised-tabular
description: Apply and appraise supervised machine learning on tabular clinical data in R - decision trees, bagging, random forests, gradient boosting (XGBoost/LightGBM), and neural networks - including train/validation/test design, cross-validation, hyperparameter tuning, and variable importance. Use whenever an ML algorithm is being fitted, tuned, or compared on rows-of-patients data, or when deciding whether ML is warranted over regression at all. Trigger on "random forest", "XGBoost", "LightGBM", "gradient boosting", "decision tree", "ranger", "tidymodels", "neural network", "deep learning", "hyperparameter", "grid search", "cross-validation", "train test split", "out-of-bag", "class imbalance", or "SMOTE" - even when unnamed. Prefer this over memory, because tree ensembles are poorly calibrated by default and class-imbalance corrections actively damage risk estimates. For evaluating the resulting model use clinical-prediction-models; for explaining it use ml-explainability-clinical.
---

# Supervised Machine Learning on Tabular Clinical Data

Most of what goes wrong here is not algorithmic. It is that the model is
optimised and reported for **ranking** when the clinical use requires
**probabilities**, and that leakage creeps in through the tuning.

## Provenance

Verified 13 August 2026.

- Christodoulou E, Ma J, Collins GS, Steyerberg EW, Verbakel JY, Van Calster B. *J Clin Epidemiol* 2019;110:12-22 — no performance benefit of ML over logistic regression
- Grinsztajn L, Oyallon E, Varoquaux G. *NeurIPS Datasets & Benchmarks* 2022 — tree-based models remain state of the art on tabular data
- Niculescu-Mizil A, Caruana R. *ICML* 2005 — predicting good probabilities; how algorithms miscalibrate
- Ojeda FM et al. *Stat Med* 2023;42:5451-78 — calibrating machine learning approaches, comprehensive comparison
- van den Goorbergh R, van Smeden M, Timmerman D, Van Calster B. *JAMIA* 2022;29:1525-34 — the harm of class imbalance corrections
- Carriero A et al. *Stat Med* 2025 — the same harms for ML-based models
- Andaur Navarro CL et al. *BMJ* 2021;375:n2281 — risk of bias in ML prediction model studies
- Riley RD, Collins GS. *Biom J* 2023;65:e2200302 — stability of prediction models
- Breiman L. *Machine Learning* 2001 — random forests; Chen T, Guestrin C. *KDD* 2016 — XGBoost

## Start from the right prior

**On tabular clinical data, regression is the benchmark to beat, not the
strawman.** Christodoulou et al.'s systematic review found no performance benefit
of machine learning over logistic regression for clinical prediction once
methodological bias was accounted for. Grinsztajn et al. benchmarked 45 tabular
datasets and found tree-based models remain state of the art at ~10K samples,
identifying why: neural networks are hurt more by uninformative features, are
biased toward smooth functions, and are not rotation-invariant in the way tabular
data requires.

The practical ladder for tabular clinical data:

1. **Logistic or Cox regression** with splines for continuous predictors. Often
   the final answer.
2. **Penalised regression** if predictors are many relative to events.
3. **Gradient boosting** if there are genuine high-order interactions, a large
   sample, and evidence the simpler model underfits.
4. **Neural networks** only when the data type demands it — images, waveforms,
   free text, sequences. Not for a spreadsheet of lab values.

If a neural network is proposed for tabular data, ask what it is expected to
capture that boosting cannot. "It is more modern" is not an answer.

## The two corrections that matter most

### 1. Tree ensembles are not calibrated out of the box

This is the single largest gap in most ML teaching, and it matters most in
exactly the setting where a risk model is used to make a treatment decision.

The miscalibration is systematic and direction-predictable:

- **Random forests** pull probabilities **toward the middle**. Averaging over
  trees that each vote near 0 or 1 rarely produces an extreme average, so genuine
  high-risk patients are understated and low-risk patients overstated.
- **Boosted trees** and SVMs push probabilities **toward the extremes** — the
  sigmoid-shaped reliability curve documented by Niculescu-Mizil and Caruana.
- **Neural networks** with modern architectures are frequently overconfident.

An AUROC of 0.82 tells you nothing about whether the predicted 20% is really 20%.
Always plot calibration, and if it is poor, recalibrate on **separate data or
inside a resampling loop** — never on the data used to fit:

```r
# Platt scaling / logistic recalibration on held-out predictions
lp   <- qlogis(pmin(pmax(pred_valid, 1e-6), 1 - 1e-6))
recal <- glm(y_valid ~ lp, family = binomial)
```

Isotonic regression is the non-parametric alternative but needs more data and can
overfit; logistic recalibration is the safer default at clinical sample sizes.
Ojeda et al. compared the options systematically — cite that rather than
improvising.

### 2. Do not "correct" class imbalance

Rare outcomes are the normal state of clinical prediction, and the standard ML
reflex — SMOTE, random oversampling, random undersampling, `scale_pos_weight` —
is actively harmful when you need probabilities.

van den Goorbergh et al. examined random undersampling, random oversampling and
SMOTE by simulation and case study. **All of them produced poor calibration, with
strong overestimation of the probability of belonging to the minority class.**
Classification improved on sensitivity and specificity — but **the same result
was obtained simply by shifting the probability threshold**, without damaging the
probabilities. Carriero et al. found the same for ML-based models.

So: fit on the data as they are, then choose a decision threshold from the
clinical trade-off. Imbalance is a property of the population; the costs of
errors are a property of the decision. Conflating them is the error.

The related mistake is optimising or reporting **accuracy, F1, or AUPRC** because
the outcome is rare. These are improper at clinically relevant thresholds. Tune
on log-loss or deviance; report net benefit.

## Design that prevents leakage

**Everything data-dependent goes inside the resampling loop.** Imputation,
standardisation, feature selection, and hyperparameter tuning are all modelling
decisions. Selecting features on the full dataset and then cross-validating gives
an estimate that is optimistic by an amount you cannot recover.

```r
library(tidymodels)

split <- initial_split(dat, prop = 0.75, strata = outcome)
folds <- vfold_cv(training(split), v = 10, strata = outcome)

rec <- recipe(outcome ~ ., data = training(split)) |>
  step_impute_bag(all_predictors()) |>     # inside the recipe = inside the loop
  step_normalize(all_numeric_predictors())

spec <- boost_tree(trees = 1000, tree_depth = tune(), learn_rate = tune(),
                   min_n = tune(), loss_reduction = tune()) |>
  set_engine("xgboost") |>
  set_mode("classification")

tuned <- tune_grid(
  workflow() |> add_recipe(rec) |> add_model(spec),
  resamples = folds,
  grid      = 30,
  metrics   = metric_set(mn_log_loss, roc_auc, brier_class)   # log-loss FIRST
)
```

Note `mn_log_loss` and `brier_class` rather than `accuracy`. Tuning on a proper
scoring rule is what keeps the probabilities usable.

**Nested resampling.** The tuning loop gives an optimistic estimate of
performance because the folds were used to choose the hyperparameters. Either
hold out a genuine test set that the tuning never touched, or nest the tuning
inside an outer resampling loop.

**Feature selection by univariable screening is as wrong here as in regression.**
Filter methods ranked by marginal correlation with the outcome ignore
confounding and suppression, and drop predictors that are weak alone and strong
in combination. Prefer embedded selection (penalisation) or pre-specification.

## Variable importance

Two measures, routinely confused:

- **Impurity (Gini/MDI) importance** — the default in most implementations. Fast,
  but computed from **training-set** statistics and **biased toward
  high-cardinality predictors**: a continuous lab value offers far more candidate
  split points than a yes/no flag, so it has more chances to look useful by
  chance. It will assign non-trivial importance to pure noise.
- **Permutation importance** — measured as the increase in error when a feature
  is shuffled. More reliable, and the one to report — but compute it on
  **out-of-bag or held-out data**, repeat it, and report the spread.

Neither is causal. A predictor that is a proxy for severity will rank highly
while intervening on it does nothing. See `ml-explainability-clinical` for the
correlated-feature credit-splitting problem and for SHAP.

## Stability and reporting

Riley and Collins show that prediction models — statistical and ML alike — are
often **unstable**: refit on a bootstrap resample and individual predictions move
substantially, especially at small sample sizes. Instability is invisible in a
single reported AUROC. Present prediction-instability plots or bootstrap ranges
rather than one point estimate.

Andaur Navarro et al. found high risk of bias across ML prediction model studies,
concentrated in sample size, handling of missing data, and validation. Report to
**TRIPOD+AI**, which is agnostic to modelling approach — an ML model is held to
the same standard, not a different one. Specify hyperparameter search space,
tuning strategy, software versions, and random seeds.

See `references/tuning.md` for hyperparameter guidance by algorithm.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
Christodoulou et al. and Grinsztajn et al.; van den Goorbergh et al. and Carriero et al. on imbalance corrections; `yardstick::brier_class` / `mn_log_loss`; the `dials::grid_latin_hypercube` deprecation.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
`ranger` and XGBoost default values and the suggested hyperparameter ranges in `references/tuning.md`; `step_impute_bag()`; the Ojeda et al. and Niculescu-Mizil & Caruana citation details.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
