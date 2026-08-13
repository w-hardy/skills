# Installing and running the grouper

## Requirements and installation

Windows only. The software targets Windows 7 / Windows Server 2008 R2 or later; it runs on Vista
but that is unsupported. Minimum specification is a 1 GHz 32- or 64-bit processor, 1 GB RAM (32-bit)
or 2 GB (64-bit), 47 MB free disk space for a minimal install excluding example files, and
Microsoft .NET Framework 4.5 or above.

Download from the National Casemix Office downloads page for groupers and tools, under Costing
Grouper; older versions sit in the Archived material section. Extract the installer from the zip
and run it. Installation may require elevated permissions.

The installer offers three components. Main executables is compulsory. Sample Files installs a
duplicate copy of the sample data and default RDFs to a chosen location (defaulting to Documents),
which is useful because the copies inside Program Files are usually not editable. Visual Studio
Runtime installs the Microsoft Visual C++ redistributable, skipping the step if a suitable version
is already present.

Accept the default installation directory (`C:\Program Files\NHS England\HRG4+ 2024_25 National
Costs Grouper`) unless there is a reason not to: reinstalling or updating to the same folder
overwrites cleanly, whereas a bespoke location complicates both updates and uninstallation. Keep
the standard set of application files and folders together in their own sub-directory. There is no
need to uninstall before reinstalling. Uninstall.exe will not execute correctly if files have been
renamed, added or scattered outside a distinct folder, and it halts if `GUIShell.exe` is running.

**Smoke test after installing.** Open the grouper, start a new Batch, load the sample APC RDF and
sample APC data, and process. A correct install reports 90% grouped and 10% ungrouped. Each sample
file is built to produce that ratio with its own grouper, so a different result means either the
sample data has been altered or it belongs to a different grouper. Re-download a clean copy before
investigating further.

## The GUI

`GUIShell.exe` is the application. Four modules, each openable from the navigation pane, the home
screen links, File > New, or a shortcut key:

| Module | Shortcut | Purpose |
|---|---|---|
| Batch | Alt+B | Process a whole file |
| Single Spell | Alt+S | Enter one record by hand and watch the outputs change |
| RDF | Alt+R | Create or edit Record Definition Files |
| Viewer | Alt+V | Inspect an input or output file against an RDF |

### Batch

Select an RDF (the Database box then populates itself), select the input file, tick **Input data has
headings** if row one is a header, choose an output location and file name, tick **Add headings to
output data**, then Process. Files can be dragged into the boxes instead of browsing. The File
Preview pane shows the input parsed against the RDF, which is the quickest way to spot a column
misalignment before committing to a run.

While processing, the Complete bar shows progress and the Error Ratio bar shows detected errors;
Cancel stops the run. The Output log reports the session, including records grouped, and is also
written to `hrg.log` (Help > View Log).

### Single Spell

Best used to understand *why* a particular record grouped as it did. Enter values by hand and the
episode and spell outputs recalculate live, so the effect of adding a procedure or changing a code
is immediately visible - the manual's worked example shows a record moving from diagnosis-driven
to procedure-driven grouping as soon as a procedure code is entered, then changing HRG again when a
different code becomes dominant. Mandatory fields are shown in bold; auto-complete offers ten
matching codes with descriptions as you type, narrowing as more characters are added.

Useful behaviours: Field Customisation adjusts the number of diagnosis and procedure fields;
drag and drop moves values between fields (available for APC diagnoses and procedures, NAC
procedures, EM investigations and treatments, PCC activity codes, diagnoses and procedures, and NCC
activity codes); undo and redo store five changes and Reset returns to defaults. Multi-episode
spells can be built for datasets that support them, with certain values carried forward to the new
episode but not non-primary diagnoses or procedure codes.

Pasting from Excel works two ways. "Smart pasting" - copying a header row plus a data row - matches
by header name, so column order need not match, but the headers must be named exactly as the Single
Spell fields are. Pasting a row or column of codes without headers transposes them into consecutive
fields from wherever the paste starts, which is quicker but depends on starting in the right place.

Copy options: Ctrl+C gives transposed CSV suitable for building input files, Ctrl+Shift+C gives
transposed TSV for Excel, Ctrl+Alt+C preserves layout and descriptions. Export saves as HTML (a
printable replica of the window) or CSV (transposed with headers, in a form usable for grouping).

Errors are highlighted in red in both the input and output panes - entering an invalid `SEX` value,
for instance, immediately shows the field in red and the message in the episode output.

### Viewer

