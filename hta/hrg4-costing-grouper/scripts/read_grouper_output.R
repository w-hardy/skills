# read_grouper_output.R ---------------------------------------------------------
# Read an HRG4+ National Costs Grouper output set into tidy tables, check the run,
# and rejoin HRGs to source records.
#
# Two properties of the output shape drive the design here. First, spell fields
# are repeated on every episode in the FCE file, so anything spell-level must come
# from the spell file or be filtered to the dominant episode. Second, unbundled
# HRGs and error messages arrive as a variable number of trailing columns in the
# main files but as tidy rows in the relational (_rel) files - so the relational
# files are what an R pipeline should read.
#
# Requires: readr (>= 2.0), dplyr

library(dplyr)
library(readr)


# Reading -----------------------------------------------------------------------

read_if_present <- function(path) {
  if (!file.exists(path)) return(NULL)
  # Everything as character: HRGs, codes and identifiers all suffer from type
  # guessing, and leading zeros in critical care and renal fields disappear.
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()))
}

#' Read a grouper output set
#'
#' @param stem The output name given at run time, with path but without suffix -
#'   e.g. "C:/data/output_apc" for output_apc_FCE.csv and its siblings.
#' @param dataset One of APC, NAC, EM, NRD, ACC, PCC, NCC.
#' @return Named list of tibbles. Absent files are NULL.
read_grouper_output <- function(stem,
                                dataset = c("APC", "NAC", "EM", "NRD", "ACC", "PCC", "NCC")) {

  dataset <- match.arg(dataset)

  main_suffix <- switch(dataset,
    APC = "_FCE", NAC = "_attend", EM = "_attend",
    NRD = "_renal", ACC = "_acc", PCC = "_pcc", NCC = "_ncc"
  )

  out <- list(
    records    = read_if_present(paste0(stem, main_suffix, ".csv")),
    spells     = if (dataset == "APC") read_if_present(paste0(stem, "_spell.csv")),
    unbundled  = read_if_present(paste0(stem, "_ub_rel.csv")),
    errors     = read_if_present(paste0(stem, "_quality_rel.csv")),
    sorted     = read_if_present(paste0(stem, "_sort.csv")),
    summary    = read_if_present(paste0(stem, "_summary.csv"))
  )

  Filter(Negate(is.null), out)
}


# Run verification --------------------------------------------------------------

#' Summarise a run: provenance, counts, and error rates
#'
#' A zero exit code only means the executable finished. This is the check that
#' tells you whether the data grouped. Record the version strings alongside any
#' analysis - they are what makes the grouping step reproducible.
grouper_run_report <- function(out) {

  stopifnot(!is.null(out$records))

  hrg_col <- intersect(
    c("FCE_HRG", "NAC_HRG", "EM_HRG", "NRD_HRG", "ACC_HRG", "PCC_HRG", "NCC_HRG"),
    names(out$records)
  )[1]

  report <- list(
    provenance = if (!is.null(out$summary)) {
      out$summary |>
        dplyr::select(dplyr::any_of(c("Grouper Version", "Database Version",
                                      "RDF path and name", "Input Filename",
                                      "Run Start Date/Time")))
    },
    n_records   = nrow(out$records),
    n_spells    = if (!is.null(out$spells)) nrow(out$spells),
    record_uz01z = mean(out$records[[hrg_col]] == "UZ01Z", na.rm = TRUE),
    spell_uz01z  = if (!is.null(out$spells)) {
      mean(out$spells[["SpellHRG"]] == "UZ01Z", na.rm = TRUE)
    },
    n_error_rows = if (!is.null(out$errors)) nrow(out$errors) else 0L
  )

  # Spell-level failure rates are always at least record-level rates, because a
  # single invalid episode invalidates its whole spell. Report both.
  report
}

