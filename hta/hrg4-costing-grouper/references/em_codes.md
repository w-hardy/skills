# A&E investigation and treatment national codes

Source: NHS Data Model and Dictionary, September 2020 release (archived), *Accident and Emergency
Investigation Table* and *Accident and Emergency Treatment Tables*. Accessed 12 August 2026.
Both items are now retired from the live dictionary - see [Currency](#currency) below.

These are the enumerated sets the grouper's EM validation is built from. Use them to distinguish a
recoverable leading-zero problem from a genuine coding error, and to check a repair before rerunning.

## Code structure

This is the part that resolves most confusion. Both attributes are six-character fields, but only
the national component is submitted to the grouper.

**Investigation** = `n2` national code, plus a *local* sub-analysis of up to 4 characters.
The national component is therefore **always exactly 2 digits**, and the local part must not be
submitted.

**Treatment** = `n2` condition code, plus `n1` *national* sub-analysis, plus local use of up to 3
characters. The national component is therefore **2 or 3 digits** - two for a plain treatment code,
three where a sub-analysed treatment carries its sub-analysis digit. Again, the local part must not
be submitted.

So a 3-character treatment value is not a longer code; it is a 2-digit code with a sub-analysis
digit appended. That positional structure is what makes the recoverability analysis below possible.

## Investigation codes (`INV_*`)

| Code | Investigation | Code | Investigation |
|---|---|---|---|
| 01 | X-ray plain film | 13 | Genitourinary contrast examination/tomography |
| 02 | Electrocardiogram | 14 | Clotting studies |
| 03 | Haematology | 15 | Immunology |
| 04 | Cross match blood / group and save serum | 16 | Cardiac enzymes |
| 05 | Biochemistry | 17 | Arterial/capillary blood gas |
| 06 | Urinalysis | 18 | Toxicology |
| 07 | Bacteriology | 19 | Blood culture |
| 08 | Histology | 20 | Serology |
| 09 | Computerised tomography — **retired 2006-04-01** | 21 | Pregnancy test |
| 10 | Ultrasound | 22 | Dental investigation |
| 11 | Magnetic resonance imaging | 23 | Refraction, orthoptic tests, computerised visual fields |
| 12 | Computerised tomography (excl. genitourinary contrast) | 24 | None |
| | | 99 | Other |

Valid values: `01`-`24` and `99`. Note `09` is retired, so its appearance in current data is itself
a finding.

## Treatment codes (`TREAT_*`)

| Code | Treatment | Code | Treatment |
|---|---|---|---|
| 01\* | Dressing | 31 | Burns review |
| 02 | Bandage/support | 32 | Recall/x-ray review |
| 03\* | Sutures | 33 | Fracture review |
| 04\* | Wound closure (excluding sutures) | 34 | Wound cleaning |
| 05\* | Plaster of Paris | 35 | Dressing/wound review |
| 06 | Splint | 36 | Sling/collar cuff/broad arm sling |
| 07 | Prescription — **retired 2006-04-01** | 37 | Epistaxis control |
| 08 | Removal foreign body | 38 | Nasal airway |
| 09\* | Physiotherapy | 39 | Oral airway |
| 10\* | Manipulation | 40 | Supplemental oxygen |
| 11 | Incision and drainage | 41 | CPAP/NIPPV/bag valve mask |
| 12 | Intravenous cannula | 42 | Arterial line |
| 13 | Central line | 43 | Infusion fluids |
| 14 | Lavage/emesis/charcoal/eye irrigation | 44 | Blood product transfusion |
| 15 | Intubation and airway management | 45 | Pericardiocentesis |
| 16 | Chest drain | 46 | Lumbar puncture |
| 17 | Urinary catheter/suprapubic | 47 | Joint aspiration |
| 18\* | Defibrillation/pacing | 48 | Minor plastic procedure/split skin graft |
| 19 | Resuscitation/CPR | 49 | Active rewarming of hypothermic patient |
| 20 | Minor surgery | 50 | Cooling — control body temperature |
| 21 | Observation/ECG, pulse oximetry/head injury/trends | 51\* | Medication administered |
| 22\* | Guidance/advice only | 52\* | Occupational therapy |
| 23\* | Anaesthesia | 53 | Loan of walking aid (crutches) |
| 24\* | Tetanus | 54 | Social work intervention |
| 25 | Nebuliser/spacer | 55\* | Eye |
| 27 | Other (consider alternatives) | 56 | Dental treatment |
| 28\* | Parenteral thrombolysis | 57 | Prescription/medicines to take away |
| 29\* | Other parenteral drugs | 99 | None (consider guidance/advice option) |
| 30 | Recording vital signs | | |

`*` marks sub-analysed treatments, which may carry a third digit. **`26` is not a valid code** -
the sequence skips it, and `27` sits out of order at the end of the source table.

### Valid sub-analysis digits

| Treatment | Valid third digit |
|---|---|
| 01 Dressing | 1-2 |
| 03 Sutures | 1-3 |
| 04 Wound closure | 1-3 |
| 05 Plaster of Paris | 1-2 |
| 09 Physiotherapy | 1-2 |
| 10 Manipulation | 1-3 |
| 18 Defibrillation/pacing | 1-2 |
| 22 Guidance/advice only | 1-2 |
| 23 Anaesthesia | 1-6 |
| 24 Tetanus | 1-6 |
| 28 Parenteral thrombolysis | 1-2 |
| 29 Other parenteral drugs | 1-2 |
| 51 Medication administered | 1-9 |
| 52 Occupational therapy | 1-2 |
| 55 Eye | 1-5 |

## Recoverability of stripped leading zeros

With the code structure known, the question "can padding repair this?" has an exact answer.

### Investigations — always recoverable

The national component is always 2 digits and has no national sub-analysis, so a 1-character value
can only have come from `0N`. Padding to width 2 is deterministic and lossless. `6` was `06`
(urinalysis); nothing else is possible.

### Treatments — 1-character values are recoverable

A 1-character value `N` could in principle have come from `0N` or `00N`. But `00` is not a valid
treatment code, so `00N` never existed. `N` was `0N`. Padding a 1-character treatment value to
width 2 is safe.

### Treatments — ten 2-character values are ambiguous

A 2-character value `AB` is ambiguous when it is both a valid 2-digit code *and* a plausible
stripping of `0AB` (sub-analysed code `0A` with sub-analysis digit `B`). Working through the
sub-analysed codes in `01`-`09` gives exactly ten such values:

| Observed | Could be | Or was | Both valid? |
|---|---|---|---|
| `11` | 11 incision and drainage | 011 dressing, minor wound/burn/eye | Yes |
| `12` | 12 intravenous cannula | 012 dressing, major wound/burn | Yes |
| `31` | 31 burns review | 031 primary sutures | Yes |
| `32` | 32 recall/x-ray review | 032 secondary/complex suture | Yes |
| `33` | 33 fracture review | 033 removal of sutures/clips | Yes |
| `41` | 41 CPAP/NIPPV/bag valve mask | 041 steristrips | Yes |
| `42` | 42 arterial line | 042 wound glue | Yes |
| `43` | 43 infusion fluids | 043 other wound closure | Yes |
| `51` | 51 medication administered | 051 application of Plaster of Paris | Yes |
| `52` | 52 occupational therapy | 052 removal of Plaster of Paris | Yes |

For these ten, **no rule can distinguish the two readings** - both are valid codes, and both group.
Only the uncorrupted source resolves it. Note how far apart the clinical meanings are: reading
`011` (a minor dressing) as `11` (incision and drainage) is not a marginal error.

Two values look ambiguous but are not: `91` and `92` are not valid 2-digit treatment codes, so they
can only be `091` and `092` (physiotherapy sub-analyses).

### The practical consequence

The grouper will **not** flag any of the ten ambiguous values, because both readings are valid. A
damaged file that has been "repaired" by blanket padding therefore produces a clean run with wrong
HRGs and nothing in the quality file to reveal it. This is why `write_grouper_input()` refuses to
pad `TREAT_*` without an explicit width, and why re-extracting from source with the column typed as
text is the only reliable fix.

An error message that reports a value which *is* a valid national code - such as
`TREAT_01|11|Treatment is invalid` - is not a leading-zero problem at all, because `11` is valid on
its own. Look elsewhere: a local sub-analysis suffix being submitted, a column offset in the RDF,
or a grouper-year mismatch.

## Currency

Both tables were retired from the live NHS Data Model and Dictionary after the September 2020
release; the live pages now redirect to a retirement notice. The Accident and Emergency
Commissioning Data Set (CDS type 010) has been replaced by the Emergency Care Data Set (ECDS), which
codes investigations and treatments in SNOMED CT.

The HRG4+ 2024/25 National Costs Grouper EM logic still takes these retired national codes. So if
the source system produces ECDS, a mapping from SNOMED CT back to the national code components is
needed before grouping. That mapping is not covered by the grouper user manual and should be
confirmed against current National Casemix Office and ECDS guidance rather than assumed - it is the
most likely place for an EM costing pipeline to go quietly wrong.
