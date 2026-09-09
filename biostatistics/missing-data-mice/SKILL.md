---
name: missing-data-mice
description: >-
  Write correct, well-structured R code for handling missing data with multiple imputation,
  following Stef van Buuren''s "Flexible Imputation of Missing Data" (FIMD) and the mice package.
  Use this whenever the person has missing values, NAs, item non-response, drop-out, or incomplete
  cases in a real dataset and wants to impute, analyze, or report on it in R, including requests
  phrased as "how do I deal with missing data", "impute these NAs", "run mice on my data", "is this
  MAR or MNAR", "pool my regression after imputation", "missing data in a multilevel or
  longitudinal study", or "what do I write about missing data in my methods section". Also covers
  follow-ups on an existing mice workflow: convergence diagnostics, predictor selection, multilevel
  (2l.) imputation, MNAR sensitivity analysis, or the reporting paragraph. Do not use this for
  simple drop-NA or fillna one-liners where the person just wants rows or columns removed, with no
  statistically principled imputation wanted.
---

# Missing data with mice (Flexible Imputation of Missing Data)

This skill turns an incomplete dataset into a sound multiple-imputation analysis in R, following
the workflow and defaults of Stef van Buuren's *Flexible Imputation of Missing Data* (2nd ed., CRC
Press 2018; free online at <https://stefvanbuuren.name/fimd/>) and implemented in his `mice`
package. The reference files' section anchors were verified against the online edition on 3 July
2026; if the book restructures, trust the chapter *titles* quoted alongside each anchor. Its central
message, to carry through every piece of code this skill produces:
**don't impute once and treat the result as real data — impute several times, analyze each version
separately, and pool the results so the final standard errors honestly reflect how much was
unknown.**

## Why this matters (read before writing code)

Most applied missing-data work goes wrong through one of two silent failure modes that look fine on
the surface:

1. **Single imputation masquerading as multiple imputation.** One plausible value per missing cell
   (mean imputation, regression imputation, a single `mice()` draw treated as final) throws away
   the uncertainty about what the true value was: standard errors too small, p-values too
   optimistic, intervals too narrow. MI fixes this by analyzing *m* completed datasets and
   combining the estimates with Rubin's rules, so the between-imputation variance carries the
   missing-data uncertainty.
2. **Averaging or stacking the imputed datasets instead of pooling.** Averaging the *m* datasets
   into one "best guess" dataset, or row-binding them into one big one, is wrong either way:
   averaging deflates variance (correlations too strong, p-values too small), stacking gives
   unbiased point estimates with invalid standard errors. Always run the analysis model *m* times —
   once per imputed dataset — and combine with `pool()`.

Keep this in mind any time you're tempted to take a shortcut: if a piece of code produces exactly
one completed dataset and feeds it straight into a regression, something has gone wrong.

## Reviewing an existing missing-data workflow

Reviewing someone else's imputation is a different task from building one: Steps 1–4 are the
standard you hold it to, but what you can see and what is worth saying both change. Read
`references/review-checklist.md` before writing anything up — it carries the checklist in the order
the defects turn up, the prior-art and materiality rules, and the pointers to the two cases most
often miscalled.

**Review the specification when you cannot see the data.** Step 0 assumes the dataset is in front of
you. On a gated, synthetic or data-free repository — most regulated trial work — it is not, and the
*specification* is then the object of review: the `mice()` call and its arguments, how `method`,
`predictorMatrix` and `post` are built, the derivation code upstream, the analysis and pooling code
downstream, and any SAP or protocol section committing to a method. Don't stall on access you won't
get, and don't report "I could not run it" as a finding.

## Step 0 — Check what you're working with

Before writing any R, find out:

- **Is there an actual dataset?** If there is a file (CSV, Excel, SPSS .sav, .RData), read it —
  pandas, `pyreadstat`/`pyreadr`, or R — for real column names, types, and missingness counts, so
  the predictor-matrix code matches their columns instead of a generic placeholder. Never guess
  column names. If there is no data to read, review the specification instead (see above).
- **Is R available to actually run?** Try `Rscript -e 'library(mice)'`. If it succeeds, run the
  script against their real data and show real output — far more useful than a script the person
  has to run blindly. If R or `mice` isn't installed, say so plainly, write the script
  anyway, and explain what they should expect to see when they run it. Never claim output you
  didn't produce.