#' Tabulate errors by class, most frequent first
#'
#' Fix classes, not rows: a uniform block of failures on one field is a pipeline
#' defect, whereas scattered failures across many fields are usually genuine
#' coding issues. See references/errors.md for the pattern-to-cause table.
grouper_error_summary <- function(out, top_n = 20) {
  if (is.null(out$errors)) return(dplyr::tibble())

  out$errors |>
    dplyr::count(`Code Type`, `Error Message`, sort = TRUE) |>
    dplyr::mutate(pct_of_errors = round(100 * n / sum(n), 1)) |>
    head(top_n)
}


# Working with the output -------------------------------------------------------

#' Episode-level table with no repeated spell fields
#'
#' Drops the Spell* columns from the FCE file so that accidental aggregation of
#' spell values across episodes becomes impossible.
apc_episodes <- function(out) {
  spell_cols <- grep("^Spell", names(out$records), value = TRUE)
  # SpellReportFlag is episode-level despite the prefix - it marks which episode
  # drove the spell HRG - so it stays.
  drop_cols <- setdiff(spell_cols, "SpellReportFlag")

  dplyr::select(out$records, -dplyr::all_of(drop_cols))
}

#' Spell-level table, one row per spell
#'
#' Prefers the dedicated spell file. Falls back to filtering the FCE file to the
#' dominant episode, which is the row carrying the grouping variable used to
#' derive the spell HRG.
apc_spells <- function(out) {
  if (!is.null(out$spells)) return(out$spells)

  out$records |>
    dplyr::filter(SpellReportFlag == "1") |>
    dplyr::select(dplyr::any_of(c("RowNo", "PROCODET", "PROVSPNO")),
                  dplyr::starts_with("Spell"))
}

#' Unbundled HRGs in long form, one row per HRG
#'
#' Where rehabilitation or specialist palliative care days are reported, eligible
#' HRGs carry an asterisk and a day count. That count is repeated against every
#' instance of the code generated within the episode, so it must not be summed -
#' it records the days used for the length of stay adjustment, nothing more.
unbundled_long <- function(out) {
  if (is.null(out$unbundled)) return(dplyr::tibble())

  # Confirmed columns in _ub_rel.csv: RowNo, Iteration, UnbundledHRGs.
  hrg_col <- "UnbundledHRGs"
  if (!hrg_col %in% names(out$unbundled)) {
    stop("Expected column 'UnbundledHRGs' in the _ub_rel file; found: ",
         paste(names(out$unbundled), collapse = ", "), call. = FALSE)
  }

  out$unbundled |>
    dplyr::rename(unbundled_hrg = dplyr::all_of(hrg_col)) |>
    dplyr::mutate(
      hrg  = sub("\\*.*$", "", unbundled_hrg),
      days = suppressWarnings(as.integer(sub("^.*\\*", "", unbundled_hrg))),
      days = ifelse(grepl("\\*", unbundled_hrg), days, NA_integer_),
      critical_care = grepl("^X[ABC]", hrg)
    )
}

#' Join grouped output back to source records
#'
#' Join on a key carried through the grouper as an extra column, not on row order:
#' RowNo is assigned after the grouper sorts the input, so it will not match the
#' order of the file that went in.
join_hrgs <- function(source_data, out, key) {
  hrg_cols <- intersect(
    c("RowNo", "FCE_HRG", "NAC_HRG", "EM_HRG", "NRD_HRG", "ACC_HRG", "PCC_HRG",
      "NCC_HRG", "GroupingMethodFlag", "DominantProcedure", "CalcEpidur",
      "SpellHRG", "SpellReportFlag", "CC_Warning_Flag", "Calc_CC_Days"),
    names(out$records)
  )

  if (!key %in% names(out$records)) {
    stop("Key '", key, "' is not in the grouper output. Carry it through the run ",
         "as an extra input column - the grouper reproduces columns it does not ",
         "recognise.", call. = FALSE)
  }

  dplyr::left_join(
    source_data,
    dplyr::select(out$records, dplyr::all_of(c(key, hrg_cols))),
    by = key
  )
}
