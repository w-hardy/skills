# write_grouper_input.R ---------------------------------------------------------
# Build an input CSV that the HRG4+ National Costs Grouper will read correctly.
#
# The grouper is unforgiving in specific, silent ways: it wants plain ASCII, no
# text qualifiers, exact column positions matching the RDF, and character values
# whose leading zeros survive. This script enforces those properties and fails
# loudly where it cannot, so that problems surface here rather than as thousands
# of UZ01Z rows later.
#
# Requires: readr (>= 2.0), dplyr

library(dplyr)
library(readr)


# `%||%` is base R only from 4.4.0; define it so this runs on older installations.
`%||%` <- function(x, y) if (is.null(x)) y else x


# Zero padding ------------------------------------------------------------------

# formatC() looks like the obvious tool here but silently ignores flag = "0" for
# character input and pads with spaces instead, which would defeat the entire
# purpose of this script. Pad explicitly.
pad_left_zero <- function(x, width) {
  x <- as.character(x)
  ifelse(is.na(x) | x == "",
         "",
         paste0(strrep("0", pmax(0L, width - nchar(x))), x))
}


# Field order -------------------------------------------------------------------

# The RDF defines which column each field occupies, so the input file must be
# written in the order that the RDF expects. Derive that order from the RDF you
# will actually use rather than assuming it - the safest source is the header row
# of the matching file in the grouper's Sample Data folder, or the Position
# column shown when the default RDF is opened in the RDF editor.

#' Read a field order from a sample or reference CSV header
#'
#' @param path Path to a CSV whose header row names the grouper fields.
#' @return Character vector of field names in column order.
grouper_field_order_from_file <- function(path) {
  names(readr::read_csv(path, n_max = 0, show_col_types = FALSE))
}

# Field order of the shipped default APC RDF, as documented in the user manual.
# Positions 1-14 are stable. The DIAG and OPER blocks default to 14 repeats each,
# but Field Customisation changes both the count and the position of every field
# after them - so verify this against your own installation before relying on it.
APC_DEFAULT_FIELD_ORDER <- c(
  "PROCODET", "PROVSPNO", "EPIORDER", "STARTAGE", "SEX", "CLASSPAT",
  "ADMISORC", "ADMIMETH", "DISDEST", "DISMETH", "EPIDUR", "MAINSPEF",
  "NEOCARE", "TRETSPEF",
  sprintf("DIAG_%02d", 1:14),
  sprintf("OPER_%02d", 1:14)
)

# Mandatory fields by dataset, used to catch omissions early. Optional fields may
# be absent entirely; mandatory ones must be present in both RDF and input file.
GROUPER_MANDATORY <- list(
  APC = c("PROCODET", "PROVSPNO", "EPIORDER", "STARTAGE", "SEX", "CLASSPAT",
          "ADMISORC", "ADMIMETH", "DISDEST", "DISMETH", "EPIDUR", "MAINSPEF",
          "TRETSPEF", "DIAG_01"),
  NAC = c("STARTAGE", "SEX", "MAINSPEF", "TRETSPEF", "FIRSTATT"),
  EM  = c("AGE"),
  NRD = c("RENALMOD", "RENALSITE", "AGE"),
  ACC = c("CCUF"),
  PCC = c("CCDate", "DISDATE", "DISMETH", "CCUF"),
  NCC = c("CCDate", "DISDATE", "CCUF", "DISMETH", "GestLen", "PERWT")
)

# Fields where a lost leading zero changes meaning or fails validation, and the
# fixed width to pad them to.
#
# Only genuinely fixed-width fields appear here. A&E investigation codes are always
# 2 characters, so padding is safe. Treatment codes are 2 *or* 3 characters, so
# padding every value to the widest one observed would corrupt the legitimate
# 2-character codes - those need widths supplied explicitly via `pad_widths`, taken
# from the source system or the valid code list. The critical care and weight fields
# are listed for visibility even though the grouper accepts them either way.
GROUPER_ZERO_PADDED <- list(
  APC = integer(),
  NAC = integer(),
  EM  = setNames(rep(2L, 99), sprintf("INV_%02d", 1:99)),
  NRD = c(RENALMOD = 2L, RENALSITE = 2L, RENALACCESS = 2L),
  ACC = c(CCUF = 2L),
  PCC = c(setNames(rep(2L, 20), sprintf("CCAC_%02d", 1:20)), CCUF = 2L),
  NCC = c(setNames(rep(2L, 20), sprintf("CCAC_%02d", 1:20)), CCUF = 2L)
)