- **Is the data clustered or longitudinal?** Look for an id/group/cluster column (school, hospital,
  subject-over-time); it changes the whole imputation model — see
  `references/multilevel-imputation.md` and `references/longitudinal-data.md`. Ask only if genuinely
  ambiguous: a repeated subject ID or an obvious nesting column is enough to proceed.
- **What's the analysis model?** Every variable, interaction, and transformation in the final
  analysis has to be present in some form in the imputation model — see "Imputation model ⊇ analysis
  model" below. If the person hasn't said what they'll analyze afterward, ask, or proceed with a
  sensible default (a regression of the outcome on the other variables) and say what you assumed.

## Step 1 — Diagnose the missingness before imputing anything

Don't jump straight to `mice()`. A few lines establishing the shape of the problem inform every
choice afterward: method per variable, predictors, whether MI is warranted at all, whether to plan
a sensitivity analysis.

```r
library(mice)

# How much is missing, and in what pattern? (FIMD §4.1; influx/outflux §4.1.3)
md.pattern(dat)   # frequency table of missingness patterns
flux(dat)         # influx/outflux: how well each variable connects to the rest
fluxplot(dat)     # visual version of the above

# Are people with missing X systematically different from people with observed X?
# (a cheap way to build evidence for or against MCAR)
dat$r <- is.na(dat$key_variable)
# compare key auxiliary variables / outcomes by dat$r (table(), t.test(), etc.)
```

Answer these explicitly in your response:

- **How much is missing**, overall and per variable? Don't impute silently if 60% of a column is
  missing — flag it. Variables irrelevant to the analysis, or with high outflux but poor data
  quality, are often better dropped before imputing (`quickpred()` in
  `references/predictors-and-methods.md` if there are many columns).
- **What was filled in before the data reached you?** `is.na()` counts only what the derivation
  code left as `NA`. Read that code: a stop date set to start + median duration is a **single
  imputation** arriving at `mice` as a fully observed value, carrying none of its own uncertainty.
  Name the rule behind each fill-in, count the records it touched, and report them alongside the
  values `mice` imputed (`references/reporting-checklist.md`, which lists the usual suspects).
- **MCAR, MAR, or MNAR?** This can never be proven from the incomplete data alone, but you can
  build a case: if missingness in one variable associates with *other observed* variables (age,
  group, time of measurement), that's evidence for MAR, and putting those variables in the
  imputation model is what makes MAR plausible. Substantive knowledge of *why* values are missing (a
  sensor failed at random vs. patients too sick to be measured) is the other half of the argument
  and should shape the imputation model. If you suspect MNAR (sicker patients are the ones with
  missing blood pressure), flag it and offer a sensitivity analysis —
  see `references/sensitivity-and-nonignorable.md`.
- **Is MI even warranted here?** (FIMD §2.7, "When not to use multiple imputation") If under ~5% of
  cases are incomplete and nothing suggests the pattern is anything but haphazard, complete-case
  analysis may be defensible and a lot less work — say so rather than reflexively reaching for
  `mice()`, and justify it in writing, because FIMD §12.2 warns that reviewers increasingly expect
  MI even then. MI earns its keep when missingness is substantial, related to other variables, or
  when dropping cases would bias the analysis or lose too much power.

## Step 2 — Build the imputation model

### Imputation model ⊇ analysis model

The single most important practical rule in the book (FIMD §6.3.2 on predictor selection, the
underlying congeniality reasoning in §4.5.3–4.5.4): **the imputation model must be at least as
general as the analysis model.** Every outcome, predictor, interaction term, and transformation in
the final analysis needs a counterpart in the imputation step, or you'll bias exactly the
relationships you care about. Concretely:

- Include the outcome variable in the imputation model, even though predictors are imputed against
  it — leaving it out is the most common and damaging mistake here.
- If the analysis model has an interaction or a transformed variable (a ratio, a log, a sum score),
  create that derived variable explicitly and impute it by **passive imputation** rather than
  computing it afterwards from separately-imputed components — see
  `references/predictors-and-methods.md`.
- Auxiliary variables that aren't in the analysis model but correlate with missingness or with the
  incomplete variable are worth including anyway — they cost little and make MAR more plausible.

### Choosing a method per variable

`mice()` picks a default per column type; know what it's doing and override when the type-based
default isn't right:

