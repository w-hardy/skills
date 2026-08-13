---
name: hrg4-costing-grouper
description: Prepare inputs for, run, and interpret output from the NHS England HRG4+ National Costs Grouper (National Casemix Office) - covering Record Definition Files, the seven dataset specifications (APC, NAC, EM, NRD, ACC, PCC, NCC), batch and command-line invocation, joining grouped HRGs back to source records in R, and diagnosing UZ01Z and other validation failures. Use whenever the work involves deriving HRGs from patient-level activity, National Cost Collection submissions, grouping HES or local PAS extracts, spell versus episode HRGs, unbundled or critical care HRGs, Record Definition Files, or grouper error codes - including implicit cases like "I need HRGs on my costing extract", "half my A&E records failed to group", or "which output file gives one row per spell".
---

# HRG4+ National Costs Grouper

The Grouper turns patient-level activity into Healthcare Resource Groups for cost collection
and costing analysis. Most of the pain in using it comes not from the software but from three
places: input files that silently lose meaning on the way out of Excel, an RDF that no longer
matches the file it is describing, and outputs whose row structure is misunderstood so that
spell-level values get double-counted.

This skill is built from the *HRG4+ 2024/25 National Costs Grouper User Manual* (NHS England,
National Casemix Office, February 2025, v1.0) plus practical pipeline guidance.

## Scope, and what to say when asked beyond it

Cover confidently: input preparation, RDF structure, running the grouper, output file layout,
linking outputs to source records, and error interpretation.

Outside this skill's source material, so say so rather than guessing:

- **Which HRG a given code combination produces.** That is the design logic, documented in the
  Chapter Summaries and code-to-group workbooks in the Grouper Documentation Suite.
- **Unit costs, tariffs, or reference costs.** The grouper assigns HRGs; it attaches no prices.
- **Payment grouper behaviour.** Best Practice Tariff and Attendance HRG fields exist in the
  output schema but are only populated by payment groupers, not this costing grouper.
- **The internal file format of a `.rdf` file.** The manual documents the RDF editor, not the
  file syntax, so never fabricate RDF file contents - see `references/rdf.md` for what to do
  instead.

Each grouper release is published for a financial year - the 2024/25 costs grouper exposes
`NC_2425` databases and is intended for 2024/25 activity - and older releases stay available in the
archive. For a National Cost Collection submission, use the mandated grouper for that year.

For research spanning several years the choice is a design decision, not a rule: contemporaneous
grouping preserves the classification in force at the time, single-grouper grouping preserves
comparability across the series. The real constraint is classification version, since codes retired
since the activity was recorded will fail validation. See `references/multi_year_grouping.md`, which
includes the test to run before choosing.

## The mental model

Three things go in, several files come out.

1. **An input CSV** - one row per unit of activity. What a row means differs by dataset: an
   episode (APC), an attendance (NAC, EM), a critical care period (ACC), a critical care day
   (PCC, NCC), or a haemodialysis session / peritoneal dialysis day (NRD).
2. **A Record Definition File (RDF)** - maps column *positions* in that CSV to grouper field
   names. The RDF must contain every mandatory field for the dataset, in whatever order the
   file happens to use. Extra columns are permitted and ignored.
3. **A grouping logic** - APC, NAC, EM, NRD, ACC, PCC or NCC. The grouper infers it from the
   fields present in the RDF, or takes it explicitly from the `-l` flag.

Out comes a copy of the input with HRG columns appended, plus a quality (error) file, a summary
file, and normalised "relational" files. Everything is linked by `RowNo`, a row number the
grouper generates *after* it sorts the input - so `RowNo` is the join key, never the original
row order.

## Workflow

Work through these in order. Steps 2 and 5 are where most defects are introduced and caught.

### 1. Identify the dataset and its mandatory fields

Read the relevant table in `references/datasets.md`. Confirm what one input row represents,
which fields are mandatory, and which fields carry leading zeros.

For emergency care there is a step before this one. The grouper does not consume SNOMED CT, so
ECDS-sourced activity must first be mapped back to A&E CDS investigation and treatment codes using
the externally supplied SUS mapping - see `references/ecds_mapping.md`. Some activity has no A&E
equivalent and cannot be grouped at all, which is a permanent residual rather than a fixable
defect.

### 2. Build the input file

The grouper reads plain comma-separated ASCII with no text qualifiers. Rules that matter, and
why:

