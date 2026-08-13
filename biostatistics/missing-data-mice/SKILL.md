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

This skill turns a person's incomplete dataset into a statistically sound multiple-imputation
analysis in R, following the workflow and defaults recommended in Stef van Buuren's *Flexible
Imputation of Missing Data* (2nd ed., CRC Press 2018; free online at
<https://stefvanbuuren.name/fimd/>) and implemented in the `mice` package, of which van Buuren
is the original author. The reference files' chapter and section anchors were verified against
the online edition on 3 July 2026; if the online book restructures, trust the chapter *titles*
quoted alongside each anchor. The book's
central message, and the one to carry through every piece of
code this skill produces, is: **don't impute once and treat the result as real data — impute
several times, analyze each version separately, and pool the results so the final standard
errors honestly reflect how much was unknown.**

## Why this matters (read before writing code)

A surprising amount of applied missing-data work goes wrong not because of the wrong method, but
because of two silent failure modes that look fine on the surface:

1. **Single imputation masquerading as multiple imputation.** Filling in one plausible value per
   missing cell (mean imputation, regression imputation, a single `mice()` draw treated as final)
   throws away the uncertainty about what the true value was. Standard errors come out too small,
   p-values too optimistic, confidence intervals too narrow. Multiple imputation fixes this by
   creating *m* completed datasets, analyzing each one, and combining the *m* estimates with
   Rubin's rules — the between-imputation variance in the *m* estimates is exactly the missing-data
   uncertainty that single imputation throws away.
2. **Averaging or stacking the imputed datasets instead of pooling.** It's tempting to average the
   m completed datasets into one "best guess" dataset, or stack them into one big dataset, and
   run a single analysis on that. Both are wrong for inference: averaging deflates variance
   (correlations come out too strong, p-values too small) and stacking gives unbiased point
   estimates but invalid standard errors. Always run the analysis model *m* times — once per
   imputed dataset — and combine with `pool()`.

Keep this in mind any time you're tempted to take a shortcut: if a piece of code produces exactly
one completed dataset and feeds it straight into a regression, something has gone wrong.

## Step 0 — Check what you're working with

Before writing any R, find out:

- **Is there an actual dataset?** If the person uploaded a file (CSV, Excel, SPSS .sav, .RData),
  read it with Python/pandas (or `pyreadstat`/`pyreadr` if needed) to get real column names, dtypes,
  and missingness counts — don't guess column names. This also lets you write predictor-matrix code
  that actually matches their columns instead of a generic placeholder.
- **Is R available to actually run?** Try `Rscript -e 'library(mice)'` via bash. If it succeeds,
  you can run the generated script against their real data and show real output, which is far more
  useful than a script the person has to run blindly. If R or the `mice` package isn't available
  (common — there's no internet access to install packages), say so plainly, write the script
  anyway, and explain what the person should expect to see when they run it themselves. Don't claim
  output you didn't actually produce.
- **Is the data clustered or longitudinal?** Look for an id/group/cluster column (school, hospital,
  subject-over-time). This changes the whole imputation model — see `references/multilevel-imputation.md`
  and `references/longitudinal-data.md`. Ask if it's genuinely ambiguous, but a repeated subject ID
  or an obvious nesting column is enough to proceed without asking.
- **What's the analysis model?** The imputation model should be at least as rich as the analysis
  model (every variable, interaction, and transformation in the final analysis needs to be present,
  in some form, in the imputation model — see "Imputation model ⊇ analysis model" below). If the
  person hasn't said what they'll analyze afterward, ask, or proceed with a sensible default (e.g.
  a regression of the outcome on the other variables) and say what you assumed.

## Step 1 — Diagnose the missingness before imputing anything

Don't jump straight to `mice()`. Spend a few lines establishing the shape of the problem — this is
what informs every choice afterward (which method per variable, which predictors, whether MI is
even warranted, whether to plan a sensitivity analysis).

```r
library(mice)

# How much is missing, and in what pattern? (FIMD §4.1; influx/outflux §4.1.3)
md.pattern(dat)            # frequency table of missingness patterns
flux(dat)                  # influx/outflux: how well each variable connects
                            # to the rest of the data (higher is more useful)
fluxplot(dat)              # visual version of the above

# Are people with missing X systematically different from people with observed X?
# (a classic, cheap way to build evidence for or against MCAR)
dat$r <- is.na(dat$key_variable)
# compare key auxiliary variables / outcomes by dat$r (table(), t.test(), etc.)
```

Use this to answer, explicitly, in your response to the person:

- **How much is missing**, overall and per variable? (Don't just impute silently if 60% of a
  column is missing — flag it. Variables with very high outflux but low data quality, or that are
  irrelevant to the analysis, are often better dropped before imputing — see `quickpred()` in
  `references/predictors-and-methods.md` if there are many columns.)
- **MCAR, MAR, or MNAR?** This can never be proven from the incomplete data alone, but you can
  build a case: if missingness in one variable associates with *other observed* variables
  (age, group, time of measurement), that's evidence for MAR, and including those variables in the
  imputation model is what makes MAR plausible. If the person knows *why* values are missing
  (a sensor failed at random vs. patients too sick to be measured), say so — that's exactly the kind
  of substantive knowledge MAR/MNAR reasoning depends on, and it should shape which variables go
  into the imputation model. If you suspect MNAR (e.g. sicker patients are the ones with missing
  blood pressure), flag it and offer a sensitivity analysis later — see
  `references/sensitivity-and-nonignorable.md`.
- **Is MI even warranted here?** (FIMD §2.7, "When not to use multiple imputation") If under ~5% of
  cases are incomplete and there's no reason to think it's anything but haphazard, plain
  complete-case analysis may be defensible and a lot less work — say so rather than reflexively
  reaching for `mice()` (though note FIMD §12.2's warning that reviewers increasingly expect MI
  even then, so justify the choice in writing). MI earns its keep when missingness is
  substantial, related to other variables, or when dropping cases would bias the analysis or lose
  too much power.

## Step 2 — Build the imputation model

### Imputation model ⊇ analysis model

The single most important practical rule in the book (FIMD §6.3.2 on predictor selection, with
the underlying congeniality/compatibility reasoning in §4.5.3–4.5.4): **the imputation model
must be at least as general as the analysis model.** Every outcome, predictor, interaction term, and transformation
that will appear in the final analysis needs a counterpart in the imputation step, or you'll bias
exactly the relationships you care about. Concretely:

- Include the outcome variable in the imputation model, even if it's the thing predictors are
  imputed against — leaving it out is one of the most common and damaging mistakes.
- If the analysis model has an interaction or a transformed variable (a ratio, a log, a sum score),
  create that derived variable explicitly and impute it via **passive imputation** rather than
  computing it after the fact from separately-imputed components — see
  `references/predictors-and-methods.md`.
- Auxiliary variables that aren't in the analysis model but correlate with missingness or with the
  incomplete variable are worth including anyway — they cost little and make MAR more plausible.

### Choosing a method per variable

`mice()` picks a sensible default automatically based on column type, but know what it's doing and
override it when the type-based default isn't right:

| Variable type | Default method | When to override |
|---|---|---|
| Continuous, no awkward distribution | `pmm` (predictive mean matching) | Usually leave as-is — pmm draws real observed values, so imputations stay in-range and respect skew without needing the right parametric form |
| Binary factor | `logreg` | `cart` if relationships are non-linear or interactions matter and you don't want to specify them all |
| Unordered categorical (>2 levels) | `polyreg` | `cart` for many categories or complex predictors |
| Ordered categorical | `polr` | — |
| Skewed / bounded / semi-continuous / count | `pmm` still usually preferred | see `references/predictors-and-methods.md` for two-step and transformation approaches |
| Variable systematically missing within whole clusters / longitudinal repeated measure | — | see `references/multilevel-imputation.md` / `references/longitudinal-data.md` |

```r
meth <- make.method(dat)
meth["some_var"] <- "cart"   # override only where you have a reason to
```

Predictive mean matching (`pmm`, FIMD §3.4) is the book's preferred default for continuous data
precisely because it never produces an impossible value (negative age, a value outside the observed range) —
it draws from real donors near the regression prediction rather than from a fitted distribution.

### Predictors

Let `mice()`'s default predictor matrix (every variable predicts every other) stand unless there's
a reason to prune it — collinearity warnings, a huge number of columns (use `quickpred()`), or a
deliberate exclusion (an ID column, a variable that's a deterministic function of others). Don't
hand-edit the predictor matrix unless asked or unless the default is visibly causing a problem;
the default's bias is toward inclusiveness, which is the safer default per the congeniality
principle above. See `references/predictors-and-methods.md` for `quickpred()` and manual
`predictorMatrix` editing.

### How many imputations (m), how many iterations (maxit)

- **While building the model**, use a low `m` (5) to iterate quickly.
- **For the final run**, raise `m` (FIMD §2.8, "How many imputations?"). The rule of thumb
  popularised by White, Royston & Wood (2011), quoting von Hippel (2009): *set m to roughly the
  percentage of incomplete cases*; it applies for fractions of missing information up to about
  0.5. Compute it from the data rather than eyeballing it:

  ```r
  pct_incomplete <- round(100 * mean(!complete.cases(dat)))
  m <- max(pct_incomplete, 5)   # floor of 5 even when missingness is light
  ```

  This isn't about getting a "better" point estimate — low m already gives unbiased estimates — it's
  about making your standard errors, p-values, and confidence intervals reproducible if someone
  reruns the analysis with a different seed. If missing information is unevenly spread (one variable
  far more incomplete than the rest, or a few variables driving most of the missingness), the percentage
  of incomplete *rows* is usually the more conservative (larger) choice over the average percentage
  missing per cell — when in doubt, use whichever is larger.
- **`maxit`**: 5–20 iterations is usually enough for the sampler to settle, much lower than
  typical MCMC (FIMD §4.5.5). Don't just trust a default — check convergence (Step 3) and raise `maxit` if the
  trace lines are still drifting.

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

# Plausibility: do imputed values (magenta) look like a believable extension
# of the observed values (blue), not a different population?
densityplot(imp)
stripplot(imp, pch = 20, cex = 1.2)
```

If `loggedEvents` isn't `NULL`, read it — it usually means a predictor was dropped for collinearity
or near-constant variance, which is worth mentioning to the person even if it's not fatal. If the
trace lines in `plot(imp)` show a clear trend rather than noisy mingling, raise `maxit` and rerun.
See `references/diagnostics-and-convergence.md` for what specific failure patterns look like and
how to fix them (visit sequence, derived-variable feedback loops, slow convergence under high
correlation + high missingness).

## Step 4 — Analyze and pool — never average, never stack

```r
# classic three-step workflow
fit <- with(imp, lm(outcome ~ predictor1 + predictor2))
est <- pool(fit)
summary(est)

# equivalent piped version
library(magrittr)
est <- dat %>%
  mice(m = 30, maxit = 20, seed = 1, print = FALSE) %>%
  with(lm(outcome ~ predictor1 + predictor2)) %>%
  pool()
summary(est)
```

`with()` re-runs the analysis model once per imputed dataset and stores all `m` fits; `pool()`
combines them with Rubin's rules into one set of estimates, standard errors, and (by default)
appropriately reduced degrees of freedom. This is the only correct way to get a final estimate —
never call `complete(imp)` to grab one dataset and analyze that, and never average or row-bind the
`m` completed datasets and analyze the result (both are explicitly wrong — see "Why this matters",
and FIMD §5.1 on workflows, which singles out averaging and stacking as the shortcuts to avoid).
If the person's downstream tool doesn't accept a `mids` object (e.g. they need each completed
dataset for something else), use `complete(imp, "all")` to get a list of `m` data frames, run the
analysis on each with `lapply()`/`purrr::map()`, and still finish with `pool()`.

## Step 5 — Sensitivity analysis (when MNAR is plausible)

If Step 1 turned up reason to suspect the data are not MAR — missingness plausibly depends on the
unobserved value itself, e.g. sicker patients are the ones with missing blood pressure — say so and
offer a sensitivity analysis rather than silently assuming MAR. The book's approach (FIMD §9.2.3)
is a simple δ-adjustment: impute under MAR as usual, then shift the imputed values up or down by
a plausible amount and see whether conclusions change. See `references/sensitivity-and-nonignorable.md` for the
`post=` mechanism and how to interpret a range of scenarios.

## Step 6 — Reporting

If the person needs to write up the missing-data handling (methods section, supplementary
material), use the checklist and template in `references/reporting-checklist.md`. It's built around
12 questions a reviewer is likely to ask (amount missing, reasons, consequences, method, software,
m, imputation model, derived variables, diagnostics, pooling, complete-case comparison, sensitivity
analysis) — pull the actual numbers from this dataset into the template rather than leaving it
generic.

## Deliverable

Unless the person clearly just wants an explanation, write a complete, runnable `.R` script (not
just a snippet) that goes from their raw data to pooled results, save it to
`/mnt/user-data/outputs/`, and share it with `present_files`. Structure the script in the same
order as this skill: load → diagnose → build imputation model → run → check convergence → analyze
& pool → (sensitivity analysis if relevant). Comment each section briefly with *why*, not just
*what*, so the script is something the person can learn from and adapt, not just run blindly.

If you were able to actually execute the script (Step 0), report the real results, including
anything `loggedEvents` flagged. If you couldn't run it, say so and explain what convergence and
plausibility checks the person should look at themselves once they run it.

## Reference files — read these when the situation calls for them

- **`references/predictors-and-methods.md`** — full method table (pmm, cart, logreg, polyreg, polr,
  two-level, passive imputation), `quickpred()` for wide data, derived variables, visit sequence.
  Read this whenever you're choosing methods/predictors beyond the basics above, or the dataset has
  many columns, interactions, or derived variables.
- **`references/multilevel-imputation.md`** — `2l.pmm`, `2lonly.pmm`, predictor-matrix codes for
  cluster variables/means/random slopes, and worked recipes for random-intercept and random-slope
  models. Read this whenever the data are clustered (schools, patients within hospitals, repeated
  subjects) and a variable above level 1 has missing values, or random slopes are involved.
- **`references/longitudinal-data.md`** — long vs. wide format, drop-out as a missing-data pattern,
  broken-stick imputation for irregularly-timed measurements. Read this for repeated-measures /
  panel / growth data.
- **`references/diagnostics-and-convergence.md`** — what slow or failed convergence looks like and
  why, visit sequence, handling `loggedEvents`. Read this when `plot(imp)` looks wrong or the person
  reports the imputation behaving strangely.
- **`references/sensitivity-and-nonignorable.md`** — pattern-mixture / selection models, the
  δ-adjustment via `post=`, conditional post-processing and `squeeze()` (note: `ifdo()` is not
  implemented in mice). Read this for MNAR sensitivity analysis.
- **`references/reporting-checklist.md`** — the 12-point reporting checklist and a fillable
  template paragraph for the methods section. Read this when the person needs to write up the
  missing-data handling for a paper, thesis, or report.

These are reference material, not required reading for every request — for a simple, well-behaved
dataset the core workflow above (Steps 0–4) is often everything you need.