| Variable type | Default | When to override |
|---|---|---|
| Continuous | `pmm` (predictive mean matching, FIMD §3.4) | Rarely — pmm draws real donors near the regression prediction, so it can't produce an impossible value and respects skew without the right parametric form |
| Binary factor | `logreg` | `cart` for non-linear relationships or interactions you don't want to spell out |
| Unordered categorical (>2 levels) | `polyreg` | `cart` for many categories or complex predictors |
| Ordered categorical | `polr` | — |
| Skewed / bounded / semi-continuous / count | `pmm` still preferred | two-step and transformation approaches: `references/predictors-and-methods.md` |
| Missing within whole clusters / repeated measure | — | `references/multilevel-imputation.md`, `references/longitudinal-data.md` |

```r
meth <- make.method(dat)
meth["some_var"] <- "cart"   # override only where you have a reason to
```

### Predictors

Let `mice()`'s default predictor matrix (every variable predicts every other) stand unless there is
a reason to prune: collinearity warnings, a huge number of columns (`quickpred()`), or a deliberate
exclusion (an ID column, a deterministic function of other columns). Its bias is toward
inclusiveness, the safer side of the congeniality principle above, so don't hand-edit it unless
asked or unless it is visibly causing a problem. See `references/predictors-and-methods.md` for
`quickpred()` and manual `predictorMatrix` editing.

### How many imputations (m), how many iterations (maxit)

- **While building the model**, use a low `m` (5) to iterate quickly.
- **For the final run**, raise `m` (FIMD §2.8, "How many imputations?"). The rule of thumb from
  White, Royston & Wood (2011), quoting von Hippel (2009): *set m to roughly the percentage of
  incomplete cases*, for fractions of missing information up to about 0.5. Compute it from the data
  rather than eyeballing it:

  ```r
  pct_incomplete <- round(100 * mean(!complete.cases(dat)))
  m <- max(pct_incomplete, 5)   # floor of 5 when missingness is light
  ```

  This isn't about a "better" point estimate — low m already gives unbiased estimates — it's about
  standard errors, p-values, and intervals that reproduce if someone reruns with a different seed.
  When missing information is unevenly spread, the percentage of incomplete *rows* is the more
  conservative choice over the average percentage missing per cell — use whichever is larger.
- **`maxit`**: 5–20 iterations is usually enough for the sampler to settle, far fewer than typical
  MCMC (FIMD §4.5.5). Don't just trust the default — check convergence (Step 3) and raise `maxit` if
  the trace lines are still drifting.

```r
imp <- mice(dat, m = 30, maxit = 20, method = meth, seed = 1, print = FALSE)
```

Always set a `seed` so the imputation is reproducible.

## Step 3 — Run it, then check before trusting it

```r
# Did anything go wrong silently? (e.g. collinearity, perfect prediction)
imp$loggedEvents

# Convergence: trace lines should mingle freely with no trend, not drift or separate
plot(imp)

# Plausibility: are imputed values (magenta) a believable extension of the
# observed values (blue), rather than a different population?
densityplot(imp)
stripplot(imp, pch = 20, cex = 1.2)
```

If `loggedEvents` isn't `NULL`, read it — usually a predictor was dropped for collinearity or
near-constant variance, worth mentioning even when it isn't fatal. If the trace lines in `plot(imp)`
show a clear trend rather than noisy mingling, raise `maxit` and rerun. See
`references/diagnostics-and-convergence.md` for specific failure patterns and their fixes (visit
sequence, derived-variable feedback loops, slow convergence under high correlation and high
missingness).

## Step 4 — Analyze and pool — never average, never stack

```r
# impute -> analyze each -> pool; equivalently dat |> mice(...) |> with(...) |> pool()
fit <- with(imp, lm(outcome ~ predictor1 + predictor2))
est <- pool(fit)
summary(est)
```

`with()` re-runs the analysis model once per imputed dataset and stores all `m` fits; `pool()`
combines them with Rubin's rules into one set of estimates, standard errors, and (by default)
adjusted degrees of freedom. This is the only correct way to get a final estimate —
never `complete(imp)` one dataset and analyze that, and never average or row-bind the `m` completed
datasets (FIMD §5.1 singles out averaging and stacking as the shortcuts to avoid). If the
downstream tool doesn't accept a `mids` object, use `complete(imp, "all")` for a list of `m` data
frames, run the analysis on each with `lapply()`/`purrr::map()`, and still finish with `pool()`.

