#' Structural checks for a multistate model BEFORE the expensive hesim
#' simulation. Catches the setup errors that produce a simulation which runs
#' but is silently wrong: misnumbered transition matrices, absorbing states
#' with stray outgoing transitions, a mismatch between the number of fitted
#' transition models and the number of permitted transitions, and (for an
#' intensity matrix) rows that don't sum to zero.
#'
#' Two complementary objects can be checked:
#'   - a hesim-style transition matrix: permitted transitions hold consecutive
#'     IDs (1..K), disallowed cells and the diagonal are NA.
#'   - an msm-style intensity matrix Q: off-diagonal rates >= 0, rows sum to 0.
#'
#' Usage:
#'   source("check_multistate_setup.R")
#'   check_transition_id_matrix(tmat, n_fitted = 4,
#'                              absorbing_states = c("Dead (Cancer)","Dead (Other cause)"))
#'   check_intensity_matrix(Q)

check_transition_id_matrix <- function(tmat, n_fitted = NULL, absorbing_states = NULL) {
  problems <- character(0); notes <- character(0)

  if (nrow(tmat) != ncol(tmat)) {
    return(report(sprintf("Transition matrix is not square: %d x %d", nrow(tmat), ncol(tmat))))
  }
  nm <- rownames(tmat); if (is.null(nm)) nm <- paste0("state_", seq_len(nrow(tmat)))

  ids <- tmat[!is.na(tmat)]
  # Permitted-transition IDs must be the consecutive integers 1..K
  if (length(ids) == 0) {
    problems <- c(problems, "No permitted transitions (all NA).")
  } else {
    if (any(ids != as.integer(ids))) {
      problems <- c(problems, "Transition IDs include non-integers.")
    }
    expected <- seq_len(length(ids))
    if (!setequal(sort(ids), expected)) {
      problems <- c(problems, sprintf(
        "Transition IDs are not the consecutive integers 1..%d; got: %s",
        length(ids), paste(sort(ids), collapse = ", ")))
    }
    if (any(duplicated(ids))) {
      problems <- c(problems, sprintf("Duplicate transition IDs: %s",
                                      paste(ids[duplicated(ids)], collapse = ", ")))
    }
    notes <- c(notes, sprintf("%d permitted transitions, IDs %s.",
                              length(ids), paste(sort(ids), collapse = ", ")))
  }

  # Diagonal must be NA (no self-transition IDs in a hesim transition matrix)
  if (any(!is.na(diag(tmat)))) {
    bad <- nm[!is.na(diag(tmat))]
    problems <- c(problems, sprintf("Diagonal should be NA but isn't for: %s",
                                    paste(bad, collapse = ", ")))
  }

  # Absorbing states must have no outgoing (non-NA) transitions
  if (!is.null(absorbing_states)) {
    for (st in absorbing_states) {
      r <- match(st, nm)
      if (is.na(r)) {
        problems <- c(problems, sprintf("Absorbing state '%s' not found in row names.", st))
        next
      }
      out <- tmat[r, ]; out_ids <- out[!is.na(out)]
      if (length(out_ids) > 0) {
        problems <- c(problems, sprintf(
          "Absorbing state '%s' has outgoing transition(s) (IDs %s) -- should have none.",
          st, paste(out_ids, collapse = ", ")))
      }
    }
  }

  # Number of fitted transition models must match number of permitted transitions
  if (!is.null(n_fitted) && length(ids) > 0 && n_fitted != length(ids)) {
    problems <- c(problems, sprintf(
      "You supplied %d fitted transition models but the matrix has %d permitted transitions.",
      n_fitted, length(ids)))
  }

  report(problems, notes)
}

check_intensity_matrix <- function(Q, tol = 1e-6) {
  problems <- character(0); notes <- character(0)

  if (nrow(Q) != ncol(Q)) {
    return(report(sprintf("Intensity matrix not square: %d x %d", nrow(Q), ncol(Q))))
  }
  nm <- rownames(Q); if (is.null(nm)) nm <- paste0("state_", seq_len(nrow(Q)))

  # Off-diagonal intensities must be >= 0
  offdiag <- Q; diag(offdiag) <- 0
  if (any(offdiag < -tol)) {
    neg <- which(offdiag < -tol, arr.ind = TRUE)
    for (k in seq_len(nrow(neg))) {
      problems <- c(problems, sprintf("Negative off-diagonal intensity at '%s' -> '%s': %.4g",
                                      nm[neg[k,1]], nm[neg[k,2]], Q[neg[k,1], neg[k,2]]))
    }
  }
  # Each row of an intensity matrix must sum to zero (diagonal = -sum of off-diagonals)
  rs <- rowSums(Q)
  bad <- which(abs(rs) > tol)
  for (r in bad) {
    problems <- c(problems, sprintf("Row '%s' of Q sums to %.6g, not 0 (diagonal mis-set?).",
                                    nm[r], rs[r]))
  }
  if (length(problems) == 0) {
    notes <- c(notes, "Intensity matrix OK: square, non-negative off-diagonals, rows sum to 0.")
  }
  report(problems, notes)
}

report <- function(problems, notes = character(0)) {
  # Allow callers to pass a single problem string for early returns
  if (is.character(problems) && length(problems) == 1 && length(notes) == 0 &&
      grepl("not square", problems)) {
    message(sprintf("1 issue(s):"))
    message("  ! ", problems)
    return(invisible(FALSE))
  }
  for (n in notes) message("  - ", n)
  if (length(problems) == 0) {
    message("OK: no structural problems found.")
    return(invisible(TRUE))
  }
  message(sprintf("%d issue(s):", length(problems)))
  for (p in problems) message("  ! ", p)
  invisible(FALSE)
}
