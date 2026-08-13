# Diagnostics and convergence

> Sources: van Buuren, *Flexible Imputation of Missing Data*, 2nd ed. (2018), Chapter 6
> ("Imputation in practice"): §6.5 "Algorithmic options" (§6.5.1 visit sequence, §6.5.2
> convergence) and §6.6 "Diagnostics". Also §4.5.5 ("Number of iterations") and the
> slow-convergence example of §4.5.6, and the `loggedEvents` discussion in the §9.1
> Leiden 85+ case study. <https://stefvanbuuren.name/fimd/sec-algoptions.html>,
> verified against the online edition 3 July 2026.

## Reading `loggedEvents`

```r
imp$loggedEvents
```

`NULL` means nothing was flagged. If it's not `NULL`, it's a data frame listing automatic
interventions `mice` made — most commonly:

- **`collinear`**: a predictor was dropped from a variable's imputation model because it's an exact
  or near-exact linear combination of other predictors (often a derived variable that duplicates
  information already in its inputs). Usually harmless, but check that the dropped predictor wasn't
  one you specifically needed.
- **`constant`**: a predictor had (near-)zero variance in the subset of complete cases used to fit
  that variable's model, so it was dropped. Worth a second look if it's a variable you expected to
  matter.

Mention any logged events to the person rather than silently ignoring them — they're not
necessarily fatal but they mean the model that actually ran differs slightly from what was
specified.

## Reading `plot(imp)` (FIMD §6.5.2)

`plot(imp)` shows, for each incomplete variable, the mean and standard deviation of the imputed
values across iterations, one line per imputation stream (one line per `m`). What you want to see:

- **Streams mingling freely**, like a "fat hairy caterpillar" with no systematic separation between
  streams and no trend across iterations. This indicates the chains have reached a stable
  distribution and the choice of starting point no longer matters.
- **What's wrong, and what to do:**
  - *A visible upward or downward trend across iterations, not yet flattened out* → raise `maxit`
    and rerun; the chain hasn't converged yet.
  - *Streams that stay separated from each other rather than mingling* → can indicate an
    order/periodicity problem (the "ping-pong" effect) — a deterministic or near-deterministic
    relationship between two variables being imputed makes the sampler oscillate depending on which
    variable was imputed last. Check for variables that are exact or near-exact functions of each
    other and either remove the redundancy or impute one of them passively from the other instead
    of both stochastically.
  - *Within-cluster (multilevel) chains are extremely slow to settle* → this is expected, not
    necessarily a bug, when missingness rates are high (>50%) and the variables involved are highly
    correlated — convergence genuinely is slower in that regime because there's less information per
    iteration to pull the chain toward the right answer. Run more iterations and more imputations
    rather than concluding the model is broken; if it's still wandering after 100+ iterations with
    high (>90%) missingness in mutually correlated variables, that itself is informative: the data
    may simply not contain enough information to estimate that particular quantity precisely, and
    the right response is a wide, honestly-reported uncertainty interval, not a procedural fix.

## Reading `densityplot(imp)` and `stripplot(imp)` (FIMD §6.6)

These compare the distribution of observed values (blue) against imputed values (magenta/red) for
each incomplete variable.

- **What you want**: imputed values that look like a plausible extension of the observed
  distribution — similar shape, similar range, not concentrated at implausible values (all zeros,
  all at the boundary, a totally different mode).
- **A difference is not automatically wrong** — if missingness is related to the outcome (which is
  exactly the MAR scenario `mice` is trying to correct for), the imputed values for variables that
  are *systematically* different among people with missing data *should* look somewhat different
  from the observed values. The question is whether the difference is plausible given what's known
  about who has missing data, not whether the two distributions are identical.
- **What's actually wrong**: imputations that are impossible (negative count data, a four-level
  factor imputed with a fifth level that doesn't exist), or a method clearly mismatched to the
  variable (e.g. `norm` producing visibly out-of-range continuous values where `pmm` would not).

## Visit sequence and feedback loops (FIMD §6.5.1)

A non-default visit sequence is mainly needed when derived (passively-imputed) variables must be
recomputed *after* their inputs change within the same iteration — see "Visit sequence" in
`predictors-and-methods.md`. A classic failure mode is a variable whose imputation model includes a
derived variable that depends on it, even indirectly through an interaction term — this creates a
feedback loop where the imputation model is, in effect, partly determined by itself. Audit the
predictor matrix for this whenever interactions or passive imputation are involved: for the row
of any target variable, no column should correspond to a term that includes that target.

## Number of iterations in practice (FIMD §4.5.5–4.5.6, §6.5.2)

Five to twenty iterations is the book's usual range and is enough in the overwhelming majority of
applications, because the imputed values themselves carry random noise that speeds up mixing
(unlike typical MCMC applications that need thousands of iterations). Iterations matter much more
when:

- correlations between the incomplete variables are high, and/or
- missing-data rates are high, and/or
- the imputation model has tight cross-variable parameter constraints (e.g. heavily-parameterized
  multilevel or passive-imputation setups).

When none of those apply — the common case — don't over-invest in `maxit`; raise it only if
`plot(imp)` actually shows a trend.
