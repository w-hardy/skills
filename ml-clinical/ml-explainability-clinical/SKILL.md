---
name: ml-explainability-clinical
description: Explain and interrogate black-box models on tabular clinical data in R - permutation importance, partial dependence (PDP), accumulated local effects (ALE), SHAP/Shapley values (beeswarm, dependence, waterfall), and LIME - and judge what those explanations do and do not establish. Use whenever opening up a fitted random forest, XGBoost, or similar model to see what it learned, ranking feature importance, plotting the shape of a predictor's effect, or explaining one patient's prediction. Trigger on "SHAP", "Shapley", "feature importance", "variable importance", "permutation importance", "partial dependence", "PDP", "ALE", "LIME", "explainability", "interpretability", "XAI", "black box", "beeswarm", or "why did the model predict this" - even when unnamed. Prefer this over memory, because the log-odds scale trap, interventional versus tree-path-dependent SHAP, and in-sample permutation importance are routinely got wrong. Explanations are not causal effects.
---

# Explainability for Tabular Clinical Models

Explanations describe **the model**, not the disease. Everything below follows
from that. The most valuable thing these tools do is catch a model that predicts
well for the wrong reason; the most dangerous thing they do is look authoritative
while doing it.

## Provenance

Verified 13 August 2026.

- Lundberg SM, Lee S-I. *NeurIPS* 2017 — SHAP
- Lundberg SM et al. *Nat Mach Intell* 2020 — TreeSHAP
- Janzing D, Minorics L, Blöbaum P. *AISTATS* 2020 — interventional Shapley values
- Chen H, Janizek JD, Lundberg S, Lee S-I. arXiv:2006.16234, 2020 — true to the model vs true to the data
- Ribeiro MT, Singh S, Guestrin C. *KDD* 2016 — LIME
- Apley DW, Zhu J. *JRSS-B* 2020 — accumulated local effects
- Ghassemi M, Oakden-Rayner L, Beam AL. *Lancet Digit Health* 2021 — the "false hope" critique
- Molnar C. *Interpretable Machine Learning*, 3rd ed — reference text
- SHAP documentation, shap.readthedocs.io — API behaviour

## The three traps

These account for most of the wrong explainability output in clinical papers.
Check for them before anything else.

### Trap 1 — SHAP values are usually in log-odds, not risk

For a binary classifier, `TreeExplainer` explains the model's **raw margin
output**. For XGBoost `binary:logistic` that is the **log-odds ratio**, so the
SHAP values sum to the log-odds, not to the predicted probability. The same
applies to `shapviz()` on an xgboost model in R, which calls
`predict(..., predcontrib = TRUE)`.

This breaks the sentence people most want to write: "start from the average
prediction, add the SHAP values, arrive at this patient's 12% risk." You arrive
at the log-odds. And because the logistic link is non-linear, a SHAP value of
+0.5 log-odds means a different change in risk depending on where the patient
sits on the curve — so log-odds SHAP values are *not* directly comparable across
patients on the risk scale.

To get probability-space SHAP values that genuinely sum to the predicted risk,
you must ask for them explicitly, and that requires the interventional approach:

```python
explainer = shap.TreeExplainer(
    model,
    data=shap.sample(X_background, 200),   # background dataset required
    feature_perturbation="interventional",
    model_output="probability",            # only valid with interventional
)
```

If you stay on the log-odds scale, say so in the figure caption. Most published
SHAP plots do not, and readers assume risk.

### Trap 2 — "exact" hides a choice of estimand, and one option is not exact

"TreeSHAP is fast and exact" is the standard summary and it is too generous.
There are two different target quantities, and the faster option is an
*approximation* to one of them:

| | `tree_path_dependent` | `interventional` |
|---|---|---|
| Background | Training counts down each tree path | A supplied background dataset |
| Handles dependence | Conditionally (observational) | Breaks dependence per causal rules (Janzing et al.) |
| Needs data argument | No | Yes |
| Speed | Faster | Linear in background size |
| Probability output | Not available | Available |

Chen, Janizek, Lundberg and Lee frame this as **true to the model versus true to
the data**. The observational/conditional version spreads credit among correlated
features that the model may never actually split on ("true to the data"); the
interventional version gives credit only to features the model genuinely uses
("true to the model"), but queries the model on combinations that never occur in
practice. Janzing et al. argue interventional is the right causal reading. Chen
et al. argue the choice is application-dependent. Neither is simply correct.

**The part usually left out:** `tree_path_dependent` TreeSHAP aims at the
observational values but does so using precomputed node counts, which implicitly
assumes feature independence. So under correlation it is exact for *neither*
estimand — it is a fast approximation to the conditional values. Only the
interventional route with an explicit background dataset is exact for what it
targets. If a paper says "exact TreeSHAP" without stating the perturbation
setting, that claim is unverifiable.

Rule of thumb: interventional if the question is "what is this model doing", or
if you want probability-scale values; tree-path-dependent if you want speed and
accept both credit-sharing among correlated features and the independence
approximation. Report which you used — it is not recoverable from the plots.

### Trap 3 — permutation importance computed in-sample

Permuting a feature and measuring the drop in AUROC **on the data the model was
fitted to** measures how much the model memorised, not how much it relies on the
feature for new patients. On a 500-tree random forest fitted to the full dataset,
in-sample permutation importance is close to meaningless.

Always compute it on held-out data, or inside a resampling loop:

