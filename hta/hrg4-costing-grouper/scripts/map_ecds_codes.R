# map_ecds_codes.R --------------------------------------------------------------
# Map ECDS SNOMED CT investigation and treatment codes back to A&E CDS national
# codes, so that emergency care activity can be grouped.
#
# The mapping table is NOT bundled here. It is supplied externally through the
# Secondary Uses Service, derived from Royal College of Emergency Medicine
# mappings, and it is versioned - so it must be loaded from a file you control and
# recorded as a provenance item. Never reconstruct it from code descriptions.
#
# See references/ecds_mapping.md for the policy position and the lossy cases.
#
# Requires: readr (>= 2.0), dplyr

library(dplyr)
library(readr)


#' Load a SUS mapping table
#'
#' Reads every column as character. Mapping tables are distributed as
#' spreadsheets, and a numeric read strips the leading zeros off the A&E codes -
#' which reintroduces the exact corruption the grouper cannot detect, at the one
#' point in the pipeline where the data was previously clean.
#'
#' @param path CSV export of the SUS mapping tool.
#' @param snomed_col,ae_col Column names holding the SNOMED CT concept id and the
#'   A&E national code.
#' @param version A label recorded with the result, e.g. the tool version and
#'   retrieval date. Required, because the mapping changes between releases.
read_ecds_mapping <- function(path, snomed_col, ae_col, version) {

  if (missing(version) || is.na(version) || version == "") {
    stop("Supply a `version` label - the mapping is versioned and the label is ",
         "part of the provenance record for the costed output.", call. = FALSE)
  }

  map <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character())) |>
    dplyr::select(snomed = dplyr::all_of(snomed_col), ae_code = dplyr::all_of(ae_col)) |>
    dplyr::filter(!is.na(snomed), !is.na(ae_code)) |>
    dplyr::distinct()

  # Many SNOMED codes to one A&E code is expected and fine. One SNOMED code to
  # several A&E codes would silently multiply rows on the join.
  fan_out <- map |>
    dplyr::count(snomed) |>
    dplyr::filter(n > 1)

  if (nrow(fan_out) > 0) {
    warning(nrow(fan_out), " SNOMED codes map to more than one A&E code. Joining ",
            "would duplicate attendance rows - resolve before mapping.", call. = FALSE)
  }

  attr(map, "mapping_version") <- version
  map
}


#' Map one or more SNOMED code columns to A&E national codes
#'
#' @param data ECDS extract, long or wide.
#' @param mapping Table from `read_ecds_mapping()`.
#' @param snomed_cols Columns holding SNOMED CT codes to translate.
#' @param prefix Output column prefix, "INV" or "TREAT".
#' @return `data` with mapped columns added, carrying an "unmapped" attribute.
map_ecds_codes <- function(data, mapping, snomed_cols, prefix = c("INV", "TREAT")) {

  prefix <- match.arg(prefix)
  n_before <- nrow(data)

  lookup <- stats::setNames(mapping$ae_code, mapping$snomed)

  for (i in seq_along(snomed_cols)) {
    src <- snomed_cols[[i]]
    out_col <- sprintf("%s_%02d", prefix, i)
    x <- as.character(data[[src]])
    data[[out_col]] <- unname(lookup[x])
    data[[out_col]][is.na(data[[out_col]])] <- ""
  }

  if (nrow(data) != n_before) {
    stop("Row count changed during mapping (", n_before, " -> ", nrow(data),
         "). The mapping is not one-to-one.", call. = FALSE)
  }

  attr(data, "mapping_version") <- attr(mapping, "mapping_version")
  data
}


#' Audit what failed to map, and why
#'
#' Separates the three causes, because only one of them is fixable. Codes with no
#' A&E equivalent - the retired codes, and anything that used to be recorded as
#' "other", which SNOMED cannot express - are a permanent residual. Unapproved
#' codes arrive blank from SUS+ with IsItemCodeApproved set to FALSE. Anything
#' left is a genuine gap in the mapping table or the extract.
#'
#' @param data ECDS extract after mapping.
#' @param snomed_cols The SNOMED source columns.
#' @param mapped_cols The mapped A&E columns.
#' @param approved_flag Optional column carrying IsItemCodeApproved.
ecds_mapping_audit <- function(data, snomed_cols, mapped_cols, approved_flag = NULL) {

  unmapped <- dplyr::bind_rows(lapply(seq_along(snomed_cols), function(i) {
    src    <- as.character(data[[snomed_cols[[i]]]])
    mapped <- as.character(data[[mapped_cols[[i]]]])
    approved <- if (!is.null(approved_flag) && approved_flag %in% names(data)) {
      as.character(data[[approved_flag]])
    } else {
      rep(NA_character_, length(src))
    }

    is_unmapped <- (is.na(mapped) | mapped == "") & !(is.na(src) | src == "")
    blank_src   <- is.na(src) | src == ""

    dplyr::tibble(
      column   = snomed_cols[[i]],
      category = dplyr::case_when(
        blank_src & !is.na(approved) & toupper(approved) == "FALSE" ~
          "code submitted outside the approved list - blanked by SUS+",
        blank_src                                                    ~ "no code recorded",
        is_unmapped                                                  ~ "no A&E equivalent in the mapping table",
        TRUE                                                         ~ "mapped"
      ),
      snomed = src
    )
  }))

  summary <- unmapped |>
    dplyr::count(column, category, name = "n") |>
    dplyr::group_by(column) |>
    dplyr::mutate(pct = round(100 * n / sum(n), 1)) |>
    dplyr::ungroup()

  # The distinct unmapped concepts are what to take back to the mapping table -
  # a short list usually means a version lag, a long tail usually means the
  # structural loss described in references/ecds_mapping.md.
  list(
    summary = summary,
    unmapped_concepts = unmapped |>
      dplyr::filter(category == "no A&E equivalent in the mapping table") |>
      dplyr::count(snomed, sort = TRUE, name = "n_attendances")
  )
}
