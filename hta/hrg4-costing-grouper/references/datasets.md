# Input dataset specifications

Seven datasets are supported. Field order in the input file is defined by the RDF, not by the
order below. Mandatory fields must be present in both the RDF and the input file for grouping to
occur; optional fields may be absent or blank.

Contents:
1. [Admitted Patient Care (APC)](#admitted-patient-care-apc)
2. [Non-Admitted Consultations (NAC)](#non-admitted-consultations-nac)
3. [Emergency Medicine (EM)](#emergency-medicine-em)
4. [Renal Dialysis (NRD)](#renal-dialysis-nrd)
5. [Adult Critical Care (ACC)](#adult-critical-care-acc)
6. [Paediatric Critical Care (PCC)](#paediatric-critical-care-pcc)
7. [Neonatal Critical Care (NCC)](#neonatal-critical-care-ncc)
8. [Leading zeros at a glance](#leading-zeros-at-a-glance)

Values are validated against enumerated sets, generally NHS Data Dictionary national codes.

---

## Admitted Patient Care (APC)

One row per finished consultant episode. The grouper sorts on provider code, spell number and
episode number before grouping, so episodes need not arrive in order - but spell identity depends
entirely on those three fields.

| Field | Source concept | Mandation | Notes |
|---|---|---|---|
| PROCODET | Organisation code (provider) | Mandatory | Supplied but not validated. First 3 characters for NHS organisations, all 5 for non-NHS |
| PROVSPNO | Hospital provider spell number, or an alternative spell identifier | Mandatory | Not validated. Must be unique within provider |
| EPIORDER | Episode number | Mandatory | Duplicates within a spell are an error; values 98 and 99 are invalid for grouping |
| STARTAGE | Derived age | Mandatory | Whole years rounded down: episode start date minus birth date |
| SEX | Person gender code current | Mandatory | Must be identical for all episodes in the spell |
| CLASSPAT | Patient classification code | Mandatory | Must be identical for all episodes in the spell |
| ADMISORC | Source of admission (spell) | Mandatory | Must be identical for all episodes in the spell |
| ADMIMETH | Admission method (spell) | Mandatory | Must be identical for all episodes in the spell |
| DISDEST | Discharge destination (spell) | Mandatory | Valid value required; the grouper uses the last episode's value |
| DISMETH | Discharge method (spell) | Mandatory | Valid value required; the grouper uses the last episode's value |
| EPIDUR | Derived episode duration | Mandatory | Whole days, episode end minus start. Range 0-99999 |
| MAINSPEF | Care professional main specialty | Mandatory | Valid value required |
| NEOCARE | Neonatal level of care | Optional | May be blank |
| TRETSPEF | Activity treatment function code | Mandatory | Valid value required |
| DIAG_01 | Primary diagnosis (ICD-10) | Mandatory | Blank generates an error |
| DIAG_02 - DIAG_99 | Secondary diagnoses (ICD-10) | Optional | Blank allowed |
| OPER_01 - OPER_99 | Primary procedure and procedures (OPCS-4) | Optional | Valid OPCS-4 or blank |
| CRITICALCAREDAYS | Derived | Optional | Range 0-99999. Count of distinct days in the episode spent in critical care. A critical care day falling on the last day of a non-final episode is assigned to the *next* episode |
| REHABILITATIONDAYS | Length of stay adjustment (rehabilitation) | Optional | Range 0-99999. Only days meeting the Data Dictionary definition; discrete periods with the same adjustment reason within an episode are totalled into one figure |
| SPCDAYS | Length of stay adjustment (specialist palliative care) | Optional | Range 0-99999. Same totalling rule as above |

Derived durations: `CalcEpidur = EPIDUR - (CRITICALCAREDAYS + REHABILITATIONDAYS + SPCDAYS)`,
floored at zero. `SpellLOS` is the sum of `CalcEpidur` across the spell's episodes.

Default RDF field count for diagnoses is 14, adjustable via Field Customisation (the manual's
worked example raises diagnoses and procedures to 20). Increasing the count moves the DIAG and
OPER blocks to the end of the field list, which changes column positions - regenerate the input
file order whenever this is changed.

---

## Non-Admitted Consultations (NAC)

One row per outpatient attendance or ward attender contact. Diagnosis codes are deliberately
excluded from the NAC algorithm because they are not mandated in the outpatient commissioning
data set - supplying them changes nothing.

| Field | Source concept | Mandation | Notes |
|---|---|---|---|
| STARTAGE | Derived age | Mandatory | Whole years rounded down: appointment date minus birth date |
| SEX | Person gender code current | Mandatory | Valid value required |
| MAINSPEF | Care professional main specialty | Mandatory | Valid value required |
| TRETSPEF | Activity treatment function code | Mandatory | Valid value required |
| FIRSTATT | First attendance code | Mandatory | Valid value required |
| OPER_01 - OPER_99 | Primary procedure and procedures (OPCS-4) | Optional | Valid OPCS-4 or blank |

---

## Emergency Medicine (EM)

One row per A&E attendance.

| Field | Source concept | Mandation | Notes |
|---|---|---|---|
| AGE | Derived age | Mandatory | Whole years rounded down: arrival date minus birth date. Validated but not used in grouping |
| AEPATIENTGROUP | A&E patient group | Optional | Valid code or blank |
| INV_01 - INV_99 | A&E investigations | Optional | National code component only, always 2 digits (`01`-`24`, `99`). Leading zeros required. Do not submit the local sub-analysis |
| TREAT_01 - TREAT_99 | A&E treatments | Optional | National code component only: a 2-digit treatment code, optionally followed by 1 national sub-analysis digit. Leading zeros required. Do not submit the local part |

The single most common EM failure is stripped leading zeros. The full code tables, and which damaged
values can and cannot be repaired, are in `references/em_codes.md` - ten 2-character treatment values
are irrecoverably ambiguous and pass validation under either reading.

Note also that these national code tables were retired from the NHS Data Dictionary after September
2020 and the A&E CDS has been replaced by ECDS (SNOMED CT), while the grouper still expects the
national codes. ECDS-sourced data needs mapping before grouping.

---

## Renal Dialysis (NRD)

One row per haemodialysis session, or per day of peritoneal dialysis. Fields come from the
National Renal Dataset.

| Field | Source concept | Mandation | Notes |
|---|---|---|---|
| RENALMOD | Renal treatment modality code | Mandatory | Leading zeros significant |
| RENALSITE | Renal treatment primary supervision code | Mandatory | Leading zeros significant |
| RENALACCESS | Renal dialysis access type | Optional | Leading zeros significant |
| HBV | Hepatitis B antigen status | Optional | `NEG`, `POS` or `UNK` |
| HCV | Hepatitis C antibody status | Optional | `NEG`, `POS` or `UNK` |
| HIV | HIV status | Optional | `NEG`, `POS` or `UNK` |
| AGE | Derived age | Mandatory | Whole years at session start date. Range 0-130 |

---

## Adult Critical Care (ACC)

One row per adult critical care period.

| Field | Source concept | Mandation | Notes |
|---|---|---|---|
| CCUF | Critical care unit function | Mandatory | Some codes carry leading zeros; the grouper accepts them with or without |
| BCSD | Basic cardiovascular support days | Optional | 0-99999 |
| ACSD | Advanced cardiovascular support days | Optional | 0-99999 |
| BRSD | Basic respiratory support days | Optional | 0-99999 |
| ARSD | Advanced respiratory support days | Optional | 0-99999 |
| RSD | Renal support days | Optional | 0-99999 |
| NSD | Neurological support days | Optional | 0-99999 |
| DSD | Dermatological support days | Optional | 0-99999 |
| LSD | Liver support days | Optional | 0-99999 |
| CCL2D | Critical care level 2 days | Optional | 0-99999 |
| CCL3D | Critical care level 3 days | Optional | 0-99999 |
| CC_Start_Date | Critical care start date | Optional | `YYYYMMDD` |
| CC_Discharge_Date | Critical care discharge date | Optional | `YYYYMMDD` |

The two dates are used only to compute critical care days in the output; they play no part in HRG
derivation. They do drive the `CC_Warning_Flag` consistency checks - see `outputs.md`.

---

## Paediatric Critical Care (PCC)

One row per paediatric critical care day. Records are sorted by provider code and local
identifier into activity date order before grouping. A move between units with different critical
care unit function codes starts a new critical care period, which can produce more than one
record - and therefore more than one HRG - for the day of transfer.

| Field | Source concept | Mandation | Notes |
|---|---|---|---|
| PROCODET | Organisation code (provider) | Optional | A value must be supplied but is not validated. First 3 characters for NHS organisations, all 5 for non-NHS |
| CCLocalID | Critical care local identifier | Optional | Together with the provider field this is the key that holds one patient's records together, so both must in practice be supplied |
| CCDate | Activity date (critical care) | Mandatory | `YYYYMMDD` |
| DISDATE | Discharge date (spell) | Mandatory | `YYYYMMDD` |
| DISMETH | Discharge method (spell) | Mandatory | Valid value required; taken from the last episode |
| CCUF | Critical care unit function | Mandatory | Leading zeros accepted with or without |
| CCAC_01 | Critical care activity code | Optional | Valid PCCMDS code; leading zeros accepted with or without |
| CCAC_02 - CCAC_20 | Critical care activity codes | Optional | As above |
| OPER_01 - OPER_20 | High cost drugs (OPCS) | Optional | Valid OPCS-4 or blank; the PCC MDS specifies only two appropriate procedure codes |
| DIAG_01 - DIAG_99 | Primary and secondary diagnoses (ICD-10) | Optional | Valid ICD-10 or blank |

Note the mandation quirk: `PROCODET` and `CCLocalID` are formally optional but function as the
record-linking key, so omitting them breaks period construction.

---

## Neonatal Critical Care (NCC)

One row per neonatal critical care day, sorted by provider code and local identifier into activity
date order. The same unit-transfer rule as PCC applies.

| Field | Source concept | Mandation | Notes |
|---|---|---|---|
| PROCODET | Organisation code (provider) | Optional | Supplied but not validated; 3 characters NHS, 5 non-NHS |
| CCLocalID | Critical care local identifier | Optional | Record-linking key with provider; supply it |
| CCDate | Activity date (critical care) | Mandatory | `YYYYMMDD` |
| DISDATE | Discharge date (spell) | Mandatory | `YYYYMMDD` |
| CCUF | Critical care unit function | Mandatory | Leading zeros accepted with or without |
| AGE_DAYS | Derived | Derived | Whole days rounded down: activity date minus birth date |
| DISMETH | Discharge method (spell) | Mandatory | Valid value required; taken from the last episode |
| GestLen | Gestation length at delivery | Mandatory | Whole numbers 10 to 49 inclusive |
| PERWT | Person weight | Mandatory | Kilograms to 3 decimal places, greater than 0 and less than 10. Leading zeros accepted |
| CCAC_01 | Critical care activity code | Optional | Valid NCCMDS code; leading zeros accepted with or without |
| CCAC_02 - CCAC_20 | Critical care activity codes | Optional | As above |

---

## Leading zeros at a glance

Every dataset except APC and NAC uses leading zeros in at least one field. Where zeros are
significant, losing them either fails validation or - worse - groups to a different, valid HRG
without any error being raised.

| Dataset | Fields where zeros matter | Behaviour if lost |
|---|---|---|
| APC | none | - |
| NAC | none | - |
| EM | `INV_*`, `TREAT_*` | Silent mis-grouping (`011` vs `11`) |
| NRD | `RENALMOD`, `RENALSITE`, `RENALACCESS` | Validation failure or mis-grouping |
| ACC | `CCUF` | Tolerated - accepted with or without |
| PCC | `CCUF`, `CCAC_*` | Tolerated - accepted with or without |
| NCC | `CCUF`, `CCAC_*`, `PERWT` | Tolerated - accepted with or without |

To import a CSV into Excel while preserving zeros: Data > From Text/CSV > Import > Transform Data,
change the affected columns from Number to Text (choosing "Replace current" conversion), then
Close & Load. Repeat the type change for every affected column. Avoiding Excel entirely and
writing from R is safer.
