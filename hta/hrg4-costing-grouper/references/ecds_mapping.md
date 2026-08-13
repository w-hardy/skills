# ECDS to A&E CDS mapping for EM grouping

Sources: NHS England, *Integrated information requirements, costing processes and costing methods*
2024, 2025 and 2026; NHS England Digital, *SUS PbR reference manual - Emergency Care Data Set
(ECDS)*; NHS England, *National Cost Collection guidance 2026*. Accessed 12 August 2026.

## Why this step exists

The Emergency Care Data Set replaced the A&E Commissioning Data Set (CDS type 010) and codes
investigations, treatments and diagnoses in SNOMED CT. The grouper does not consume SNOMED.

The costing standards are explicit and have been unchanged across the 2024, 2025 and 2026 editions:
the Casemix groupers do not yet group to emergency care HRGs from SNOMED CT, so providers must also
include the investigation and treatment fields and HRG codes from the A&E CDS, mapped from the
SNOMED CT codes using the mapping tool supplied on the Secondary Uses Service webpage. The
underlying mappings are supplied by the Royal College of Emergency Medicine. Submitted SNOMED CT
codes will be used directly once the grouper is updated to consume them.

The costing standards distinguish Feed 2a (the original A&E CDS feed) from Feed 2b (ECDS), the
latter signalling the intended move once the HRG grouping issue is resolved. Until then both
terminologies are in play: bring SNOMED CT into the costing system for the emergency care procedure
field, and carry the mapped A&E investigation and treatment codes for grouping.

**Check the current year's Approved Costing Guidance before relying on any of this.** The entire
mapping step disappears the moment the grouper consumes SNOMED directly, and that change will
arrive through the costing standards rather than through the grouper manual.

## Two routes, and which to prefer

**Central (preferred).** SUS+ performs the translation and derives the HRGs, applying the same
mapping logic to both the A&E and ECDS extracts, and issues a report confirming the mappings
applied. Taking the derived investigation and treatment fields from SUS+ means the HRGs reconcile
with the national position by construction.

**Local.** Map in your own pipeline using the SUS mapping tool. HRGs will match the central
derivation exactly only if the mapping is done correctly, so treat the SUS+ report as the
reconciliation target rather than an optional check. Local mapping is worth doing when the costing
pipeline needs to run ahead of the SUS+ return, or when the mapping needs auditing.

Either way the mapping table is externally supplied and versioned. It is not bundled with this
skill and must not be reconstructed from memory or inferred from code descriptions.

## Where the mapping is lossy

This is the part that determines your unmapped rate, and it is structural rather than a data
quality failure on your side.

- **SNOMED has no "other" concept.** Activity that used to be recorded against the A&E "other"
  codes - investigation `99`, treatment `27` - cannot be represented, so some ECDS activity has no
  A&E equivalent to map back to.
- **Retired codes.** Several A&E codes representing practice that no longer occurs in the emergency
  department, or that added no clinical value, were retired at the ECDS transition. Investigation
  `09` (computerised tomography) and treatment `07` (prescription) were both retired in 2006 and
  should not appear at all.
- **Codes outside the approved list.** The Royal College specifies an approved SNOMED CT list per
  item. Departments can submit codes outside it, but SUS+ marks these as errors and omits them from
  user extracts: the code column is blank and a companion `IsItemCodeApproved` column carries
  `FALSE`. So a blank investigation or treatment field in an extract is not necessarily an absent
  investigation - check the flag before treating it as missing data.

Every one of these produces attendances that cannot be grouped from mapped codes. Decide and
document how they are costed, because the residual will not go away by improving the pipeline.

## Pipeline placement

The mapping sits between the source extract and `write_grouper_input()`:

```
ECDS extract (SNOMED CT)
  -> join to the SUS mapping table            -> A&E investigation and treatment codes
  -> validate_em_codes()                      -> catch unmapped and malformed values
  -> write_grouper_input(dataset = "EM")      -> quote-free ASCII, zero-padded
  -> grouper                                  -> EM_HRG
```

Two failure modes specific to this join, both silent:

1. **Type coercion on the join key.** Mapping tables arrive as spreadsheets. Read both sides as
   character, or the A&E codes lose their leading zeros in the join itself - reintroducing exactly
   the problem described in `em_codes.md`, after you had clean data.
2. **Many-to-one collapse.** Several SNOMED codes map to one A&E code, which is expected. A
   one-to-many mapping is not, and silently multiplies rows. Check the row count across the join.

`scripts/map_ecds_codes.R` handles both, and reports the unmapped rate by category.

## What to record

Alongside the grouper and database versions:

- the mapping tool version and its retrieval date
- the ECDS version in force for the period (v4.0 from 1 July 2023, with subsequent refset updates)
- the unmapped rate, split into no-equivalent-code, unapproved-code and genuinely-missing
- whether the mapped codes were reconciled against the SUS+ derivation, and any residual difference

## Related cost collection rules

Emergency care HRGs sit in subchapter VB. Two rules from the 2026 National Cost Collection guidance
that intersect with grouping rather than costing:

- Patients brought in dead - A&E patient group code `70`, or ECDS discharge status SNOMED CT
  `63238001` - are submitted against HRG `VB99Z`.
- Streamed attendances (triaged away from the ED to a GP, pharmacist or other service) are treated
  as PbR exclusions by SUS+ and flagged with an exclusion reason. GP streaming attendances are
  costed but then excluded from the patient-level submission and reported on separate reconciliation
  lines.

These are handled outside the grouper, but they explain gaps between attendance counts and grouped
records that would otherwise look like grouping failures.
