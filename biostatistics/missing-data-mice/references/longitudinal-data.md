# Longitudinal / repeated-measures data

> Sources: van Buuren, *Flexible Imputation of Missing Data*, 2nd ed. (2018), Chapter 11
> ("Longitudinal data": §11.1 long and wide format, §11.2 SE Fireworks Disaster Study with
> intention-to-treat in §11.2.1, §11.3 time raster imputation with the broken stick model in
> §11.3.3) and Chapter 10 ("Selection issues": §10.1 correcting for selective drop-out, POPS
> study; §10.2 correcting for nonresponse, Fifth Dutch Growth Study, sample augmentation
> §10.2.4). <https://stefvanbuuren.name/fimd/ch-longitudinal.html>, verified against the
> online edition 3 July 2026.

## Long vs. wide format (FIMD §11.1)

The same repeated-measures data can be arranged two ways, and the choice affects what "a missing
data pattern" even means:

- **Wide format**: one row per subject, one column per occasion (`y_t1`, `y_t2`, `y_t3`, ...).
  Standard `mice()` works directly on this — each timepoint is just another column, and a monotone
  drop-out pattern (subject leaves the study and never returns) is a special case of the general
  multivariate patterns `mice` already handles, often imputed faster precisely because it's
  monotone.
- **Long format**: one row per subject-occasion. Missingness here is more naturally about whole
  rows being absent (a visit that didn't happen) rather than a cell being `NA` within an existing
  row, and a subject's repeated measures are clustered exactly like the multilevel case above
  (subject = cluster). If the analysis model is a mixed/multilevel model fit on long-format data,
  treat the subject ID as the cluster variable and use the `2l.` methods in
  `multilevel-imputation.md`.

For most "impute missing follow-up visits and then fit a mixed model" tasks, decide which format
the final analysis model actually wants and impute in that format directly, rather than imputing
in one format and reshaping afterward — reshaping a `mids` object after the fact is easy to get
wrong (the imputation indices need to follow the data through the reshape).

## Drop-out as a missing data pattern

Monotone drop-out (once missing, always missing for that subject from that point on) is the
single most common longitudinal pattern. In wide format:

```r
md.pattern(wide_dat)   # look for a staircase pattern - that's monotone drop-out
```

A purely monotone pattern can be imputed with `mice`'s faster monotone-specific routine
(`visitSequence` ordered by missingness, optionally `where` restricted) but in practice the general
FCS algorithm handles monotone patterns fine too; only reach for the monotone-specific machinery if
runtime is actually a problem.

### Intention-to-treat reasoning (FIMD §11.2.1)

In trials, drop-out is often informative (people who are doing badly leave), so the *reason* for
drop-out and what's known about it matters for whether MAR is plausible — the same Step 1 reasoning
in SKILL.md applies, just with "time since last observation" and "treatment arm" as natural
candidate predictors of missingness. If a complete-data model is meant to follow an intention-to-
treat principle (analyze subjects according to original assignment regardless of what happened
afterward), make sure the imputation model includes treatment assignment so that principle is
preserved through imputation, not just through using all randomized subjects in the analysis step.

## Broken-stick model for irregularly-timed measurements (FIMD §11.3, esp. §11.3.3)

When subjects are measured at different, irregularly-spaced ages/times (common in growth studies),
neither pure wide format (which assumes a shared grid of timepoints) nor a single polynomial curve
fits well. The broken-stick model fits a linear mixed model with random knots at a shared set of
break ages, giving each subject a piecewise-linear trajectory; missing or irregularly-timed
measurements are then represented on a common time grid this way, after which standard multilevel
imputation methods apply. This is implemented in the `brokenstick` package (companion to `mice`,
same author). Reach for this when the person's repeated-measures data don't share a common
measurement schedule and a smooth individual trajectory is part of the substantive question (e.g.
growth curves, change scores over irregular follow-up).

## Augmenting with known population totals

If there's a complete external benchmark (a census total, a known marginal distribution) that the
observed sample doesn't match well due to selective non-response, FIMD's nonresponse case study
(§10.2, Fifth Dutch Growth Study; augmentation in §10.2.4) augments the working dataset with synthetic records reflecting the known population
margins before imputing, so the imputation model is informed by the discrepancy between sample and
population. This is a more involved, dataset-specific technique — flag it as an option if the
person mentions a known external benchmark their sample doesn't match, but don't reach for it by
default.
