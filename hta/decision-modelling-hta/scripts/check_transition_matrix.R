#' Check a transition matrix (or a heemod transition object) for the
#' mistakes that most commonly produce silently-wrong decision models:
#' non-square matrices, rows that don't sum to 1, negative probabilities,
#' and absorbing states that aren't really absorbing.
#'
#' Works on:
#'   - a plain square numeric matrix
#'   - a heemod `part_surv`/transition object evaluated at one or more
#'     cycles (pass a list of matrices, one per cycle, for a
#'     time-inhomogeneous model)
#'
#' Usage:
#'   source("check_transition_matrix.R")
#'   check_transition_matrix(my_matrix, absorbing_states = "Dead")
#'   check_transition_matrix(list(mat_cycle1, mat_cycle2, ...), tol = 1e-8,
#'                            absorbing_states = c("Dead_disease", "Dead_other"))
#'
#' `absorbing_states` is optional but recommended: name the states that
#' should never be left once entered (typically death states). Without it,
#' the function can only check that rows sum to 1 -- it can't tell a
#' correctly-specified absorbing state from a state that just happens to
#' have a high self-transition probability, since both look the same from
#' the matrix alone.

check_transition_matrix <- function(mat_or_list, tol = 1e-6, state_names = NULL,
                                     absorbing_states = NULL) {

  mats <- if (is.list(mat_or_list) && !is.matrix(mat_or_list)) mat_or_list else list(mat_or_list)

  problems <- character(0)

  for (i in seq_along(mats)) {
    m <- as.matrix(mats[[i]])
    label <- if (length(mats) > 1) sprintf("cycle %d", i) else "matrix"

    if (nrow(m) != ncol(m)) {
      problems <- c(problems, sprintf("[%s] not square: %d rows, %d cols", label, nrow(m), ncol(m)))
      next
    }

    nm <- if (!is.null(state_names)) state_names else rownames(m)
    if (is.null(nm)) nm <- paste0("state_", seq_len(nrow(m)))

    row_sums <- rowSums(m)
    bad_rows <- abs(row_sums - 1) > tol
    if (any(bad_rows)) {
      for (r in which(bad_rows)) {
        problems <- c(problems, sprintf(
          "[%s] row '%s' sums to %.8f, not 1 (off by %.2e)",
          label, nm[r], row_sums[r], row_sums[r] - 1
        ))
      }
    }

    if (any(m < -tol)) {
      neg <- which(m < -tol, arr.ind = TRUE)
      for (k in seq_len(nrow(neg))) {
        problems <- c(problems, sprintf(
          "[%s] negative entry at row '%s', col '%s': %.6f",
          label, nm[neg[k, 1]], nm[neg[k, 2]], m[neg[k, 1], neg[k, 2]]
        ))
      }
    }

    # Check named absorbing states explicitly: self-transition must be 1
    # (within tolerance) and every other entry in that row must be 0.
    if (!is.null(absorbing_states)) {
      for (st in absorbing_states) {
        r <- match(st, nm)
        if (is.na(r)) {
          problems <- c(problems, sprintf(
            "[%s] absorbing state '%s' not found among state names %s",
            label, st, paste(nm, collapse = ", ")
          ))
          next
        }
        if (abs(m[r, r] - 1) > tol) {
          problems <- c(problems, sprintf(
            "[%s] '%s' should be absorbing but self-transition is %.6f, not 1",
            label, st, m[r, r]
          ))
        }
        off_diag <- m[r, -r]
        if (any(abs(off_diag) > tol)) {
          leaking <- nm[-r][abs(off_diag) > tol]
          problems <- c(problems, sprintf(
            "[%s] '%s' is meant to be absorbing but leaks probability to: %s",
            label, st, paste(leaking, collapse = ", ")
          ))
        }
      }
    }
  }

  if (length(problems) == 0) {
    message("OK: all matrices square, rows sum to 1 (tol = ", tol, "), no negative entries, no leaky absorbing states.")
    return(invisible(TRUE))
  } else {
    message(sprintf("Found %d issue(s):", length(problems)))
    for (p in problems) message("  - ", p)
    return(invisible(FALSE))
  }
}
