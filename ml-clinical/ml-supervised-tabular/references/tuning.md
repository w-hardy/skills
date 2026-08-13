# Hyperparameters and Tuning

Contents:
1. Parameters versus hyperparameters
2. Random forests
3. Gradient boosting
4. Neural networks on tabular data
5. Search strategy
6. What to record

---

## 1. Parameters versus hyperparameters

**Parameters** are learned from the data by the fitting algorithm — regression
coefficients, split points in a tree, network weights. **Hyperparameters** are
set before fitting and govern how learning happens — number of trees, depth,
learning rate, penalty strength.

The distinction matters because hyperparameters are chosen using the data too,
just through a different mechanism (cross-validation). That choice is a modelling
decision and carries the same leakage risk as any other. Treat tuning as part of
model development, always inside the resampling loop.

## 2. Random forests

Random forests are famously insensitive to tuning; defaults are usually close to
optimal, which is a genuine advantage.

| Hyperparameter | `ranger` | Guidance |
|---|---|---|
| Number of trees | `num.trees` | More is never worse for accuracy, only slower. 500–1000. Not a tuning parameter — a convergence setting. |
| Predictors per split | `mtry` | The one worth tuning. Default √p for classification. Lower values decorrelate trees more. |
| Minimum node size | `min.node.size` | Default 1 for classification, 5 for regression. Raise it for smoother probability estimates on small data. |
| Sampling | `replace`, `sample.fraction` | Rarely needs changing. |

**Set `probability = TRUE`** in `ranger` for a probability forest. Classification
forests that return votes give crude, granular probabilities that calibrate
badly.

**Out-of-bag error** comes free: each tree is fitted on a bootstrap sample, so
roughly a third of observations are out of bag for that tree and can be scored
without a separate split. Useful for a quick internal estimate and for
permutation importance. It is *not* a substitute for a proper validation design
when tuning has occurred, because repeated OOB-guided tuning reintroduces
optimism.

## 3. Gradient boosting

Boosting is far more tuning-sensitive than random forests, and much easier to
overfit. Sequential trees each correct the previous ensemble's errors, so nothing
stops it fitting noise.

| Hyperparameter | XGBoost | Guidance |
|---|---|---|
| Learning rate | `eta` | 0.01–0.1. Lower is better but needs more trees. |
| Number of rounds | `nrounds` | Do not fix it — use early stopping on a validation fold. |
| Tree depth | `max_depth` | 2–6. Depth 2–3 captures pairwise interactions; deep trees overfit clinical data fast. |
| Minimum child weight | `min_child_weight` | Raise to regularise on small or imbalanced data. |
| Subsample | `subsample` | 0.5–0.8 adds stochasticity and helps generalisation. |
| Column subsample | `colsample_bytree` | 0.5–1. |
| L2 / L1 penalty | `lambda`, `alpha` | Genuine regularisation; do not leave at zero on small data. |

**The learning rate / number of trees trade-off** is the central one: halving
`eta` roughly doubles the `nrounds` needed. Fix a small `eta`, use early stopping
to choose `nrounds`, and tune the structural parameters around that.

**Do not set `scale_pos_weight` for a risk model.** It is an imbalance
correction, and it distorts the predicted probabilities in exactly the way van
den Goorbergh et al. document. Leave it at 1 and choose a decision threshold
afterwards.

**Objective and evaluation metric:** use `objective = "binary:logistic"` with
`eval_metric = "logloss"`. Selecting on `error` or `auc` will not protect the
probabilities.

## 4. Neural networks on tabular data

If a network is genuinely warranted, the things that matter most:

- **Standardise every input.** Networks are not scale-invariant.
- **Architecture**: start small. Two hidden layers of 32 and 16 units handle most
  tabular problems; capacity is rarely the binding constraint.
- **Regularisation**: dropout (0.2–0.5), weight decay, and above all **early
  stopping** on a validation metric with patience, restoring the best weights.
- **Loss**: binary cross-entropy — the same quantity logistic regression
  minimises. Monitoring AUC while training on cross-entropy is fine; selecting on
  AUC alone is not.
- **Optimiser**: Adam with default settings is a reasonable starting point.
- **Calibrate afterwards.** Modern networks are frequently overconfident.

Sample size is usually the binding constraint. A network with thousands of
weights fitted to a few hundred events will memorise. If the Riley sample-size
criteria would already strain for a 10-parameter regression, a neural network is
not the answer.

## 5. Search strategy

**Grid search** evaluates every combination on a predefined grid. Exhaustive,
interpretable, and exponentially expensive in the number of hyperparameters.

**Random search** samples combinations at random. Usually finds a better model in
the same budget, because performance typically depends strongly on a few
hyperparameters and weakly on the rest — random search spends its budget spread
across the important dimensions rather than replicating the unimportant ones.

**Bayesian / iterative search** (`tune_bayes()` in tidymodels) models the
performance surface and proposes promising points. Worth it when each fit is
expensive.

For most clinical datasets, a space-filling design over 30–60 candidates is a
sensible default. Use `dials::grid_space_filling()` — `grid_latin_hypercube()`
and `grid_max_entropy()` were deprecated in dials 1.3.0, and `tune` now builds
automatic grids with `grid_space_filling()`, which produces optimised designs
that do not depend on the random seed.

## 6. What to record

TRIPOD+AI expects this, and it is also what makes the work reproducible:

- Every hyperparameter searched and its range or grid
- The search strategy and number of candidates evaluated
- The resampling scheme used for tuning, and whether an outer loop or untouched
  test set existed
- The metric optimised (a proper scoring rule, ideally)
- The final selected values
- Software and package versions, and random seeds

If a paper reports "hyperparameters were tuned by cross-validation" and nothing
else, the tuning cannot be appraised and the performance estimate cannot be
trusted.