- **Leading zeros are meaningful in every dataset except APC and NAC.** EM treatment code `011`
  and `11` are different codes; the same applies to `RENALMOD`, `RENALSITE`, `RENALACCESS`,
  `CCUF` and `CCAC_*`. Excel strips them on open. Keep every code column as character in R and
  never round-trip the file through a default Excel open.
- **No quotation marks around fields.** Text qualifiers break parsing; write with
  `readr::write_csv(quote = "none")` or equivalent.
- **Commas cannot be escaped or extracted** - the file is comma-delimited, so no field may
  contain one.
- **Trailing empty fields can truncate rows** when files are produced via Excel. Adding a dummy
  rightmost column of a constant value (`"x"`) protects the row structure. Harmless in R-written
  files, but keep it if anyone else will touch the file in Excel.
- **Dates are `YYYYMMDD` character strings**, not R `Date` objects.
- **Full stops in ICD-10 and OPCS-4 codes are stripped automatically.** The RDF Picture feature
  is no longer needed for that.
- **One decision needs care: the spell identifier.** APC records are sorted and grouped by
  provider code plus `PROVSPNO` plus `EPIORDER`. An alternative spell identifier may be
  substituted for the Hospital Provider Spell Number, but it must be unique within provider
  across the whole extract, or unrelated episodes will be merged into one spell. `EPIORDER`
  values 98 and 99 are invalid, and duplicate `EPIORDER` within a spell is an error.
- **Spell-constant fields** - `SEX`, `CLASSPAT`, `ADMISORC` and `ADMIMETH` must be identical on
  every episode in a spell; `DISDEST` and `DISMETH` are taken from the last episode. Derive these
  at spell level and broadcast them, rather than carrying episode-level values through.

`scripts/write_grouper_input.R` handles the mechanical parts - column ordering against a field
list, type coercion to character, zero-padding, validation of missing mandatory fields, and a
quote-free ASCII write.

### 3. Settle the RDF

Two safe routes, described fully in `references/rdf.md`:

- **Match the shipped default RDF** (simplest). Read the field order from the sample data header
  or the RDF editor, then write the input file in that order.
- **Build an RDF once in the RDF editor GUI**, save it, and put it under version control next to
  the analysis code. Treat it as a project artefact, because a pipeline is only reproducible if
  the RDF that interpreted the file is preserved with it.

Never hand-write or generate `.rdf` file contents; the format is not documented.

Extracts carrying more than 14 diagnoses need the repeat counts raised in Field Customisation,
which moves the DIAG and OPER blocks behind `CRITICALCAREDAYS`, `REHABILITATIONDAYS` and
`SPCDAYS` and shifts every position after `TRETSPEF`. Read the resulting order from the editor's
Position column - a one-column offset groups cleanly and produces wrong HRGs, with nothing in the
quality file to reveal it.

### 4. Run it

Prefer the command line over the Batch GUI - it is scriptable, logs to file, and returns an exit
code, which is what makes a costing pipeline reproducible and auditable.

```bat
@echo off
cd /d "c:\Program Files\NHS England\HRG4+ 2024_25 National Costs Grouper"
HRGGrouperc.exe -i "c:\data\apc.csv" -o "c:\data\output.csv" -d "c:\data\apc.rdf" -l APC -h > "c:\data\hrg.log"
if %ERRORLEVEL% neq 0 echo Error in command, please check hrg.log
```

`-h` declares that the input has a header row; omit it if row one is data. `-t` suppresses
headers on the output. Any path containing spaces must be quoted. Exit code 0 means success;
anything else means the run failed - see the exit code table in `references/running.md`.

A non-zero exit code is a *run* failure. A successful run with thousands of `UZ01Z` HRGs is a
*data* failure, and the exit code will still be 0. Both need checking.

### 5. Verify before using the output

Three checks, in this order:

1. **Exit code** - non-zero means nothing downstream is trustworthy.
2. **`[name]_summary.csv`** - record count in versus records submitted, error counts, and the
   grouper and database versions. Capture those version strings; they belong in the methods
   section of anything written up.
3. **`[name]_quality_rel.csv`** - tabulate errors by code type and message. Fix *classes* of
   error, not individual rows. A block of `TREAT_01` failures across A&E records is almost
   always stripped leading zeros, not thousands of independent coding mistakes.

An error rate that is implausibly low is as suspicious as one that is high - it often means the
input was silently truncated and only a fraction of records were read.