# Variable-width code fields: never auto-pad, because the correct width differs by
# code. Warn if they are present without an explicit width.
GROUPER_VARIABLE_WIDTH <- list(
  EM = sprintf("TREAT_%02d", 1:99)
)


# Writer ------------------------------------------------------------------------

#' Write a grouper input file
#'
#' @param data A data frame of activity records, one row per unit of activity.
#' @param field_order Character vector naming the columns to write, in the order
#'   the RDF expects. Columns of `data` not named here are dropped unless listed
#'   in `carry_through`.
#' @param path Output CSV path.
#' @param dataset One of APC, NAC, EM, NRD, ACC, PCC, NCC. Used for mandatory
#'   field checks and default zero padding.
#' @param carry_through Extra columns appended after the grouper fields, e.g. a
#'   local record key. The grouper ignores unrecognised columns and reproduces
#'   them in the output, which is the cleanest way to rejoin results to source
#'   data without depending on row order.
#' @param pad_widths Named integer vector of field widths to zero-pad, e.g.
#'   c(TREAT_01 = 3). Defaults are applied for the dataset's zero-sensitive
#'   fields where a width can be inferred from the data.
#' @param dummy_column Append a constant rightmost column. Protects row structure
#'   against trailing empty fields being lost if the file is ever opened and
#'   resaved in Excel. Harmless otherwise.
#' @param eol Line ending. "\n" suits most setups; switch to "\r\n" if the
#'   grouper or a downstream Windows tool objects.
#' @return Invisibly, the path written.
write_grouper_input <- function(data,
                                field_order,
                                path,
                                dataset = c("APC", "NAC", "EM", "NRD", "ACC", "PCC", "NCC"),
                                carry_through = character(),
                                pad_widths = NULL,
                                dummy_column = TRUE,
                                eol = "\n") {

  dataset <- match.arg(dataset)

  # 1. Mandatory fields present?
  missing_mandatory <- setdiff(GROUPER_MANDATORY[[dataset]], field_order)
  if (length(missing_mandatory) > 0) {
    stop("Mandatory ", dataset, " fields missing from field_order: ",
         paste(missing_mandatory, collapse = ", "), call. = FALSE)
  }

  # 2. Every requested field present in the data?
  missing_cols <- setdiff(c(field_order, carry_through), names(data))
  if (length(missing_cols) > 0) {
    stop("Columns absent from data: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  out <- data |>
    dplyr::select(dplyr::all_of(c(field_order, carry_through))) |>
    # Everything becomes character: numeric coercion is how leading zeros and
    # date formats get destroyed.
    dplyr::mutate(dplyr::across(dplyr::everything(),
                                \(x) ifelse(is.na(x), "", as.character(x))))

  # 3. Zero padding to known fixed widths, overridden by anything the caller
  #    supplies. Widths are never inferred from the data: the widest observed
  #    value is not evidence of the correct width.
  widths <- GROUPER_ZERO_PADDED[[dataset]]
  widths <- widths[names(widths) %in% names(out)]
  if (!is.null(pad_widths)) widths[names(pad_widths)] <- as.integer(pad_widths)

  for (f in names(widths)) {
    out[[f]] <- pad_left_zero(out[[f]], widths[[f]])
  }

  # Variable-width code fields cannot be padded safely. Stripping a leading zero is
  # not a reversible map where the width varies: TREAT "011" and "11" both arrive as
  # "11", and "01" and "001" both arrive as "1". Padding guesses, and a wrong guess
  # produces a different *valid* code that groups without error.
  unpadded <- intersect(GROUPER_VARIABLE_WIDTH[[dataset]] %||% character(), names(out))
  unpadded <- setdiff(unpadded, names(pad_widths))
  if (length(unpadded) > 0) {
    warning("Variable-width code fields written without padding: ",
            paste(utils::head(unpadded, 5), collapse = ", "),
            if (length(unpadded) > 5) paste0(" (+", length(unpadded) - 5, " more)"),
            ". These are 2 or 3 characters depending on the code, so a lost leading ",
            "zero cannot be inferred from the value alone. Re-extract from source ",
            "with the column typed as text; supply pad_widths only where the correct ",
            "width is known from the source system or the valid code list.",
            call. = FALSE)
  }

  # 4. Characters the format cannot survive. Commas cannot be escaped because the
  #    file is comma-delimited, and quotes are read as data, not as qualifiers.
  offending <- vapply(out, \(x) any(grepl('[,"]', x)), logical(1))
  if (any(offending)) {
    stop("Commas or quotation marks found in: ",
         paste(names(offending)[offending], collapse = ", "),
         ". Strip them at source - the grouper cannot escape either.", call. = FALSE)
  }

  non_ascii <- vapply(out, \(x) any(grepl("[^\\x20-\\x7E]", x, perl = TRUE)), logical(1))
  if (any(non_ascii)) {
    stop("Non-printing or non-ASCII characters found in: ",
         paste(names(non_ascii)[non_ascii], collapse = ", "), call. = FALSE)
  }

  # 5. Trailing structural guard.
  if (dummy_column) out[["DUMMY"]] <- "x"

  readr::write_csv(out, path, na = "", quote = "none", escape = "none", eol = eol)

  message("Wrote ", nrow(out), " rows and ", ncol(out), " columns to ", path)
  invisible(path)
}


#' Detect stripped leading zeros before grouping
#'
#' Compares observed code widths against the widths the dataset expects, and
#' reports whether the damage is reversible.
#'
#' Two signals matter. Values narrower than the minimum valid width were coerced.
#' And if any value in a column still carries a leading zero, that column probably
#' was not coerced at all - Excel's numeric conversion is column-wide, so mixed
#' evidence points at a different cause.
#'
#' @param data Data frame of prepared records.
#' @param dataset One of APC, NAC, EM, NRD, ACC, PCC, NCC.
#' @return A tibble, one row per suspect field.
diagnose_stripped_zeros <- function(data,
                                    dataset = c("APC", "NAC", "EM", "NRD", "ACC",
                                                "PCC", "NCC")) {
  dataset <- match.arg(dataset)

  # Minimum valid width per field family, from the dataset specifications.
  min_widths <- c(GROUPER_ZERO_PADDED[[dataset]],
                  setNames(rep(2L, length(GROUPER_VARIABLE_WIDTH[[dataset]] %||% character())),
                           GROUPER_VARIABLE_WIDTH[[dataset]] %||% character()))
  min_widths <- min_widths[names(min_widths) %in% names(data)]
  if (length(min_widths) == 0) return(dplyr::tibble())

  variable_width <- GROUPER_VARIABLE_WIDTH[[dataset]] %||% character()

  dplyr::bind_rows(lapply(names(min_widths), function(f) {
    x <- as.character(data[[f]])
    x <- x[!is.na(x) & x != ""]
    if (length(x) == 0) return(NULL)

    dplyr::tibble(
      field           = f,
      n_values        = length(x),
      n_under_width   = sum(nchar(x) < min_widths[[f]]),
      any_leading_zero = any(startsWith(x, "0")),
      # Fixed-width fields can be repaired by padding; variable-width ones cannot,
      # because several originals collapse onto the same damaged value.
      repairable      = !f %in% variable_width
    )
  })) |>
    dplyr::filter(n_under_width > 0 | !any_leading_zero)
}


# EM national code validation ---------------------------------------------------

# Verified against the NHS Data Model and Dictionary, September 2020 release
# (accessed 12 August 2026): Accident and Emergency Investigation Table and
# Accident and Emergency Treatment Tables. See references/em_codes.md.

AE_INVESTIGATION_CODES <- c(sprintf("%02d", 1:24), "99")

AE_TREATMENT_CODES <- c(sprintf("%02d", 1:25), sprintf("%02d", 27:57), "99")

# Sub-analysed treatments and their valid third digit.
AE_TREATMENT_SUBANALYSIS <- list(
  "01" = 1:2, "03" = 1:3, "04" = 1:3, "05" = 1:2, "09" = 1:2, "10" = 1:3,
  "18" = 1:2, "22" = 1:2, "23" = 1:6, "24" = 1:6, "28" = 1:2, "29" = 1:2,
  "51" = 1:9, "52" = 1:2, "55" = 1:5
)

valid_treatment_values <- function() {
  with_sub <- unlist(lapply(names(AE_TREATMENT_SUBANALYSIS), function(code) {
    paste0(code, AE_TREATMENT_SUBANALYSIS[[code]])
  }))
  c(AE_TREATMENT_CODES, with_sub)
}

# Two-character treatment values that are simultaneously a valid code and a valid
# stripping of "0A" + sub-analysis digit. Neither reading can be ruled out, and
# both group without error - so these must never be repaired by inference.
AE_TREATMENT_AMBIGUOUS <- local({
  candidates <- unlist(lapply(names(AE_TREATMENT_SUBANALYSIS), function(code) {
    if (!startsWith(code, "0")) return(NULL)
    paste0(substr(code, 2, 2), AE_TREATMENT_SUBANALYSIS[[code]])
  }))
  sort(intersect(candidates, AE_TREATMENT_CODES))
})   # "11" "12" "31" "32" "33" "41" "42" "43" "51" "52"

#' Validate EM investigation and treatment values before grouping
#'
#' Returns one row per offending value with a verdict, so that genuine coding
#' errors are separated from repairable truncation and from the ambiguous cases
#' that no amount of code can resolve.
validate_em_codes <- function(data) {
  inv_cols   <- grep("^INV_",   names(data), value = TRUE)
  treat_cols <- grep("^TREAT_", names(data), value = TRUE)
  valid_treat <- valid_treatment_values()

  classify <- function(x, field) {
    x <- as.character(x)
    x <- x[!is.na(x) & x != ""]
    if (length(x) == 0) return(NULL)

    is_inv <- startsWith(field, "INV_")
    valid  <- if (is_inv) AE_INVESTIGATION_CODES else valid_treat

    verdict <- dplyr::case_when(
      x %in% valid & !is_inv & x %in% AE_TREATMENT_AMBIGUOUS ~ "valid but ambiguous if file was coerced",
      x %in% valid                                            ~ "valid",
      nchar(x) == 1 & paste0("0", x) %in% valid               ~ "truncated - repairable by padding",
      TRUE                                                    ~ "invalid - not a national code"
    )

    dplyr::tibble(field = field, value = x, verdict = verdict) |>
      dplyr::count(field, value, verdict, name = "n") |>
      dplyr::filter(verdict != "valid")
  }

  dplyr::bind_rows(lapply(c(inv_cols, treat_cols),
                          \(f) classify(data[[f]], f)))
}


# Spell-level consistency -------------------------------------------------------

#' Check APC spell-constant fields before grouping
#'
#' SEX, CLASSPAT, ADMISORC and ADMIMETH must be identical on every episode of a
#' spell, and the spell identifier must be unique within provider. Violations
#' surface as "Sex is inconsistent in spell" errors after a run; catching them
#' here is cheaper, and they usually point at the spell identifier rather than at
#' the clinical data.
#'
#' @return A tibble of offending spells; empty if all checks pass.
check_apc_spell_consistency <- function(data,
                                        provider = "PROCODET",
                                        spell = "PROVSPNO",
                                        episode = "EPIORDER",
                                        constant_fields = c("SEX", "CLASSPAT",
                                                            "ADMISORC", "ADMIMETH")) {
  constant_fields <- intersect(constant_fields, names(data))

  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(provider, spell)))) |>
    dplyr::summarise(
      n_episodes        = dplyr::n(),
      duplicate_episode = anyDuplicated(.data[[episode]]) > 0,
      invalid_episode   = any(.data[[episode]] %in% c("98", "99", 98, 99)),
      dplyr::across(dplyr::all_of(constant_fields),
                    \(x) dplyr::n_distinct(x) > 1,
                    .names = "inconsistent_{.col}"),
      .groups = "drop"
    ) |>
    dplyr::filter(dplyr::if_any(dplyr::starts_with("inconsistent_")) |
                    duplicate_episode | invalid_episode)
}
