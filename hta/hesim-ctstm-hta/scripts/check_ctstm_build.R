#!/usr/bin/env Rscript
# check_ctstm_build.R  (hesim 0.5.8)
# -----------------------------------------------------------------------------
# Structural PRE-FLIGHT for an EXPO IndivCtstm build. Catches the "runs but is
# silently wrong" class BEFORE the expensive simulation: bad clock string, a
# pwexp age axis that under-runs the horizon, misaligned coefficient names, an
# out-of-order params_surv_list, an unresolved mortality_key, or a max_age that
# disagrees with the mortality axis.
#
# This COMPLEMENTS the multistate-models-hta skill's check_multistate_setup.R
# (transition-matrix / Q consistency). Run that first; run this second.
#
# All checks are cheap and require no simulation. Use as a hard gate: any FAIL
# should stop the build (fail-closed), consistent with EXPO governance.
# -----------------------------------------------------------------------------

check_ctstm_build <- function(tmat,
                              params_list,          # the assembled params_surv_list (or fits list)
                              clock,                # "reset" | "forward" | "mix" | "mixt"
                              max_age,              # value passed to $sim_disease(max_age=)
                              start_ages,           # numeric vector of patient start ages
                              age_axis_end = NULL,  # top breakpoint of any attained-age pwexp edge
                              top_band_rate = NULL, # rate of the LAST pwexp band (carried forward);
                                                    #   supply it to downgrade the short-axis FAIL to a
                                                    #   note when the band is deliberately terminal-lethal
                              mortality_keys = NULL,# character vector of keys used by living states
                              smr_tbl = NULL,       # named list/data.table with smr_<key> columns
                              coef_name_sets = NULL # optional list of character vectors: coef names
                                                    #   per transition, to check cross-consistency
                              ) {
  fails <- character(0); warns <- character(0)
  fail <- function(...) fails[[length(fails) + 1L]] <<- paste0(...)
  warn <- function(...) warns[[length(warns) + 1L]] <<- paste0(...)

  ## 1. Clock string ----------------------------------------------------------
  valid_clocks <- c("reset", "forward", "mix", "mixt")
  if (!is.character(clock) || length(clock) != 1L || !clock %in% valid_clocks) {
    fail(sprintf("clock must be one of {%s}; got '%s'.",
                 paste(valid_clocks, collapse = ", "), paste(clock, collapse = ",")))
  }
  if (identical(clock, "mix")) {
    warn("clock = 'mix' mixes PER ORIGIN STATE. If any origin has both a reset ",
         "and a forward transition (e.g. reset-retention + age-mortality), you ",
         "need 'mixt' (per transition). Confirm this is intended.")
  }

  ## 2. Transition matrix vs params count -------------------------------------
  n_trans <- suppressWarnings(max(tmat, na.rm = TRUE))
  if (!is.finite(n_trans)) {
    fail("tmat has no non-NA transition IDs.")
  } else {
    ids <- sort(unique(as.vector(tmat[!is.na(tmat)])))
    if (!identical(ids, seq_len(n_trans))) {
      fail(sprintf("transition IDs in tmat are not consecutive 1..%d: {%s}.",
                   n_trans, paste(ids, collapse = ", ")))
    }
    if (!is.null(params_list) && length(params_list) != n_trans) {
      fail(sprintf("params_surv_list length (%d) != number of permitted transitions (%d). ",
                   length(params_list), n_trans))
    }
    # absorbing states (all-NA rows) must have no outgoing transitions -- structural echo
    absorbing <- which(apply(tmat, 1, function(r) all(is.na(r))))
    for (a in absorbing) if (any(!is.na(tmat[a, ])))
      fail(sprintf("row %d looks absorbing but has outgoing transitions.", a))
  }

  ## 3. pwexp attained-age axis vs horizon ------------------------------------
  if (!is.null(age_axis_end)) {
    # An attained-age pwexp death edge carries its LAST rate forward to infinity, so
    # the axis (in attained age) must reach the oldest age any patient can attain --
    # UNLESS the last band is deliberately terminal-lethal (e.g. a qx capped at 0.999
    # gives h ~ 6.9/yr), in which case carrying it forward IS the intended "everyone
    # dies at the table top" behaviour. Supply `top_band_rate` to declare that;
    # the FAIL downgrades to a note when survival through the uncovered gap is
    # negligible (< 0.1%).
    if (age_axis_end < max_age) {
      gap <- max_age - age_axis_end
      lethal <- !is.null(top_band_rate) && is.finite(top_band_rate) &&
        exp(-top_band_rate * gap) < 1e-3
      if (lethal) {
        warn(sprintf("pwexp age axis ends at %.0f < max_age %.0f, but the last band's ",
                     age_axis_end, max_age),
             sprintf("rate (%.2f/yr) is terminal-lethal (P(survive the %.0fy gap) = %.1e) -- ",
                     top_band_rate, gap, exp(-top_band_rate * gap)),
             "the carried-forward band is the intended behaviour. Confirm it is.")
      } else {
        fail(sprintf("pwexp age axis ends at %.0f but max_age = %.0f: the top-of-horizon ",
                     age_axis_end, max_age),
             "band is wrong and life-years may return NA. Extend aux$time to >= max_age, ",
             "or pass top_band_rate if the last band is deliberately terminal-lethal.")
      }
    }
    if (age_axis_end < 110) {
      warn(sprintf("pwexp age axis ends at %.0f; ONS-style lifetables run to ~110. ",
                   age_axis_end),
           "Confirm the top band is intended rather than a truncated axis.")
    }
    if (max_age <= 100) {
      warn(sprintf("max_age = %.0f (hesim default is 100). If mortality runs to ~110, ",
                   max_age), "raise max_age so truncation and the mortality axis agree.")
    }
    if (length(start_ages) && max(start_ages) + (max_age - min(start_ages)) > age_axis_end) {
      warn("with heterogeneous start_age, confirm the attained-age axis is built ",
           "per-patient (or covers the oldest attainable age) rather than a single ",
           "shared model-time grid.")
    }
  }

  ## 4. mortality_key resolution (fail-LOUD) ----------------------------------
  if (!is.null(mortality_keys)) {
    if (is.null(smr_tbl)) {
      fail("mortality_keys supplied but smr_tbl is NULL: cannot verify resolution.")
    } else {
      cols <- names(smr_tbl)
      for (k in unique(mortality_keys)) {
        col <- paste0("smr_", k)
        if (!col %in% cols) {
          fail(sprintf("mortality_key '%s' does not resolve (no column '%s'). ", k, col),
               "A quiet fallback to SMR=1 would apply BACKGROUND mortality -- fail closed.")
        } else {
          v <- smr_tbl[[col]]
          if (!all(is.finite(v)) || any(v <= 0))
            fail(sprintf("SMR column '%s' has non-finite or non-positive values.", col))
        }
      }
    }
  }

  ## 5. Coefficient-name cross-consistency ------------------------------------
  if (!is.null(coef_name_sets) && length(coef_name_sets) > 1L) {
    shared <- Reduce(intersect, coef_name_sets)
    all_names <- unique(unlist(coef_name_sets))
    # crude smell test: a lone 'cons' living beside '(Intercept)' usually means a
    # hand-built table didn't adopt the fit's naming.
    if ("cons" %in% all_names && "(Intercept)" %in% all_names) {
      warn("both 'cons' and '(Intercept)' appear across coefficient tables -- in a MIXED ",
           "assembly hand-built intercepts should adopt the fit's names (e.g. '(Intercept)', ",
           "'armsoc'), not 'cons'. Confirm the intent.")
    }
  }

  ## Report -------------------------------------------------------------------
  cat("== check_ctstm_build (hesim 0.5.8) ==\n")
  if (length(warns)) { cat("\nWARNINGS:\n"); for (w in warns) cat("  ! ", w, "\n", sep = "") }
  if (length(fails)) {
    cat("\nFAILURES:\n"); for (f in fails) cat("  X ", f, "\n", sep = "")
    cat(sprintf("\nFAIL: %d structural problem(s) -- do NOT simulate.\n", length(fails)))
    return(invisible(FALSE))
  }
  cat("\nPASS: no structural problems detected. (Not a correctness proof -- ",
      "still run the validation ladder.)\n", sep = "")
  invisible(TRUE)
}

# Example (pseudo-inputs):
# check_ctstm_build(
#   tmat = tmat, params_list = all_params, clock = "mixt",
#   max_age = 110, start_ages = patients$age, age_axis_end = 110,
#   mortality_keys = c("ontx","offtx","recovered","offtx_exit4wk","prison","postrelease"),
#   smr_tbl = smr_tbl,
#   coef_name_sets = lapply(all_params, function(p) colnames(p$coefs[[1]]))
# )