### 6. Join outputs back to source data

`RowNo` is the key. `scripts/read_grouper_output.R` reads an output set and returns tidy episode,
spell, unbundled-HRG and error tables.

The trap worth stating explicitly: in APC, `[name]_FCE.csv` carries *both* episode and spell
fields, and the spell fields are repeated on every episode of the spell. Summing `SpellLOS` or
counting `SpellHRG` over that file multiplies multi-episode spells. Use `[name]_spell.csv`
(one row per spell) for spell-level work, or filter `SpellReportFlag == 1` to keep only the
dominant episode.

Which file to reach for:

| Question | File |
|---|---|
| Episode HRGs, grouping method, dominant procedure | `_FCE.csv` (APC) or `_attend` / `_renal` / `_acc` / `_pcc` / `_ncc` |
| Spell HRGs, spell LOS, episode counts | `_spell.csv`, never `_FCE.csv` |
| Unbundled and critical care HRGs | `_ub_rel.csv` - one row per HRG |
| Why records failed | `_quality_rel.csv` - one row per error |
| Grouper and database version, record counts | `_summary.csv` |

Note that `SpellLOS` is the sum of `CalcEpidur`, so it is length of stay *net of* critical care,
rehabilitation and specialist palliative care days - those are costed through unbundled HRGs
instead. Add `SpellCCDays` back if gross length of stay is wanted, and say which is being reported.

Full output file and field descriptions are in `references/outputs.md`.

## Errors and UZ01Z

When a mandatory field fails validation the grouper assigns `UZ01Z Data Invalid for Grouping`.
Validation does not stop at the first error, so the quality file lists everything wrong with a
record at once.

The cascade rules are asymmetric and worth holding in mind when reconciling counts:

- **Upward:** any episode with `UZ01Z` makes the whole spell `UZ01Z`. A `UZ01Z` unbundled HRG
  also forces the episode, and therefore the spell, to `UZ01Z`.
- **Not downward:** a `UZ01Z` episode HRG does not overwrite its unbundled HRGs.
- **Critical care is exempt from the upward cascade.** The `XA*`, `XB*` and `XC*` unbundled HRGs
  for neonatal, paediatric and adult critical care are produced by separate modules outside the
  APC commissioning data set, so they cannot force a core APC HRG to `UZ01Z`.

Error messages are pipe-delimited: `Code Type|Code|Error Message`, with the code section blank
when the error is an absent value. Categories (`UZ01`-`UZ06` clinical coding, `UZ11`-`UZ21`
critical care and renal grouping) are listed with worked examples in `references/errors.md`,
alongside a triage recipe that maps common error patterns to their usual root cause.

## Reporting and reproducibility

For work that will be reviewed - a cost collection submission, a trial-based costing, a paper -
these details make the grouping step auditable and should be recorded alongside the analysis:

- grouper product and version, and the internal database version, both from `_summary.csv`
- the RDF file itself, version-controlled with the code
- record counts in and out, plus the percentage of records assigned `UZ01Z` and how they were
  handled (excluded, or costed by another route)
- the grouping logic used, and which grouper release was applied to which activity years

## Reference files

Read the one that fits the question rather than all of them:

- `references/datasets.md` - input field specifications for all seven datasets, with mandation,
  valid ranges, leading-zero flags, and what one row represents
- `references/outputs.md` - every output file and field, per dataset, and how they join
- `references/errors.md` - error types, error categories with examples, and a triage recipe
- `references/em_codes.md` - verified A&E investigation and treatment national code tables, code
  structure, and which stripped-zero damage is repairable
- `references/ecds_mapping.md` - mapping ECDS SNOMED CT back to A&E national codes for EM grouping,
  where the mapping is lossy, and what to record
- `references/multi_year_grouping.md` - choosing a grouper release for activity spanning several
  years, classification-version limits, and local versus SUS-derived HRGs
- `references/rdf.md` - RDF concepts, Picture and Extract, and how to obtain a valid RDF
- `references/running.md` - installation, GUI Batch and Single Spell use, command-line parameters,
  exit codes, and the sample-data smoke test

## Scripts

- `scripts/write_grouper_input.R` - build a grouper-safe input CSV from a data frame
- `scripts/read_grouper_output.R` - read and tidy an output set, and join HRGs back to source
- `scripts/map_ecds_codes.R` - map ECDS SNOMED CT codes to A&E national codes and audit what failed
