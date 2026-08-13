# Reporting checklist and template

> Sources: van Buuren, *Flexible Imputation of Missing Data*, 2nd ed. (2018), §12.2
> ("Reporting": guidelines §12.2.1, template §12.2.2).
> <https://stefvanbuuren.name/fimd/sec-reporting.html>, verified against the online edition
> 3 July 2026. The §12.2.1 list combines reporting guidance from Sterne et al. (2009),
> Enders (2010), Mackinnon (2010), and National Research Council (2010).

## The 12 questions (FIMD §12.2.1)

When writing up a missing-data analysis, work through these and pull the actual numbers from
the person's data rather than leaving anything generic. If space is tight, FIMD suggests
points 1, 2, 4, 5, 6, and 11 as the minimum for the main text; the rest can go in a supplement
or appendix.

1. **Amount of missing data** — number/percentage missing per variable of interest; number of
   fully complete cases; if longitudinal, the number of participants per occasion.
2. **Reasons for missingness** — what's known about why data are missing; whether missingness
   was intentional (e.g. skip patterns by design) and whether it's plausibly related to the
   outcome or to other study variables.
3. **Consequences** — do people with complete vs. incomplete data differ on key variables? What
   would complete-case analysis have missed or biased?
4. **Method** — what was used to handle missing data (multiple imputation, complete-case, etc.)
   and under what assumption (MAR, etc.); how multivariate missingness was handled.
5. **Software** — which package/version, and any settings that differ from defaults.
6. **Number of imputed datasets** — how many (`m`), and how `m` was chosen.
7. **Imputation model** — which variables were included; whether automatic predictor selection
   (`quickpred`) was used; how non-normal/categorical variables were imputed; how design
   features (clustering, weighting, complex sampling) were handled.
8. **Derived variables** — how transformations, recodes, sum scores, and interaction terms were
   handled (passive imputation, if used).
9. **Diagnostics** — how convergence was checked; how observed vs. imputed distributions
   compare; whether imputed values are plausible.
10. **Pooling** — how the m estimates were combined; whether any statistic needed
    transformation before pooling.
11. **Complete-case comparison** — do MI and complete-case analysis agree? If not, what might
    explain the discrepancy?
12. **Sensitivity analysis** — does the set of variables in the imputation model make MAR
    plausible? Do conclusions hold under a plausible nonignorable (MNAR) scenario?

For clinical trials, FIMD (citing National Research Council 2010, recommendation 15) says the
sensitivity analysis (point 12) belongs in the main text, not just a supplement, and (citing
recommendation 9) the missing-data handling plan should ideally have been pre-specified in the
study protocol. §12.2 also notes that editorial expectations have shifted: reviewers
increasingly expect multiple imputation even where authors had a defensible reason not to use
it (e.g. under 5% incomplete cases), so a stated justification for *whatever* was done is
worth its space.

## Template paragraph (adapt the bracketed parts with real numbers from the data)

FIMD §12.2.2 offers a short model paragraph for the methods section; the version below covers
the same reportable elements in this skill's own wording — adapt freely rather than pasting
unchanged.

> Missingness across the [N] analysis variables ranged from [min]% to [max]% per variable, and
> [n_incomplete] of [n_total] records ([pct]%) had at least one missing value. [One sentence on
> the substantive reason for missingness, if known.] Missing values were handled by multiple
> imputation under fully conditional specification, implemented in the R package `mice`
> [version] (van Buuren and Groothuis-Oudshoorn, 2011), using [the package defaults / the
> following non-default settings: ...]. We generated [m] imputed datasets, fitted the analysis
> model to each, and combined the results with Rubin's rules. As a check, the analysis was
> repeated on complete cases only.

In the results section, a pointer to a missing-data table plus one comparison sentence is
usually enough — either noting that the complete-case analysis reached similar conclusions
(with MI typically the more efficient of the two, visible as narrower confidence intervals),
or, if they disagree, describing the direction and size of the discrepancy, giving more weight
to the MI results (which use more of the data and are less exposed to selection effects from
missingness) while offering any candidate explanation for the difference.

If the person has a target journal or field, looking at how missing-data handling is reported
in well-regarded papers from that field is a good supplementary source of phrasing conventions.
