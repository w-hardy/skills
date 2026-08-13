# Grouping activity spanning multiple years

Each grouper release is published for a specific financial year - the 2024/25 National Costs
Grouper produces HRG4+ output for the 2024/25 collection - and older releases remain available in
the Archived material section of the National Casemix Office downloads page.

That is a statement of intended use, not a technical restriction. The manual does not say a grouper
refuses activity from another year, and no NHS England or National Casemix Office guidance on
retrospective grouping for research was found when this reference was written (August 2026). So
treat what follows as a design decision to be justified in the methods, not a rule to comply with.

## When the year is fixed for you

For a National Cost Collection submission, use the grouper mandated for that collection year. No
judgement involved, and nothing below applies.

## For a research series, two defensible strategies

**Contemporaneous grouping** - each year's activity through its own grouper. Reproduces the
classification in force at the time, and is what allows a join to that year's published national
costs. The cost is that an HRG does not mean the same thing across the series: subchapters are
redesigned, splits added and removed, codes remapped. Apparent casemix change is partly
classification drift.

**Single-grouper grouping** - all years through one release, usually the most recent. Gives a
consistent classification, so movement in the series reflects activity rather than design. The cost
is that year-specific national costs no longer attach cleanly, and historical activity is being
described in a classification that did not exist at the time.

Neither is wrong. Let the estimand decide: "what would this activity cost at today's classification
and prices" points to a single current grouper, "what did this cost at the time" points to
contemporaneous grouping. Grouping two or three years both ways as a sensitivity analysis is cheap
and makes the divergence measurable rather than hypothetical.

## The binding constraint is classification version, not grouper year

This is what actually determines whether single-grouper grouping is feasible, and it is an empirical
question about your data.

Each grouper is built against particular ICD-10 and OPCS-4 versions. The 2016/17 release was updated
for ICD-10 5th edition, effective 1 April 2016; the 2017/18 release for OPCS-4.8, effective 1 April
2017; and the pattern continues with later OPCS-4 revisions. The grouper validates every code
against its internal design database, so a code retired since the activity was recorded is simply
invalid and produces `UZ01Z`.

**Test this before committing to a strategy.** Group a sample from the oldest year with the
candidate grouper and count `Procedure is invalid` and `Diagnosis is invalid` in
`[name]_quality_rel.csv`:

```r
out <- read_grouper_output("test_oldest_year", dataset = "APC")

out$errors |>
  dplyr::filter(grepl("invalid$", `Error Message`)) |>
  dplyr::count(`Code Type` = sub("_\\d+$", "", `Code Type`), `Error Message`)
```

A negligible rate means single-grouper grouping is viable. A material rate means the loss is
concentrated in the early years, which biases a time series exactly where you least want it - at
that point group contemporaneously, or restrict the series to years that group cleanly.

## Quantifying classification drift

The Roots workbook, published in the documentation suite for each release, identifies new HRGs,
deleted HRGs and changes to existing HRG labels between designs. Chaining the Roots workbooks across
the study period gives a defensible account of which HRGs are comparable across the series and which
are artefacts of redesign - far better than asserting comparability or abandoning it wholesale.

The Summary of Changes document for each release covers design and software changes since the
previous one.

## Check whether you need to group at all

HES and SUS extracts often already carry HRGs, derived centrally with the grouper in force for that
year. For a ten-year series that may be exactly the contemporaneous grouping you want, at no effort.

Where local grouping is still needed, be aware that SUS-derived HRGs and locally grouped HRGs can
differ, for documented reasons rather than error:

- SUS derives its own spell identifier and uses it in place of the Hospital Provider Spell Number,
  so different sets of episodes can be treated as a spell. The disparity is expected to be extremely
  rare in normal use.
- The SUS derivation of critical care days is more comprehensive than the guidance supporting local
  grouping, and includes extra validation checks that can allocate a different number of critical
  care days and so change grouping results.
- In outpatient care SUS can produce two HRGs, adding an attendance HRG where the derived HRG is not
  tariffed, calculated as if grouping after removing all procedures except those beginning `X62`.

If a reconciliation between local and SUS HRGs is part of the work, expect and explain these rather
than treating them as defects.

## What to record

- which grouper release was used for which activity years, and the reasoning
- the ICD-10 and OPCS-4 versions in force for each year of activity
- the invalid-code rate by year, if a single grouper was used across years
- whether HRG comparability across the series was assessed against the Roots workbooks
- if reconciling to SUS or HES HRGs, which differences were expected
