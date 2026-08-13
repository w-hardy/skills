#' Design-stage checker for a DES model. A DES is hand-built code, not a single
#' object, so this validates the *modelling decisions* before the trajectory is
#' written, flagging mismatches the literature warns about:
#'   - a competing-events strategy poorly matched to the censoring situation
#'   - strategy 3 (time-first) without a multimodality-capable combined distribution
#'   - parameter uncertainty declared handled but with no PSA loop
#'   - correlated distribution parameters resampled independently
#'   - too few simulated individuals for the stochastic mean to converge
#'   - DES chosen where the stated dynamics don't actually require it
#'
#' Usage:
#'   source("check_des_setup.R")
#'   check_des_setup(
#'     events = c("recurrence","cancer_death","other_death"),
#'     competing = TRUE,
#'     censored = TRUE,
#'     competing_strategy = 1,           # 1..4 (see SKILL.md / reference)
#'     combined_dist = NA,               # for strategy 3: "mixture"/"spline"/"single"
#'     n_individuals = 50000,
#'     parameter_uncertainty = "psa",    # "psa" / "none"
#'     correlated_params_sampled = "joint",  # "joint" / "independent" / NA
#'     needs_history = TRUE,             # do event rates depend on prior events?
#'     needs_resources = FALSE           # are capacity constraints / queues modelled?
#'   )

check_des_setup <- function(events,
                            competing = TRUE,
                            censored = NA,
                            competing_strategy = NA,
                            combined_dist = NA,
                            n_individuals = NA,
                            parameter_uncertainty = NA,
                            correlated_params_sampled = NA,
                            needs_history = NA,
                            needs_resources = NA,
                            min_individuals = 10000) {

  problems <- character(0); notes <- character(0)

  notes <- c(notes, sprintf("%d event(s): %s", length(events), paste(events, collapse = ", ")))

  # --- Is DES even the right tool? --------------------------------------
  if (isFALSE(needs_history) && isFALSE(needs_resources)) {
    problems <- c(problems, paste(
      "Neither history-dependence nor resources/queues are needed -- a state-transition or",
      "hesim multistate model is likely simpler and more transparent than DES here.",
      "Justify DES by a concrete need or use multistate-models-hta / decision-modelling-hta."))
  } else {
    reasons <- c(if (isTRUE(needs_history)) "history-dependent rates",
                 if (isTRUE(needs_resources)) "resources/queues")
    if (length(reasons) > 0)
      notes <- c(notes, sprintf("DES justified by: %s.", paste(reasons, collapse = " and ")))
  }

  # --- Competing-events strategy vs censoring ---------------------------
  if (isTRUE(competing) && !is.na(competing_strategy)) {
    if (!competing_strategy %in% 1:4) {
      problems <- c(problems, sprintf("competing_strategy must be 1-4; got %s.", competing_strategy))
    } else {
      if (isTRUE(censored) && competing_strategy == 2) {
        problems <- c(problems, paste(
          "Strategy 2 (event-first-then-time) is awkward under censoring -- recovering unbiased",
          "event probabilities/conditional times from censored data is not straightforward.",
          "With censoring, strategy 1 (earliest latent time) or 3 (time-first) is usually preferred."))
      }
      if (competing_strategy == 3) {
        if (is.na(combined_dist) || combined_dist == "single") {
          problems <- c(problems, paste(
            "Strategy 3 (time-first) uses a COMBINED time distribution; if event timings differ it",
            "is multimodal and a single parametric distribution will misfit it. Use a mixture",
            "distribution or survival spline for the combined time (set combined_dist)."))
        } else if (combined_dist %in% c("mixture","spline")) {
          notes <- c(notes, sprintf("Strategy 3 with a %s combined distribution -- handles multimodality.", combined_dist))
        }
      }
      if (competing_strategy == 4) {
        notes <- c(notes, paste(
          "Strategy 4 (discretised cyclic probabilities) forfeits DES's continuous-time advantage --",
          "only sensible to match an existing discrete-time model."))
      }
      if (competing_strategy %in% c(1,3) && isTRUE(censored))
        notes <- c(notes, sprintf("Strategy %d is a reasonable fit for censored data.", competing_strategy))
    }
  } else if (isTRUE(competing) && is.na(competing_strategy)) {
    notes <- c(notes, "Competing events present but no strategy chosen yet -- decide BEFORE fitting time-to-event models (it dictates how data are analysed).")
  }

  # --- Parameter uncertainty handling -----------------------------------
  if (!is.na(parameter_uncertainty)) {
    if (parameter_uncertainty == "none") {
      problems <- c(problems, paste(
        "parameter_uncertainty = 'none': running many individuals addresses STOCHASTIC noise only,",
        "not parameter (2nd-order) uncertainty. Add an outer PSA loop resampling parameters."))
    } else if (parameter_uncertainty == "psa") {
      notes <- c(notes, "Parameter uncertainty via PSA -- remember it nests an inner loop of enough individuals per iteration.")
    }
  }

  # --- Correlated parameter sampling ------------------------------------
  if (!is.na(correlated_params_sampled) && correlated_params_sampled == "independent") {
    problems <- c(problems, paste(
      "Correlated distribution parameters (e.g. Gompertz shape/rate) are being resampled",
      "INDEPENDENTLY -- this distorts the implied survival. Sample jointly (MVN on the",
      "transformed scale, or non-parametric bootstrap)."))
  }

  # --- Number of individuals --------------------------------------------
  if (!is.na(n_individuals)) {
    if (n_individuals < min_individuals) {
      problems <- c(problems, sprintf(paste(
        "n_individuals = %d may be too few for the stochastic mean to converge (rule-of-thumb",
        ">= %d; check convergence of mean costs/QALYs as n grows)."), n_individuals, min_individuals))
    } else {
      notes <- c(notes, sprintf("n_individuals = %d (check mean-outcome convergence regardless).", n_individuals))
    }
  }

  # --- Report ------------------------------------------------------------
  for (nt in notes) message("  - ", nt)
  if (length(problems) == 0) {
    message("OK: DES design decisions look coherent. (Still validate the built model, e.g. cross-check recorded OS against component event times.)")
    return(invisible(TRUE))
  }
  message(sprintf("%d issue(s) to resolve at design stage:", length(problems)))
  for (p in problems) message("  ! ", p)
  invisible(FALSE)
}
