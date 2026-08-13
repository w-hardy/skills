#' Pre-fit structural checks for an NMA network, to run BEFORE set_agd_arm()
#' (multinma) or pairwise()/netmeta(). Catches the setup problems that
#' otherwise fail deep inside a fit with an opaque error:
#'   - incoherent arm data (events > patients, negatives, non-integers)
#'   - a DISCONNECTED network (a treatment with no direct-or-indirect path to
#'     the reference cannot be estimated by standard NMA)
#'   - a reference treatment that doesn't appear in the data
#'   - multi-arm trials carrying duplicate arms on the same treatment (netmeta
#'     rejects these; they must be merged)
#'
#' Expects LONG arm-level data: one row per (study, arm), with columns naming
#' the study, treatment, events, and sample size.
#'
#' Usage:
#'   source("check_nma_network.R")
#'   check_nma_network(dat, study = "study", trt = "trt",
#'                     r = "r", n = "n", reference = "nonantibacterial")

check_nma_network <- function(dat, study = "study", trt = "trt",
                              r = NULL, n = NULL, reference = NULL) {
  problems <- character(0); notes <- character(0)

  for (col in c(study, trt)) if (!col %in% names(dat))
    stop(sprintf("Column '%s' not found in data.", col))
  S <- as.character(dat[[study]]); T <- as.character(dat[[trt]])

  # --- Arm-data coherence (only if r and n supplied) --------------------
  if (!is.null(r) && !is.null(n)) {
    if (!r %in% names(dat) || !n %in% names(dat))
      stop("r/n columns named but not found in data.")
    rv <- dat[[r]]; nv <- dat[[n]]
    if (any(rv < 0, na.rm = TRUE) || any(nv < 0, na.rm = TRUE))
      problems <- c(problems, "Negative event or sample-size counts present.")
    if (any(rv > nv, na.rm = TRUE)) {
      bad <- which(rv > nv)
      problems <- c(problems, sprintf("Events exceed patients in %d arm(s) (e.g. study '%s').",
                                      length(bad), S[bad[1]]))
    }
    if (any(rv != round(rv), na.rm = TRUE) || any(nv != round(nv), na.rm = TRUE))
      notes <- c(notes, "Non-integer counts present -- check these are really event/patient counts.")
    if (any(nv == 0, na.rm = TRUE))
      problems <- c(problems, "Arm(s) with zero patients (n = 0) present.")
    z <- sum(rv == 0, na.rm = TRUE)
    if (z > 0)
      notes <- c(notes, sprintf("%d zero-event arm(s): netmeta will add a 0.5 continuity correction; check their fit.", z))
  }

  # --- Reference treatment exists ---------------------------------------
  trts <- sort(unique(T))
  if (!is.null(reference) && !reference %in% trts) {
    problems <- c(problems, sprintf("Reference treatment '%s' not found among treatments: %s",
                                    reference, paste(trts, collapse = ", ")))
  }

  # --- Duplicate same-treatment arms within a study (netmeta rejects) ---
  dup_studies <- character(0)
  for (st in unique(S)) {
    tt <- T[S == st]
    if (any(duplicated(tt))) dup_studies <- c(dup_studies, st)
  }
  if (length(dup_studies) > 0) {
    problems <- c(problems, sprintf(
      "%d study(ies) have >1 arm on the same treatment (netmeta needs these merged): %s",
      length(dup_studies), paste(head(dup_studies, 5), collapse = ", ")))
  }

  # --- Connectivity: is every treatment reachable from the reference? ---
  # Build an undirected graph: treatments are nodes; an edge exists between
  # two treatments if some study contains both. Then BFS from the reference.
  edges <- list()
  for (st in unique(S)) {
    arms <- unique(T[S == st])
    if (length(arms) >= 2) {
      cb <- combn(arms, 2)
      for (j in seq_len(ncol(cb))) edges[[length(edges) + 1]] <- cb[, j]
    }
  }
  adj <- setNames(vector("list", length(trts)), trts)
  for (e in edges) {
    adj[[e[1]]] <- union(adj[[e[1]]], e[2])
    adj[[e[2]]] <- union(adj[[e[2]]], e[1])
  }
  root <- if (!is.null(reference) && reference %in% trts) reference else trts[1]
  seen <- character(0); queue <- root
  while (length(queue) > 0) {
    cur <- queue[1]; queue <- queue[-1]
    if (cur %in% seen) next
    seen <- c(seen, cur)
    queue <- c(queue, setdiff(adj[[cur]], seen))
  }
  unreached <- setdiff(trts, seen)
  if (length(unreached) > 0) {
    problems <- c(problems, sprintf(
      "Network is DISCONNECTED: treatment(s) with no path to '%s': %s. Standard NMA cannot estimate these.",
      root, paste(unreached, collapse = ", ")))
  } else {
    notes <- c(notes, sprintf("Network is connected (%d treatments, all reachable from '%s').",
                              length(trts), root))
  }

  notes <- c(notes, sprintf("%d studies, %d treatments.", length(unique(S)), length(trts)))

  # --- Report ------------------------------------------------------------
  for (nt in notes) message("  - ", nt)
  if (length(problems) == 0) {
    message("OK: network setup looks sound. (Still test the consistency assumption after fitting.)")
    return(invisible(TRUE))
  }
  message(sprintf("%d issue(s) to resolve before fitting:", length(problems)))
  for (p in problems) message("  ! ", p)
  invisible(FALSE)
}
