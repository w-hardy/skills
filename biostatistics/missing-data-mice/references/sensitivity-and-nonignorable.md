# Sensitivity analysis and nonignorable (MNAR) missingness

> Sources: van Buuren, *Flexible Imputation of Missing Data*, 2nd ed. (2018), §3.8
> ("Nonignorable missing data": selection models §3.8.2, pattern-mixture models §3.8.3,
> converting between them §3.8.4, sensitivity analysis §3.8.5, Table 3.6 example δ offsets)
> and §9.2 ("Sensitivity analysis", Leiden 85+ Cohort: scenarios §9.2.2, δ-adjustment
> recipe and feedback discussion §9.2.3). <https://stefvanbuuren.name/fimd/sec-nonignorable.html>
> and <https://stefvanbuuren.name/fimd/sec-sensitivity.html>, verified against the online
> edition 3 July 2026. `post`/`squeeze()` behaviour checked against the current mice CRAN
> reference manual (3 July 2026).

## Why this is needed at all

Everything in the core workflow assumes MAR: missingness depends only on observed data, not on
the missing values themselves. That assumption can never be verified from the incomplete data
alone — by definition, you don't have the missing values to check. When there's substantive
reason to doubt MAR (sicker patients are the ones with missing blood pressure; people with the
lowest or highest income are the ones who skip the income question), the honest response isn't
to assume MAR away the problem, but to:

1. First, try to make MAR *more* plausible by adding the right auxiliary variables to the
   imputation model — if you can measure or proxy *why* the data are missing, conditioning on
   that variable goes a long way (this "make the data more MAR" strategy opens FIMD §9.2, with
   the fuller treatment of imputation-model construction in §6.2–6.3).
2. Then run a sensitivity analysis: impute under a range of explicitly nonignorable scenarios
   and see whether the substantive conclusion changes (FIMD §3.8.5, §9.2.2).

## Two ways to formalize a nonignorable model (FIMD §3.8.2–3.8.4)

- **Selection model** (§3.8.2): factors the joint distribution as (data model) × (probability
  of being missing, possibly depending on the data value itself). Conceptually closer to how
  missingness usually arises (a process decides who responds) but the model for the missingness
  mechanism is itself unidentifiable from the data, hard to specify, and small
  misspecifications can change conclusions a lot.
- **Pattern-mixture model** (§3.8.3): factors the other way — (probability of each missingness
  pattern) × (data model conditional on pattern). More transparent for sensitivity analysis
  because every parameter has a direct, statable interpretation ("imputed values for
  non-responders are shifted down by this many units relative to what a MAR model would
  impute") even though it doesn't correspond as directly to a real-world response process.

The practical sensitivity-analysis technique in FIMD is a simple pattern-mixture device: a
shift (δ), scale, or shape adjustment applied on top of an otherwise-ordinary MAR imputation
(§3.8.5 introduces it; §9.2.3 applies it to the Leiden 85+ blood-pressure data).

## The δ-adjustment, via `post=` (FIMD §9.2.3)

Impute as usual under MAR, then shift every imputed value for a chosen variable by a fixed
amount δ, using `mice()`'s `post` processing argument (a named vector of R expressions
evaluated right after that variable's imputation step on each iteration). FIMD's Leiden 85+
example uses δ ∈ {0, −5, −10, −15, −20} mmHg for systolic blood pressure:

```r
delta <- c(0, -5, -10, -15, -20)   # 0 = MAR; increasingly extreme departures from MAR
results <- vector("list", length(delta))

for (i in seq_along(delta)) {
  d <- delta[i]
  post <- make.post(dat)
  post["key_variable"] <- paste("imp[[j]][, i] <- imp[[j]][, i] +", d)
  imp <- mice(dat, post = post, m = 30, maxit = 20, seed = i, print = FALSE)
  fit <- with(imp, lm(outcome ~ key_variable + other_predictors))
  results[[i]] <- pool(fit)
}
```

Then compare the pooled estimate (and its confidence interval) across the δ values. The
standard, honest framing for the person's report:

- δ = 0 is the ordinary MAR analysis — it should match the non-sensitivity-analysis result.
- Each further δ represents a progressively more extreme, but pre-specified and substantively
  motivated, departure from MAR (e.g. "imputed blood pressures 5/10/15/20 mmHg lower than what
  a MAR model would suggest, because non-measurement was associated with frailty in ways an MAR
  model can't fully capture"). FIMD Table 3.6 illustrates the same idea for daily kcal offsets,
  from 0 ("ignorable") through small plausible shifts to −20% ("extreme, not plausible").
- **If the substantive conclusion (sign and rough size of an effect, statistical significance)
  doesn't change across a plausible range of δ, that's a positive, reportable finding** — it
  means the result is robust to the specific way MAR might be violated (this is exactly the
  conclusion of the Leiden 85+ analysis, FIMD §9.2.4). If it does change, that's important to
  report too, and argues for caution in how the result is interpreted, not for picking the δ
  that gives the preferred answer.
- Choose the *range* of δ based on substantive knowledge (a clinically plausible shift), not by
  searching for the value that flips the result.

### A subtlety: feedback through correlated variables (FIMD §9.2.3)

A δ-adjustment applied to one variable propagates to every other variable whose imputation
depends on it, because the adjusted values get used as predictors for imputing other variables
in subsequent iterations. The realized shift in the variable's own mean after a full `mice()`
run can therefore end up somewhat larger in magnitude than δ itself (in the Leiden 85+ data,
δ = −10 produced a realized difference of about −12.5 mmHg against the MAR imputations). If
this matters for interpretation, FIMD notes a damping correction — multiplying δ by
√(1 − r²), where r² is the proportion of explained variance of the imputation model for the
adjusted variable — compensates for the feedback; in the book's data the damped and undamped
versions gave very similar estimates, so it's worth checking but rarely changes the takeaway.

## Conditional adjustments and bounds

- **Conditional post-processing**: the shift (or any other fix-up) can be made to depend on
  other variables by subsetting inside the `post` expression — e.g. shift imputed blood
  pressure only for a subgroup, or set a downstream variable to zero when its gatekeeper
  variable was imputed as "no". The pattern is an ordinary indexed assignment such as
  `post["var"] <- "idx <- <condition on p$data or imp>; imp[[j]][idx, i] <- <value>"`.
  Note: FIMD and older mice documentation mention a convenience wrapper `ifdo()` for exactly
  this, but the current mice manual states plainly that `ifdo()` is **not implemented** — do
  not generate code that calls it; write the indexed `post` expression directly.
- **`squeeze(x, bounds, ...)`** (in mice) clips values back into a specified range — useful
  inside a `post` expression so a δ-adjustment doesn't push values outside what's physically or
  logically possible (e.g. a percentage below 0 or above 100):
  `post["var"] <- "imp[[j]][, i] <- squeeze(imp[[j]][, i], c(0, 100))"`.

## Reporting a sensitivity analysis

Whatever the outcome, report it explicitly — this is one of the points in the reporting
checklist (`reporting-checklist.md`, FIMD §12.2.1 point 12): state the MAR-departure scenarios
considered, the range of δ (or other parameter) used and why that range is substantively
plausible, and whether conclusions were stable across it.