## Step 5 — Sensitivity analysis (when MNAR is plausible)

If Step 1 gave reason to doubt MAR — missingness plausibly depends on the unobserved value itself,
sicker patients being the ones with missing blood pressure — say so and offer a sensitivity
analysis rather than silently assuming MAR. The book's approach (FIMD §9.2.3) is a δ-adjustment:
impute under MAR as usual, then shift the imputed values by a plausible amount and see whether
conclusions change. See `references/sensitivity-and-nonignorable.md` for the `post=` mechanism, the
tipping-point framing, and how to interpret a range of scenarios.

## When a full Bayesian model is the better route

MI is not the only principled option. It is a posterior-predictive procedure, but a **two-stage**
one: imputation and analysis models are fitted separately and can imply different joint
distributions (uncongeniality). A fully Bayesian model samples each missing value as a parameter in
the same run, so there is no seam.

Route to `mice` when many **covariates** are incomplete, or the analysis model is not Bayesian.
Model missingness in place when it is confined to the **outcomes** of an already-Bayesian model, or
when the analysis model's structure is hard to mirror in an imputation model. Both together is
legitimate — impute components, derive the outcome, fit per imputation, imputations separate to the
end. See `references/bayesian-alternatives.md`, which also carries the reviewer checks for
`brm_multiple()`; `brms-modelling` owns the implementation and `trial-based-cea-hta` the
trial-based cost/QALY case.

## Step 6 — Reporting

If the person needs to write up the missing-data handling (methods section, supplementary
material), use the checklist and template in `references/reporting-checklist.md` — 12 questions a
reviewer is likely to ask, plus a fillable paragraph. Pull the actual numbers from this dataset into
the template rather than leaving it generic, and report the by-arm and upstream-fill-in items it
adds to the standard list.

## Deliverable

**On a build task**, unless the person clearly just wants an explanation, write a complete, runnable
`.R` script (not just a snippet) that goes from their raw data to pooled results. Put it where the
work lives — a sensible path in their project, beside the data-preparation code — or show it in the
reply if there is no repository to write into. Structure it in this skill's order: load → diagnose →
build imputation model → run → check convergence → analyze & pool → (sensitivity analysis if
relevant). Comment each section with *why*, not just *what*, so it is something the person can adapt
rather than only run.

**On a review task the deliverable is findings, not a script.** Don't write code into someone's
repository to demonstrate a criticism: quote the lines you object to, say what they produce that is
wrong, and give the corrected call inline. Produce a patch only if the person asked for one.

If you actually executed the script (Step 0), report the real results, including anything
`loggedEvents` flagged. If you couldn't run it, say so and name the convergence and plausibility
checks the person should look at once they do.

## Reference files — the index; each is pointed to inline above where it becomes relevant

- **`references/predictors-and-methods.md`** — the method table in full, `quickpred()` for wide
  data, passive imputation of derived variables, visit sequence.
- **`references/multilevel-imputation.md`** — `2l.`/`2lonly.` methods, predictor-matrix codes for
  cluster variables and random slopes, worked recipes, when fixed cluster dummies are good enough.
- **`references/longitudinal-data.md`** — long vs. wide format, drop-out patterns, broken-stick
  imputation for irregular measurement times.
- **`references/diagnostics-and-convergence.md`** — what failed convergence looks like and why,
  visit sequence, `loggedEvents`.
- **`references/sensitivity-and-nonignorable.md`** — pattern-mixture and selection models, the
  δ-adjustment via `post=`, `squeeze()` (`ifdo()` is not implemented in mice).
- **`references/reporting-checklist.md`** — the 12 reporting questions, upstream fill-ins, a
  fillable template paragraph.
- **`references/bayesian-alternatives.md`** — MI versus a one-stage Bayesian model, uncongeniality
  (including which direction of mismatch is benign), the routing table, `brm_multiple()` reviewer
  checks.
- **`references/review-checklist.md`** — reviewing someone else's imputation: the checklist in
  priority order, the prior-art and materiality rules.

These are reference material, not required reading for every request — for a simple, well-behaved
dataset the core workflow above (Steps 0–4) is often everything you need.
