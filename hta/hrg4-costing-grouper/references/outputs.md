# Output files

The output name supplied at run time is written below as `[name]`; the grouper appends a standard
suffix to produce each file. All output is comma-separated text. Very large files may exceed
Excel's row limit and produce a "File not loaded completely" message - read them in R rather than
opening them.

Contents:
1. [How the files link together](#how-the-files-link-together)
2. [APC output](#apc-output-eleven-files)
3. [NAC output](#nac-output-seven-files)
4. [EM output](#em-output-five-files)
5. [NRD output](#nrd-output-five-files)
6. [ACC output](#acc-output-five-files)
7. [PCC output](#pcc-output-six-files)
8. [NCC output](#ncc-output-six-files)
9. [Fields that are never populated](#fields-that-are-never-populated)

---

## How the files link together

**`RowNo`** is a grouper-generated identifier used to link rows across output files. It is
assigned after sorting, so it does not correspond to input row order. Because a file's role in a
relationship varies, `RowNo` values are not necessarily consecutive within a file - the spell-level
files skip values wherever the input contained multi-episode spells. That is by design, not
corruption.

**`Iteration`** appears in relational files to distinguish repeated occurrences within one key -
several error messages on one record, or several unbundled HRGs on one episode. Values start at 1
and carry no meaning beyond ordering.

**Relational files** carry `_rel` in the name. They normalise repeated items into rows rather than
a variable number of columns, which is what makes them the right choice for R: a file with a
variable column count per row cannot be read cleanly, whereas `[name]_ub_rel.csv` gives one row per
unbundled HRG and joins straight back on `RowNo`.

To reconnect grouped output to source records, carry your own record key through as an extra
non-mandatory column in the input file. Extra columns are ignored by the grouper and reproduced in
the output, so the key survives the round trip and removes any dependence on row order.

---

## APC output (eleven files)

| File | Contents |
|---|---|
| `[name].csv` | Index listing the other output files |
| `[name]_sort.csv` | The input data after sorting by provider, spell and episode number, with `RowNo` |
| `[name]_FCE.csv` | The main file: input data plus episode-level *and* spell-level fields |
| `[name]_spell.csv` | One row per spell |
| `[name]_quality.csv` | One row per episode containing an error |
| `[name]_FCE_rel.csv` | Episode output, relational form |
| `[name]_spell_rel.csv` | Spell output, relational form |
| `[name]_quality_rel.csv` | One row per error per episode |
| `[name]_flag_rel.csv` | Best Practice Tariff flags - populated by payment groupers only |
| `[name]_ub_rel.csv` | One row per unbundled HRG; episodes without unbundled HRGs are absent |
| `[name]_summary.csv` | Single row describing the run |

The `fce_flag_rel` file was retired in January 2022 and is no longer produced.

### Episode-level fields

| Field | Meaning |
|---|---|
| `FCE_HRG` | The episode HRG |
| `GroupingMethodFlag` | How the HRG was derived: `P` procedure driven, `D` diagnosis driven, `B` burns driven, `M` multiple trauma, `G` global exception, `U` error |
| `DominantProcedure` | The procedure that drove grouping |
| `FCE_PBC` | Programme budgeting code for the episode |
| `CalcEpidur` | Episode duration less critical care, rehabilitation and specialist palliative care days; zero if the deductions exceed the duration |
| `SpellReportFlag` | 1 on the episode holding the grouping variable used to derive the spell HRG (the dominant episode), 0 otherwise |

### Spell-level fields

| Field | Meaning |
|---|---|
| `SpellHRG` | The spell HRG |
| `SpellGroupingMethodFlag` | Same code set as `GroupingMethodFlag` |
| `SpellDominantProcedure` | Dominant procedure for the spell |
| `SpellPDiag` | Primary diagnosis used for spell grouping |
| `SpellSDiag` | First secondary diagnosis in the spell |
| `SpellEpisodeCount` | Number of episodes in the spell |
| `SpellLOS` | Spell duration used for grouping - the total of `CalcEpidur` across the spell |
| `SpellCCDays` | Critical care days in the spell |
| `SpellPBC` | Programme budgeting code for the spell |

**The double-counting trap.** In `[name]_FCE.csv` the spell fields are repeated on every episode
of the spell. Aggregating `SpellLOS`, `SpellCCDays` or spell HRG counts over that file inflates
multi-episode spells by the number of episodes they contain. Either use `[name]_spell.csv`, or
filter to `SpellReportFlag == 1`.

### Unbundled HRGs

`UnbundledHRGs` appears in `_FCE.csv` and `_spell.csv` as a variable number of trailing columns.
Where rehabilitation or specialist palliative care days are reported, an eligible unbundled HRG is
followed by an asterisk and a day count. Only certain HRGs are eligible for these multipliers, and
the count is written against every instance of the unbundled code generated in the episode - so
where several are output, the same day count appears more than once. Read the asterisk as "days
recorded and used for the length of stay adjustment" and nothing more; it will not survive
naive summation.

Prefer `[name]_ub_rel.csv` for analysis. Its columns are `RowNo`, `Iteration` and `UnbundledHRGs` -
one row per unbundled HRG, joining straight back to the episode on `RowNo`.

### Quality file

`[name]_quality.csv` reproduces the input plus a variable number of error fields, each formatted
`Code Type|Code|Error Message`. `[name]_quality_rel.csv` splits these into columns - `RowNo`,
`Iteration`, `Code Type`, `Code`, `Error Message` - which is far easier to tabulate.

### Summary file

One row: grouper version, internal HRG database version, episode count, spell count, episode error
count, spell error count, run start and end times, input filename, output filename, and the RDF
path used. The two version strings and the RDF path are the provenance record for the run.

---

## NAC output (seven files)

`[name].csv`, `[name]_attend.csv` (main), `[name]_quality.csv`, `[name]_attend_rel.csv`,
`[name]_quality_rel.csv`, `[name]_ub_rel.csv`, `[name]_summary.csv`. The redundant `flag_rel` file
is no longer produced.

Main fields: `NAC_HRG` (the outpatient HRG), `GroupingMethodFlag` (`P` procedure driven,
`G` global exception, `O` outpatient default, `U` error), `DominantProcedure`, and `AttendanceHRG`
(payment groupers only - it supports the national reimbursement system where the outpatient core
non-`WF*` HRG has no mandatory tariff, and is equivalent to `SUS_HRG`).

Summary fields are attendance count and attendance error count in place of episode/spell counts.

---

## EM output (five files)

`[name].csv`, `[name]_attend.csv` (input data plus `RowNo` and `EM_HRG`), `[name]_quality.csv`,
`[name]_quality_rel.csv`, `[name]_summary.csv`. No unbundled HRG file - EM produces a single
attendance HRG per record.

---

## NRD output (five files)

`[name].csv`, `[name]_renal.csv` (input data plus `RowNo` and `NRD_HRG`), `[name]_quality.csv`,
`[name]_quality_rel.csv`, `[name]_summary.csv`. Summary counts are NRD record count and NRD record
error count.

---

## ACC output (five files)

`[name].csv`, `[name]_acc.csv` (main), `[name]_quality.csv`, `[name]_quality_rel.csv`,
`[name]_summary.csv`.

| Field | Meaning |
|---|---|
| `ACC_HRG` | The unbundled HRG for the adult critical care period |
| `Calc_CC_Days` | `CC_Discharge_Date - CC_Start_Date + 1`; set to -1 where the dates are unusable |
| `CC_Warning_Flag` | Blank if date and respiratory support checks pass, `F` if any fail |

`CC_Warning_Flag` is set to `F` when any of the following hold: `Calc_CC_Days` is -1 (discharge
before start, or a date blank, invalid or wrongly formatted); level 2 plus level 3 days exceed
`Calc_CC_Days`; advanced plus basic respiratory support days exceed `Calc_CC_Days`; or advanced
plus basic respiratory support days exceed level 2 plus level 3 days.

A warning flag does **not** prevent HRG derivation - the HRG is still produced. It is a data
quality signal, and for costing work it is worth reporting the flagged proportion rather than
silently accepting those periods.

---

## PCC output (six files)

`[name].csv`, `[name]_sort.csv`, `[name]_pcc.csv` (main, carrying `PCC_HRG` - the unbundled HRG for
the paediatric critical care day), `[name]_quality.csv`, `[name]_quality_rel.csv`,
`[name]_summary.csv`.

---

## NCC output (six files)

`[name].csv`, `[name]_sort.csv`, `[name]_ncc.csv` (main, carrying `NCC_HRG` - the unbundled HRG for
the neonatal critical care day), `[name]_quality.csv`, `[name]_quality_rel.csv`,
`[name]_summary.csv`.

---

## Fields that are never populated

These exist in the output schema but carry no value in the costing grouper. Building logic on them
produces silently empty results.

Redundant in APC output: `ReportingEPIDUR`, `FCETrimpoint`, `FCEExcessBeddays`, `FCESSC_Ct`
(defaults to 0), `FCESSCs1`-`FCESSCs7`, `ReportingSpellLOS`, `SpellTrimpoint`,
`SpellExcessBeddays`, `SpellSSC_Ct` (defaults to 0), `SpellSSCs1`-`SpellSSCs7`, `SpellFlag_Ct`
(defaults to 0), `SpellFlag1`-`SpellFlag7`.

Payment grouper only, therefore empty here: `SpellBP_Ct`, `SpellBP1`-`SpellBP7`,
`[name]_flag_rel.csv`, and NAC's `AttendanceHRG`.

Redundant in NAC output: `AttendSSC_Ct`, `AttendSSC1`-`AttendSSC5`, `AttendBP_Ct`,
`AttendBP1`-`AttendBP5`, `AttendFlag_Ct`, `AttendFlag1`-`AttendFlag5`.

Trimpoints and excess bed days are payment concepts. If a costing analysis needs long-stay
adjustment, it has to come from elsewhere.