Displays a file organised into the columns defined by an RDF, over paged output. Use file header
keeps the file's own headers visible under the RDF field names while paging. Each column has a
filter supporting exact values and the wildcards `*` (any characters, zero or more) and `?` (a
single character, repeatable) - so `F*` on `DIAG_01` returns all diagnoses beginning with F, and
`??0` on `MAINSPEF` returns three-character specialty codes ending in 0. Leaving the filter box
blank filters for blanks. Individual filters clear via the bin icon, or all at once via the clear
all filters icon.

Double-clicking a row - or right-clicking and choosing Open in single spell - opens that record in
Single Spell with the fields populated, which is the fastest route from "this row looks wrong" to
"here is why it grouped that way". It requires an RDF to be selected alongside the file.

## Command line

The scriptable route, and the one to prefer for any pipeline that needs to be re-run or audited.

```
HRGGrouperc.exe -i Input_File -o Output_File -d RDF_File -l Grouping_Logic [-h] [-t] [-v] [-?] [> Log_File]
```

| Parameter | Meaning |
|---|---|
| `-i` | Path and filename of the input file |
| `-o` | Path and filename of the output file |
| `-d` | Path and filename of the record definition file |
| `-l` | Grouping logic: `APC`, `ACC`, `EM`, `NAC`, `PCC`, `NRD` or `NCC` |
| `-h` | Optional. The input file has a header row. Omit when row one is data |
| `-t` | Optional. Suppress field names in the top row of the output files |
| `-v` | Optional. Increase log verbosity |
| `-?` | Optional. List available parameters. Cannot be combined with others |
| `> Log_File` | Optional. Redirect log output to a file instead of the screen |

Parameter values containing spaces must be enclosed in double quotes.

Two script patterns, both valid - change into the installation directory and call the executable by
name, or stay in the working directory and give the executable a fully qualified path:

```bat
@echo off
cd /d "c:\Program Files\NHS England\HRG4+ 2024_25 National Costs Grouper"
HRGGrouperc.exe -i "c:\Temp\data\apc.csv" -o "c:\Temp\data\output.csv" -d "c:\Temp\data\apc.rdf" -l APC -h > "c:\Temp\data\hrg.log"
if %ERRORLEVEL% neq 0 echo Error in command, please check hrg.log
pause
```

```bat
@echo off
cd /d "c:\Temp\data"
"c:\Program Files\NHS England\HRG4+ 2024_25 National Costs Grouper\HRGGrouperc.exe" -i "apc.csv" -o "output.csv" -d "apc.rdf" -l APC -h > "hrg.log"
if %ERRORLEVEL% neq 0 echo Error in command, please check hrg.log
pause
```

The `ERRORLEVEL` check is what turns a script into something trustworthy - without it a failed run
looks identical to a successful one until someone reads the log.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Process successful |
| 1 | Unknown switch encountered |
| 2 | Unknown parameter |
| 3 | RDF parameter is blank |
| 4 | Input file parameter is blank |
| 5 | Output file parameter is blank |
| 6 | Unknown grouping logic parameter |
| 7 | A range of processing failures - more than one plugin present and not selected; failure loading the plugin schema or record definition file; zero records; logic not specified and not derivable from the RDF; logic not found in plugin; RDF missing a required field; reports not found; report logic not found; sorting cancelled or failed; failed to load plugin; grouping cancelled; unhandled exception |
| 8 | Failed to set logic |
| 9 | Failed to set output file |
| 10 | Failed to set RDF file |
| 11 | Failed to set input file |

Exit code 7 is the broad one; the log file identifies which of its causes applied.

## Calling the grouper from R

The grouper is a Windows executable, so an R pipeline shells out to it. Keep the RDF path, logic
and header flag as explicit arguments rather than hard-coding them, and check the status:

```r
run_grouper <- function(input_csv, output_csv, rdf, logic,
                        has_header = TRUE,
                        exe = "C:/Program Files/NHS England/HRG4+ 2024_25 National Costs Grouper/HRGGrouperc.exe",
                        log_file = file.path(dirname(output_csv), "hrg.log")) {

  args <- c("-i", shQuote(input_csv), "-o", shQuote(output_csv),
            "-d", shQuote(rdf),       "-l", logic)
  if (has_header) args <- c(args, "-h")

  status <- system2(exe, args, stdout = log_file, stderr = log_file)

  if (status != 0) {
    stop("Grouper exited with code ", status, ". See ", log_file, call. = FALSE)
  }
  invisible(status)
}
```

A zero status means the run completed, not that the data grouped well - always follow it with the
summary and quality checks described in `outputs.md`.
