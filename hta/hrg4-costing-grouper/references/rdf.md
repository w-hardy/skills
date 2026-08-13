# Record Definition Files

The RDF tells the grouper how to read the input file. It lists field names against the column
positions they occupy. It must contain every mandatory field for the dataset, but the user chooses
the order - the RDF describes the file, so the file does not have to be rearranged to suit a fixed
layout. Additional fields may be included and are ignored during grouping, which is how a local
record key can be carried through a run.

Selecting an RDF automatically sets the database, because the grouper infers which of the seven
algorithms applies from the mandatory fields present.

## How to obtain a valid RDF

**Do not write or generate `.rdf` file contents.** The manual documents the editor, not the file
format, so any hand-constructed file is guesswork. Three legitimate routes:

1. **Use a shipped default RDF.** Files such as `HRG4+_default_APC.rdf` live in the `Default RDF`
   sub-folder of the installation directory, one per dataset. Write the input file to match that
   field order and no RDF work is needed at all. To discover the order, either open the default RDF
   in the RDF editor (the Position column shows each field's column number) or read the header row
   of the matching file in the `Sample Data` sub-folder.

2. **Create one from an input file.** Open the RDF module, pick the database, load a CSV; the first
   30 rows appear in a drag-and-drop pane with numbered columns. Drag each yellow-highlighted field
   name onto its column, or type the number into the Position column directly. Bold field names are
   mandatory and must all be assigned. Save.

3. **Create one from the database alone**, typing positions in directly - useful when the structure
   is known but no sample file is to hand.

Then version-control the resulting `.rdf` alongside the analysis code. A grouper run is only
reproducible if the file that interpreted the input is preserved with it.

## Editing behaviour worth knowing

- **Field Customisation** adjusts the number of repeating fields, e.g. raising diagnoses from the
  default 14 to 20. Doing so reorders the field list - the DIAG and OPER blocks move to the end -
  which changes column positions. Regenerate the input file order after any such change.

  This matters more often than it sounds, because most HES-derived extracts carry more than 14
  diagnoses. Once the counts are altered, the APC field list runs in this order:

  ```
  PROCODET, PROVSPNO, EPIORDER, STARTAGE, SEX, CLASSPAT, ADMISORC, ADMIMETH,
  DISDEST, DISMETH, EPIDUR, MAINSPEF, NEOCARE, TRETSPEF,
  CRITICALCAREDAYS, REHABILITATIONDAYS, SPCDAYS,
  DIAG_01 … DIAG_n, OPER_01 … OPER_n
  ```

  The length of stay adjustment fields sit between `TRETSPEF` and the diagnosis block, and any
  optional field you omit shifts everything after it. Read the actual positions from the Position
  column in the editor before the first production run rather than trusting the layout above - a
  one-column offset produces a file that groups without error and gives wrong HRGs, which is the
  worst failure mode available here.
- Non-mandatory fields can be inserted (Ctrl+I) or removed (Ctrl+Delete). Mandatory fields cannot
  be deleted.
- Assignments are cleared by clicking the `x` beside a field, right-clicking and choosing Unassign,
  or selecting the position and pressing Delete. Clear resets everything.
- Undo and Redo (Ctrl+Z, Ctrl+Y) store a maximum of five changes.

## The four RDF columns

| Column | Purpose |
|---|---|
| Field | The field name. Mandatory fields, shown in bold, cannot be modified |
| Position | The column number of that field in the input file |
| Picture | Character template controlling which character *positions* are used |
| Extract | Characters to ignore wherever they appear in the field |

## Picture

Picture filters by position. `A` keeps the character in that position, `.` ignores it. The template
is applied before validation, so the grouper sees the modified value.

| Template | Effect |
|---|---|
| `AAA.AA` | Uses characters 1, 2, 3, 5, 6; ignores 4 |
| `.A.AAA` | Uses 2, 4, 5, 6; ignores 1 and 3 |
| `.A.` | Uses character 2 only |
| `AA` | Uses characters 1 and 2 (trailing full stops unnecessary when only a leading run is wanted) |

Rules: no spaces between characters, no quotation marks, works on alpha and numeric fields.
Where a field is longer than the template, the template is applied to the left-most portion - which
makes Picture unpredictable on variable-length fields, so use it sparingly there. Picture applies
to file processing only and has no effect in Single Spell.

Removing full stops from diagnosis and procedure codes no longer needs Picture; the grouper strips
them automatically.

## Extract

Extract filters by character, irrespective of position. Every listed character is removed wherever
it occurs; a string of characters is treated as a set, not as a sequence to match.

| Entry | Effect |
|---|---|
| `.` | `abc...d` is read as `abcd` |
| `+$` | `46+$$++` is read as `46` |

Commas cannot be excluded, because the input file is comma-delimited. Like Picture, Extract is
applied before validation and affects file processing only, not Single Spell.

Both features exist to accommodate source systems that cannot be changed. Where the input file is
generated by your own code, cleaning the values in that code is clearer than encoding the cleanup
in the RDF, because the RDF is easy to overlook when someone later asks why a value differs from
the source system.
