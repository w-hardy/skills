#' Sanity-check a fitted flexsurv survival model before extrapolating it or
#' feeding it into an economic model. Catches the failure modes that can print
#' without an obvious error: non-convergence, near-unidentifiable parameters
#' (huge SEs), and an extrapolated hazard that goes negative or non-finite.
#'
#' Works on objects from flexsurv::flexsurvreg() or flexsurv::flexsurvspline().
#'
#' Usage:
#'   source("check_survival_fit.R")
#'   check_survival_fit(fit, horizon = 40)               # horizon in model time units
#'   check_survival_fit(fit, horizon = 40, se_ratio_warn = 2)
#'
#' Requires the flexsurv package to be loaded for the hazard/RMST checks
#' (summary() methods). The convergence and SE checks work from the fitted
#' object's stored components alone.

check_survival_fit <- function(fit, horizon = NULL, se_ratio_warn = 2,
                               hazard_grid = 200) {

  if (!inherits(fit, c("flexsurvreg"))) {
    stop("Expected a flexsurvreg/flexsurvspline object (flexsurvspline inherits flexsurvreg).")
  }

  notes    <- character(0)
  problems <- character(0)

  # --- Convergence -------------------------------------------------------
  # flexsurvreg stores the optim() result in fit$opt, whose $convergence is
  # 0 on success. NB: for the survreg-wrapped distributions (exponential,
  # Weibull, log-normal, log-logistic) the optim step only double-checks a
  # survreg fit, so the convergence field may be structured differently or
  # absent -- hence the defensive read. A non-finite Hessian (which flexsurv
  # warns about at fit time) is the other convergence signal; we catch its
  # downstream effect via non-finite SEs below.
  conv <- tryCatch(fit$opt$convergence, error = function(e) NULL)
  if (is.null(conv) || length(conv) == 0 || is.na(conv)) {
    notes <- c(notes, "No optim convergence code found (normal for survreg-wrapped distributions like Weibull/exp/lnorm/llogis); relying on the SE/Hessian checks below instead.")
  } else if (conv != 0) {
    problems <- c(problems, sprintf("Optimiser did NOT converge (code %s) -- estimates are unreliable.", conv))
  } else {
    notes <- c(notes, "Optimiser converged (code 0).")
  }

  # --- Parameter identifiability (SE relative to |estimate|) --------------
  # res.t holds estimates and SEs on the transformed (real-line) scale, which
  # is the right scale to judge relative uncertainty.
  rt <- tryCatch(fit$res.t, error = function(e) NULL)
  if (!is.null(rt) && all(c("est", "se") %in% colnames(rt))) {
    est <- rt[, "est"]; se <- rt[, "se"]
    ratio <- abs(se) / pmax(abs(est), 1e-8)
    flagged <- which(is.finite(ratio) & ratio > se_ratio_warn)
    for (k in flagged) {
      problems <- c(problems, sprintf(
        "Parameter '%s': SE (%.3g) is %.1fx the |estimate| (%.3g) on the transformed scale -- possible weak identifiability.",
        rownames(rt)[k], se[k], ratio[k], est[k]
      ))
    }
    if (any(!is.finite(se))) {
      bad <- rownames(rt)[!is.finite(se)]
      problems <- c(problems, sprintf("Non-finite SE for parameter(s): %s -- the fit is not identified.",
                                       paste(bad, collapse = ", ")))
    }
  } else {
    notes <- c(notes, "Could not read res.t (estimates/SEs); skipping identifiability check.")
  }

  # --- Fit statistics ----------------------------------------------------
  aic <- tryCatch(fit$AIC, error = function(e) NA)
  loglik <- tryCatch(fit$loglik, error = function(e) NA)
  npars <- tryCatch(fit$npars, error = function(e) NA)
  notes <- c(notes, sprintf("AIC = %s, log-likelihood = %s, parameters = %s",
                            fmt(aic), fmt(loglik), fmt(npars)))

  # --- Extrapolated hazard finite & non-negative -------------------------
  # Only runnable if flexsurv's summary method is available and a horizon given.
  if (!is.null(horizon)) {
    haz_ok <- tryCatch({
      tg <- seq(1e-6, horizon, length.out = hazard_grid)
      hz <- summary(fit, type = "hazard", t = tg, ci = FALSE, tidy = TRUE)
      hv <- hz$est
      if (any(!is.finite(hv))) {
        problems <<- c(problems, "Extrapolated hazard is non-finite somewhere on [0, horizon].")
      }
      if (any(hv < 0, na.rm = TRUE)) {
        problems <<- c(problems, "Extrapolated hazard goes NEGATIVE -- the model is producing an invalid hazard over the horizon.")
      }
      # Informational: report hazard at the horizon for an eyeball plausibility check
      notes <<- c(notes, sprintf("Hazard at horizon (t=%g): %.4g (sense-check against disease/background mortality).",
                                 horizon, tail(hv[is.finite(hv)], 1)))
      TRUE
    }, error = function(e) {
      notes <<- c(notes, paste0("Could not compute extrapolated hazard (is flexsurv loaded?): ", conditionMessage(e)))
      FALSE
    })

    # RMST to horizon -- the economically relevant summary
    tryCatch({
      rm <- summary(fit, type = "rmst", t = horizon, ci = FALSE, tidy = TRUE)
      notes <<- c(notes, sprintf("Restricted mean survival to t=%g: %s", horizon,
                                 paste(round(rm$est, 3), collapse = ", ")))
    }, error = function(e) invisible(NULL))
  } else {
    notes <- c(notes, "No horizon supplied; skipped extrapolated-hazard and RMST checks. Pass horizon = <lifetime> to enable.")
  }

  # --- Report ------------------------------------------------------------
  message("Survival fit check:")
  for (n in notes) message("  - ", n)
  if (length(problems) == 0) {
    message("No blocking problems found. Still: plot the extrapolated hazard yourself before trusting the tail.")
    return(invisible(TRUE))
  } else {
    message(sprintf("%d issue(s) needing attention:", length(problems)))
    for (p in problems) message("  ! ", p)
    return(invisible(FALSE))
  }
}

fmt <- function(x) if (is.null(x) || length(x) == 0 || is.na(x)) "NA" else format(round(x, 2), nsmall = 2)