```r
set.seed(2026)
idx   <- sample(nrow(dat), 0.7 * nrow(dat))
train <- dat[idx, ]; test <- dat[-idx, ]

rf <- ranger(outcome ~ ., data = train, probability = TRUE)

pred_fun <- function(X.model, newdata) predict(X.model, newdata)$predictions[, 2]

predictor <- iml::Predictor$new(rf, data = test, y = test$outcome,
                                predict.function = pred_fun)

imp <- iml::FeatureImp$new(
  predictor,
  loss          = "logLoss",
  compare       = "ratio",   # DEFAULT: importance = permuted error / original
  n.repetitions = 20
)
plot(imp)
```

Two details that trip people up:

- **`compare = "ratio"` is the default**, so an importance of **1 means no
  effect**, not 0. Use `compare = "difference"` if you want the drop on the loss
  scale. Reporting a ratio as though it were a difference misstates everything.
- **`n.repetitions` defaults to 5.** Raise it — a single permutation is noisy —
  and report the spread. `plot()` shows the median and the 90% quantile, which is
  the honest presentation.

For correlated predictors, `FeatureImp` accepts a named list in `features=` to
compute **joint importance for a group**, which sidesteps the credit-splitting
problem rather than pretending it is not there.

## Choosing a method

| Question | Method |
|---|---|
| Which variables does the model rely on? | Permutation importance (held-out), or mean absolute SHAP |
| What shape does one variable's effect take? | PDP if predictors are near-independent; **ALE otherwise** |
| Why did this patient get this prediction? | SHAP waterfall |
| Global and local from one consistent object | SHAP |
| Reading older literature | LIME |

**PDP versus ALE.** A PDP sets every patient's age to 90 while keeping their own
bloodwork, producing 90-year-olds with the labs of a 40-year-old. The model is
then asked to score patients who cannot exist. ALE instead accumulates local
changes within realistic windows. Clinical predictors are almost always
correlated, so **ALE should be the default** and PDP the exception you justify.
In R, `iml::FeatureEffects$new()` computes **ALE by default** (PDP is opt-in via
`method = "pdp"`), which is the right default; `DALEX` also computes ALE. In
Python, `PyALE`.

**Permutation importance versus mean |SHAP| — not the same quantity.**
Permutation importance is loss-based: it asks how much *performance* degrades.
Mean absolute SHAP is prediction-based: it asks how much the *output moves*. A
feature can move predictions a lot while adding nothing to accuracy. When the two
rankings disagree, that disagreement is informative, not an error to resolve.

## Minimal R workflow

```r
library(ranger); library(xgboost); library(shapviz); library(iml)

# TreeSHAP for xgboost. NOTE: for binary:logistic this returns LOG-ODDS.
sv <- shapviz(xgb_fit, X_pred = data.matrix(X_test), X = X_test)

sv_importance(sv, kind = "beeswarm")        # global: direction and spread
sv_dependence(sv, v = "prior_admissions")   # shape, with interaction colouring
sv_waterfall(sv, row_id = 1)                # one patient
```

**Reading a beeswarm.** One row per feature, ordered by mean |SHAP|. One dot per
patient. Horizontal position is that patient's SHAP value — right pushes
predicted risk up. Colour is the feature's *value*, so a clean red-right /
blue-left gradient means "higher values raise risk". A row where colours are
mixed at the same horizontal position signals an interaction: the feature's
effect depends on something else.

## What explanations cannot establish

Say these plainly whenever presenting explainability output; the visual
authority of these plots outruns their warrant.

- **Not causal.** A SHAP plot saying the model uses high creatinine to raise risk
  does not say creatinine causes readmission, and certainly does not imply that
  lowering creatinine helps. The variable may be a marker for sicker patients.
  Intervening is a different question needing different methods.
- **Not evidence the model is correct.** If the model has learned a scanner
  artefact or a treatment proxy, SHAP will faithfully report that variable as
  important. The explanation is right about the model and thereby exposes that
  the model is wrong — but only if you check it against clinical knowledge rather
  than rationalising whatever appears.
- **Not stable.** Change the background sample, the seed, or the perturbation
  setting and the numbers move. Treat explanations as estimates with their own
  uncertainty.
- **Not a fair division when features are correlated.** Weight and BMI carry
  overlapping information; the credit splits between them in ways that can look
  arbitrary. Low apparent importance may mean a correlated twin took the credit.
  Consider grouping correlated features and explaining the group —
  `shapviz::collapse_shap()` sums SHAP values across a group of columns, and
  `iml::FeatureImp` takes grouped `features=`.
- **Not a substitute for validation.** Ghassemi, Oakden-Rayner and Beam argue
  that current methods offer "false hope" for patient-level decision support:
  explanations describe model behaviour without assuring clinical validity.
  Rigorous external validation, calibration assessment, and decision-analytic
  evaluation are the direct route to trustworthiness. Explainability is a
  debugging and communication tool, and a TRIPOD+AI reporting expectation — not
  evidence of clinical usefulness.

There is a real tension between "a prediction you cannot explain is a clinical
liability" and the Ghassemi critique. Do not paper over it. The defensible
position is that explanations are necessary for *development-time scrutiny* and
*reporting*, and insufficient for *deployment-time trust*.

## Reporting

For a paper, state: which method; which library and version; the perturbation
setting and background dataset for SHAP; **the output scale** (log-odds or
probability); whether importance was computed in-sample or on held-out data; and
how many repetitions. Then state what you concluded and, explicitly, that the
explanation concerns model behaviour rather than causal effect.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
SHAP `TreeExplainer` output scale and the interventional / tree-path-dependent distinction, from the package docs; `shapviz` and `iml` signatures including `compare = "ratio"`; Chen et al. and Kobak & Linderman.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
Apley & Zhu, Molnar and Ghassemi et al. citation details; `PyALE`; the LIME description.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
