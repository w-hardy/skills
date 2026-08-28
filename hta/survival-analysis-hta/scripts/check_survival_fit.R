#!/usr/bin/env Rscript
#' Sanity-check a fitted flexsurv survival model before extrapolating it or
#' feeding it into an economic model. Catches the failure modes that can
#' print without an obvious error: non-convergence, a non-identified fit
#' (singular/near-singular covariance matrix), an extrapolated survival or
#' hazard curve that leaves its valid range, and a defective/cure-like tail
#' whose mean is undefined.
#'
#' Works on objects from flexsurv::flexsurvreg() or flexsurv::flexsurvspline()
#' (flexsurvspline objects inherit flexsurvreg).
#'
#' Usage:
#'   source("check_survival_fit.R")
#'   check_survival_fit(fit, horizon = 40)                     # horizon in model time units
#'   check_survival_fit(fit, horizon = 40, bg_hazard = 0.02)   # scalar background hazard
#'   check_survival_fit(fit, horizon = 40,
#'                       bg_hazard = function(t) 0.01 + 0.0006 * t)  # age-varying background
#'
#' What is checked (see the "Checks" comment blocks below for the maths):
#'   1. Optimiser convergence (fit$opt$convergence).
#'   2. Finite parameter estimates and SEs on the transformed scale (fit$res.t).
#'   3. Covariance-matrix validity: symmetric positive definite, extreme
#'      pairwise correlations (|rho| > 0.99), reciprocal condition number.
#'   4. Prediction validity on (0, horizon]: survival finite, in [0,1],
#'      non-increasing; hazard finite and >= 0.
#'   5. Defective-tail / plateau report: S(horizon), and an informational
#'      note if the survival has already plateaued above 0 by the horizon.
#'   6. Restricted mean survival (RMST) to the horizon, with a CI.
#'   7. Optional: model hazard at the horizon vs. a supplied background
#'      hazard (all-cause models only).
#'   8. Informational: parameters vs. events, if fit$events is available.
#'
#' Requires the flexsurv package (used for vcov()/summary() on the fitted
#' object). Loading flexsurv itself (to create a fit to check) is the
#' caller's responsibility.

if (!requireNamespace("flexsurv", quietly = TRUE)) {
  stop(
    "check_survival_fit() requires the 'flexsurv' package.\n",
    "Install it with install.packages(\"flexsurv\") and try again.",
    call. = FALSE
  )
}

# --- State accumulator ------------------------------------------------------
# `st` is an environment, which R passes and mutates by reference. Writing
# `st$notes <- c(st$notes, msg)` inside a tryCatch() handler (or any other
# nested closure) updates the *same* object the caller holds -- there is no
# need for (and no risk from) `<<-`, whose search for `notes`/`problems`
# would otherwise start in tryCatch's *calling* environment and silently
# create/overwrite a variable in globalenv() instead of the local one. Every
# check below reports through add_note()/add_problem() on this one `st`.
new_check_state <- function() {
  st <- new.env(parent = emptyenv())
  st$notes <- character(0)
  st$problems <- character(0)
  st
}

add_note <- function(st, msg) {
  st$notes <- c(st$notes, msg)
  invisible(NULL)
}

add_problem <- function(st, msg) {
  st$problems <- c(st$problems, msg)
  invisible(NULL)
}

fmt <- function(x, digits = 3) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) return("NA")
  paste(format(round(x, digits), nsmall = digits), collapse = ", ")
}

# Human-readable covariate-pattern label per row of a tidy
# summary.flexsurvreg() data frame ("" when the model has no covariates).
# Every per-pattern message below embeds this label so that multi-arm output
# is unambiguous whatever order summary() returns rows in.
.row_labels <- function(df) {
  grp_cols <- setdiff(names(df), c("time", "est", "lcl", "ucl"))
  if (length(grp_cols) == 0) return(rep("", nrow(df)))
  do.call(paste, c(Map(function(cn) paste0(cn, "=", df[[cn]]), grp_cols),
                   list(sep = ", ")))
}
.lbl <- function(key) if (nzchar(key)) paste0(" [", key, "]") else ""

# Group a tidy summary data frame by covariate pattern, PRESERVING summary()'s
# own row order (first appearance), with the pattern label as the list names.
# Handles the no-covariate ("~ 1") case (one group) the same way.
.group_by_pattern <- function(df) {
  key <- .row_labels(df)
  split(seq_len(nrow(df)), factor(key, levels = unique(key)))
}

check_survival_fit <- function(fit, horizon = NULL, bg_hazard = NULL,
                                B = 500, hazard_grid = 200,
                                rho_warn = 0.99, ci_width_warn = 0.5) {

  if (!inherits(fit, "flexsurvreg")) {
    stop("Expected a flexsurvreg/flexsurvspline object (flexsurvspline inherits flexsurvreg).")
  }

  st <- new_check_state()

  # --- (1) Optimiser convergence -----------------------------------------
  # fit$opt$convergence is populated by flexsurv's own optim() call for
  # EVERY distribution, including the "survreg-wrapped" ones (exponential,
  # Weibull, log-normal, log-logistic). flexsurv only uses survreg to
  # generate *starting values* for those distributions before running its
  # own optim() -- the convergence code is present and means the same thing
  # (0 = converged) for all of them, so there is no distribution for which
  # this check should be skipped.
  conv <- tryCatch(fit$opt$convergence, error = function(e) NULL)
  if (is.null(conv) || length(conv) == 0 || is.na(conv)) {
    add_problem(st, "No optimiser convergence code found on fit$opt$convergence -- this is expected to always be present; treat the fit as unverified.")
  } else if (conv != 0) {
    add_problem(st, sprintf("Optimiser did NOT converge (code %s) -- estimates are unreliable.", conv))
  } else {
    add_note(st, "Optimiser converged (code 0).")
  }

  # --- (2) Finite estimates and SEs on the transformed scale -------------
  # res.t holds estimates/SEs on flexsurv's transformed (real-line) scale,
  # e.g. log(scale) for a Weibull, identity for a Gompertz shape.
  rt <- tryCatch(fit$res.t, error = function(e) NULL)
  if (!is.null(rt) && all(c("est", "se") %in% colnames(rt))) {
    est <- rt[, "est"]; se <- rt[, "se"]
    if (any(!is.finite(est))) {
      add_problem(st, sprintf(
        "Non-finite parameter estimate(s): %s.",
        paste(rownames(rt)[!is.finite(est)], collapse = ", ")))
    }
    if (any(!is.finite(se))) {
      add_problem(st, sprintf(
        "Non-finite SE for parameter(s): %s -- the Hessian is not invertible / the fit is not identified.",
        paste(rownames(rt)[!is.finite(se)], collapse = ", ")))
    }
    if (all(is.finite(est)) && all(is.finite(se))) {
      add_note(st, sprintf("All %d parameter estimate(s) and SE(s) are finite.", length(est)))
    }
  } else {
    add_note(st, "Could not read fit$res.t (estimates/SEs); skipping the finite-estimate check.")
  }

  # --- (3) Covariance-matrix validity --------------------------------------
  # A well-identified fit has a symmetric positive-definite vcov(); an
  # extreme pairwise correlation on the transformed scale (|rho| > rho_warn)
  # is the scale-free signature of a ridge in the likelihood -- two
  # parameters trading off against each other with almost no independent
  # information -- which is the thing "weak identifiability" actually means
  # (unlike an SE/|estimate| ratio, this is invariant to time units and to
  # a parameter's estimate happening to sit near zero).
  V <- tryCatch(vcov(fit), error = function(e) NULL)
  if (!is.null(V) && is.matrix(V) && nrow(V) == ncol(V) && nrow(V) >= 1) {
    if (!isTRUE(all.equal(V, t(V), tolerance = 1e-6))) {
      add_problem(st, "vcov(fit) is not symmetric -- treat the fit as suspect.")
    }

    ev <- tryCatch(eigen(V, symmetric = TRUE, only.values = TRUE)$values, error = function(e) NULL)
    if (is.null(ev) || any(!is.finite(ev))) {
      add_problem(st, "Could not compute eigenvalues of vcov(fit) (non-finite covariance matrix).")
    } else if (any(ev <= 0)) {
      add_problem(st, sprintf(
        "vcov(fit) is not positive definite (smallest eigenvalue %.3g) -- the fit is not locally identified.",
        min(ev)))
    } else {
      add_note(st, sprintf("Covariance matrix is symmetric positive definite (%d parameter(s)).", nrow(V)))
      if (nrow(V) >= 2) {
        recip_cond <- min(ev) / max(ev)
        add_note(st, sprintf(
          "Reciprocal condition number of vcov(fit): %.3g (closer to 0 = closer to non-identified; informational).",
          recip_cond))

        cc <- cov2cor(V)
        offdiag_mask <- lower.tri(cc)
        worst <- max(abs(cc[offdiag_mask]))
        bad <- which(offdiag_mask & abs(cc) > rho_warn, arr.ind = TRUE)
        if (nrow(bad) > 0) {
          # High correlation between ADJACENT SPLINE BASIS COEFFICIENTS
          # (gamma0..gammaK+1 in flexsurvspline fits) is structural
          # (overlapping basis functions), not by itself evidence of a
          # pathological fit: the covariance is already known to be positive
          # definite on this branch and the prediction-validity checks below
          # remain blocking, so those pairs are reported as notes. Every
          # other extreme pair -- covariate coefficients, anc terms like
          # gamma1(trt), and all pairs in non-spline fits -- keeps the
          # blocking classification: there a near-ridge is a genuine
          # identifiability signal. Classification is per pair, so a
          # covariate ridge in a spline fit is still flagged even when a
          # structural basis pair happens to correlate more strongly.
          # Basis coefficients are identified by POSITION (flexsurv orders
          # res.t/vcov as baseline parameters first, then covariate and anc
          # coefficients), not by name -- a covariate a user happened to call
          # "gamma2" must not be mistaken for a basis term.
          is_spline <- isTRUE(grepl("survspline", fit$dlist$name))
          n_base <- tryCatch(length(fit$dlist$pars), error = function(e) 0L)
          for (r in seq_len(nrow(bad))) {
            pair <- c(rownames(cc)[bad[r, 1]], colnames(cc)[bad[r, 2]])
            val <- abs(cc[bad[r, 1], bad[r, 2]])
            pair_names <- paste(pair, collapse = " / ")
            if (is_spline && all(c(bad[r, 1], bad[r, 2]) <= n_base)) {
              add_note(st, sprintf(
                "Spline basis coefficients %s have |correlation| = %.4f (> %.2f) -- expected/structural for adjacent basis terms, not treated as a failure on its own; judge against the prediction-validity checks below.",
                pair_names, val, rho_warn))
            } else {
              add_problem(st, sprintf(
                "Parameters %s have |correlation| = %.4f (> %.2f) -- near-ridge likelihood, weak identifiability.",
                pair_names, val, rho_warn))
            }
          }
        } else {
          add_note(st, sprintf("Largest pairwise parameter correlation: %.3f.", worst))
        }
      }
    }
  } else {
    add_note(st, "Could not read vcov(fit); skipping covariance-validity checks.")
  }

  # --- (viii) Parameters vs. events (informational) -----------------------
  npars <- tryCatch(fit$npars, error = function(e) NULL)
  nevents <- tryCatch(fit$events, error = function(e) NULL)
  if (is.null(nevents) || length(nevents) != 1 || !is.finite(nevents)) {
    # fit$events is populated on every flexsurvreg/flexsurvspline object in
    # current flexsurv, so this branch is not expected to run in practice --
    # kept as a defensive fallback (derive from the stored Surv() status
    # column) rather than erroring if a future/older version omits it.
    nevents <- tryCatch(sum(fit$data$Y[, "status"]), error = function(e) NULL)
  }
  if (!is.null(npars) && !is.null(nevents) &&
      length(npars) == 1 && length(nevents) == 1 &&
      is.finite(npars) && is.finite(nevents) && nevents > 0) {
    add_note(st, sprintf(
      "%d parameter(s) vs %d event(s) (%.1f events/parameter) -- informational; a low ratio (rough rule of thumb: below ~10) can signal weak identifiability even when the fit reports as converged. Context-dependent, not a universal threshold.",
      npars, nevents, nevents / npars))
  }
  # else: fit$events not available on this object -- skip silently, as instructed.

  # --- Checks that need a horizon ------------------------------------------
  if (is.null(horizon)) {
    add_note(st, "No horizon supplied; skipped prediction-validity, defective-tail, RMST and background-hazard checks. Pass horizon = <lifetime horizon, in the fit's own time units> to enable them.")
  } else {
    stopifnot(is.numeric(horizon), length(horizon) == 1, is.finite(horizon), horizon > 0)

    # --- (4) Prediction validity over (0, horizon] -------------------------
    # Grid starts just above 0 rather than at 0 itself: some fitted hazards
    # are mathematically infinite exactly at t=0 (e.g. a Weibull with
    # shape<1), which is a property of the distribution, not a fit defect.
    tg <- seq(horizon / max(hazard_grid, 10), horizon, length.out = max(hazard_grid, 10))

    sv <- tryCatch(summary(fit, type = "survival", t = tg, ci = FALSE, tidy = TRUE),
                    error = function(e) {
                      add_note(st, paste0("Could not compute extrapolated survival: ", conditionMessage(e)))
                      NULL
                    })
    if (!is.null(sv)) {
      s_est <- sv$est
      if (any(!is.finite(s_est))) {
        add_problem(st, "Extrapolated survival is non-finite somewhere on (0, horizon].")
      }
      if (any(is.finite(s_est) & (s_est < -1e-8 | s_est > 1 + 1e-8))) {
        add_problem(st, "Extrapolated survival leaves the [0, 1] range somewhere on (0, horizon].")
      }
      groups <- .group_by_pattern(sv)
      mono_ok <- all(vapply(groups, function(idx) {
        ii <- idx[order(sv$time[idx])]
        all(diff(sv$est[ii]) <= 1e-6)
      }, logical(1)))
      if (!mono_ok) {
        add_problem(st, "Extrapolated survival is not monotone non-increasing on (0, horizon] (beyond numerical tolerance) -- most often a spline tail with a negative implied hazard.")
      } else {
        add_note(st, "Extrapolated survival is finite, within [0,1], and non-increasing on (0, horizon].")
      }
    }

    hz <- tryCatch(summary(fit, type = "hazard", t = tg, ci = FALSE, tidy = TRUE),
                    error = function(e) {
                      add_note(st, paste0("Could not compute extrapolated hazard: ", conditionMessage(e)))
                      NULL
                    })
    if (!is.null(hz)) {
      h_est <- hz$est
      if (any(!is.finite(h_est))) {
        add_problem(st, "Extrapolated hazard is non-finite somewhere on (0, horizon].")
      }
      if (any(is.finite(h_est) & h_est < -1e-8)) {
        add_problem(st, "Extrapolated hazard goes NEGATIVE somewhere on (0, horizon] -- the model is producing an invalid hazard.")
      }
      if (all(is.finite(h_est)) && all(h_est >= -1e-8)) {
        add_note(st, "Extrapolated hazard is finite and non-negative on (0, horizon].")
      }
    }

    # --- (5) Defective-tail / plateau report --------------------------------
    # A Gompertz with negative shape, a hazard-scale spline with a
    # non-positive tail slope, or a deliberate cure fit can all produce a
    # survival curve that plateaus above 0: S(infinity) > 0, the
    # distribution is "defective", and the untruncated mean is undefined
    # (RMST to a finite horizon remains well defined -- see (6)). This is
    # sometimes exactly what's intended (cure models; a negative-shape
    # Gompertz chosen deliberately) and sometimes a sign of a badly
    # extrapolating fit -- either way it needs to be seen, not silently
    # accepted, so it is reported as an informational note, not a problem.
    tail_pts <- tryCatch(
      summary(fit, type = "survival", t = c(0.9 * horizon, horizon), ci = FALSE, tidy = TRUE),
      error = function(e) NULL)
    if (!is.null(tail_pts)) {
      groups <- .group_by_pattern(tail_pts)
      for (g in seq_along(groups)) {
        key <- names(groups)[g]
        idx <- groups[[g]]
        ii <- idx[order(tail_pts$time[idx])]
        if (length(ii) == 2) {
          s90 <- tail_pts$est[ii[1]]
          sH  <- tail_pts$est[ii[2]]
          if (is.finite(sH)) {
            add_note(st, sprintf("S(horizon = %g)%s = %.4g.", horizon, .lbl(key), sH))
            if (is.finite(s90) && (s90 - sH) < 1e-6 && sH > 0.01) {
              add_note(st, sprintf(
                "%sS(0.9*horizon)-S(horizon) = %.3g with S(horizon) = %.3g > 0.01: survival has effectively plateaued -- this fit implies a cure-like plateau / defective distribution (S(infinity) > 0). Deliberate for a cure model or a negative-shape Gompertz; an error otherwise. Mean-to-infinity is then undefined -- report RMST to a finite horizon instead of type=\"mean\".",
                if (nzchar(key)) paste0("[", key, "] ") else "", s90 - sH, sH))
            }
          }
        }
      }
    }

    # --- (6) RMST at the horizon, with a CI ---------------------------------
    rm <- tryCatch(summary(fit, type = "rmst", t = horizon, ci = TRUE, B = B, tidy = TRUE),
                    error = function(e) {
                      add_note(st, paste0("Could not compute RMST/CI at the horizon: ", conditionMessage(e)))
                      NULL
                    })
    if (!is.null(rm) && all(c("est", "lcl", "ucl") %in% names(rm))) {
      rm_labs <- .row_labels(rm)
      for (i in seq_len(nrow(rm))) {
        add_note(st, sprintf(
          "RMST to t=%g%s: %.4g (95%% CI %.4g to %.4g, B=%d bootstrap draws).",
          horizon, .lbl(rm_labs[i]), rm$est[i], rm$lcl[i], rm$ucl[i], B))
        width <- rm$ucl[i] - rm$lcl[i]
        if (is.finite(width) && is.finite(rm$est[i]) && rm$est[i] != 0 &&
            width > ci_width_warn * abs(rm$est[i])) {
          add_note(st, sprintf(
            "[informational, not a failure] RMST CI width%s (%.4g) exceeds %.0f%% of the estimate (%.4g) -- substantial extrapolation uncertainty at this horizon.",
            .lbl(rm_labs[i]), width, 100 * ci_width_warn, rm$est[i]))
        }
      }
    }

    # --- (7) Optional background-hazard plausibility check ------------------
    # All-cause models only: if `fit` was itself estimated with a bhazard
    # argument (a relative-survival / excess-hazard model), its predictions
    # are relative survival, not all-cause, and this comparison does not
    # apply in the way described below -- flagged as a note rather than
    # skipped, since the caller may still find the comparison informative
    # for the excess component.
    if (!is.null(bg_hazard)) {
      call_txt <- tryCatch(paste(deparse(fit$call), collapse = " "), error = function(e) "")
      if (grepl("bhazard\\s*=", call_txt)) {
        add_note(st, "bg_hazard was supplied but this fit already used bhazard= (relative-survival/excess-hazard model) -- the hazard compared below is the EXCESS hazard, not all-cause; the background-plausibility check below is designed for all-cause fits.")
      }
      bg_h <- if (is.function(bg_hazard)) bg_hazard(horizon) else bg_hazard
      model_h <- tryCatch(summary(fit, type = "hazard", t = horizon, ci = FALSE, tidy = TRUE),
                            error = function(e) NULL)
      if (!is.null(model_h) && is.finite(bg_h)) {
        mh_labs <- .row_labels(model_h)
        for (i in seq_len(nrow(model_h))) {
          mh <- model_h$est[i]
          if (is.finite(mh)) {
            if (mh < bg_h) {
              add_problem(st, sprintf(
                "Model hazard at horizon%s (%.4g) is BELOW the supplied background hazard (%.4g) -- implausible for an all-cause model (disease hazard cannot be negative, so all-cause hazard cannot be below background). Check the extrapolation, or confirm this really is intended as an all-cause fit.",
                .lbl(mh_labs[i]), mh, bg_h))
            } else {
              add_note(st, sprintf(
                "Model hazard at horizon%s (%.4g) is at or above the supplied background hazard (%.4g) -- passes the background-plausibility check.",
                .lbl(mh_labs[i]), mh, bg_h))
            }
          }
        }
      }
    }
  }

  # --- Fit statistics (kept for context; not a pass/fail check) -----------
  aic <- tryCatch(fit$AIC, error = function(e) NA)
  loglik <- tryCatch(fit$loglik, error = function(e) NA)
  add_note(st, sprintf("AIC = %s, log-likelihood = %s, parameters = %s",
                        fmt(aic), fmt(loglik), fmt(npars)))

  # --- Report ---------------------------------------------------------------
  message("Survival fit check:")
  for (n in st$notes) message("  - ", n)
  if (length(st$problems) == 0) {
    message("No blocking problems found. Still: plot the extrapolated hazard yourself before trusting the tail.")
    return(invisible(TRUE))
  } else {
    message(sprintf("%d issue(s) needing attention:", length(st$problems)))
    for (p in st$problems) message("  ! ", p)
    return(invisible(FALSE))
  }
}

# --- Self-test / demo --------------------------------------------------------
# Runs only under `Rscript check_survival_fit.R` (sys.nframe() == 0 at top
# level), not when this file is source()'d into another session -- the same
# pattern used by the sibling script
# hta/nice-economic-evaluation/scripts/survival_extrapolation.R.
if (sys.nframe() == 0) {

  library(flexsurv)

  fail <- function(msg) {
    message("SELF-TEST FAILED: ", msg)
    quit(status = 1)
  }

  set.seed(2026)

  ## 1. Clean Weibull, n ~ 300, ~30% censoring -------------------------------
  n <- 300
  t_event <- rweibull(n, shape = 1.3, scale = 10)
  cens_time <- runif(n, 0, 30)
  time <- pmin(t_event, cens_time)
  status <- as.integer(t_event <= cens_time)
  cat(sprintf("\n[demo data] n=%d, censoring = %.0f%%\n", n, 100 * mean(status == 0)))

  fit_weibull <- flexsurvreg(Surv(time, status) ~ 1, dist = "weibull")
  fit_gompertz <- flexsurvreg(Surv(time, status) ~ 1, dist = "gompertz")

  horizon <- 30

  cat("\n=== Clean Weibull fit (expect: no problems) ===\n")
  ok_weibull <- check_survival_fit(fit_weibull, horizon = horizon)
  if (!isTRUE(ok_weibull)) fail("clean Weibull fit reported problems")

  cat("\n=== Clean Gompertz fit (expect: no problems) ===\n")
  ok_gompertz <- check_survival_fit(fit_gompertz, horizon = horizon)
  if (!isTRUE(ok_gompertz)) fail("clean Gompertz fit reported problems")

  ## 2. Generalized gamma fit to a 12-observation subsample (expect: problems)
  ## Deterministic "immature data" cut: the 12 EARLIEST observations by time
  ## (an early interim analysis), rather than a random sample of 12 -- a
  ## 3-parameter gengamma on that few, that early, is reliably unstable,
  ## where a random 12-of-300 sample is only sometimes unstable.
  cat("\n=== Generalized gamma fit to a 12-observation subsample (expect: problems) ===\n")
  idx12 <- order(time)[1:12]
  fit_gengamma_sick <- flexsurvreg(Surv(time[idx12], status[idx12]) ~ 1, dist = "gengamma")
  ok_sick <- check_survival_fit(fit_gengamma_sick, horizon = 3 * max(time[idx12]))
  if (!isFALSE(ok_sick)) fail("gengamma fit on 12 observations reported NO problems (expected weak-identifiability flags)")

  ## 3. Negative-shape Gompertz: exercises the defective-tail / plateau note -
  cat("\n=== Negative-shape Gompertz: defective-tail / plateau note (expect: no *problems*, but the plateau note present) ===\n")
  n_neg <- 800
  t_neg <- rgompertz(n_neg, shape = -0.3, rate = 0.4)
  cens_neg <- runif(n_neg, 0, 20)
  time_neg <- pmin(t_neg, cens_neg)
  status_neg <- as.integer(t_neg <= cens_neg)
  fit_gompertz_neg <- flexsurvreg(Surv(time_neg, status_neg) ~ 1, dist = "gompertz")
  cat(sprintf("fitted shape = %.4f (negative => defective/plateauing distribution)\n",
              fit_gompertz_neg$res["shape", "est"]))
  horizon_neg <- 80  # far enough out that the plateau is numerically resolved
  ok_neg <- check_survival_fit(fit_gompertz_neg, horizon = horizon_neg)
  if (!isTRUE(ok_neg)) fail("negative-shape Gompertz reported problems (the plateau should be informational only)")

  ## 4. False-positive scenario (Reviewer C): a well-identified Gompertz with
  ##    true shape = 0 (i.e. truly exponential), n = 500. The retired SE/|est|
  ##    ratio heuristic flagged this (ratio > 100x on a tight, correct fit);
  ##    the new checks must NOT flag it.
  cat("\n=== False-positive check: well-identified Gompertz, true shape = 0, n=500 (expect: no problems) ===\n")
  n_fp <- 500
  t_fp <- rexp(n_fp, rate = 0.05)             # shape=0 Gompertz IS exponential
  cens_fp <- rexp(n_fp, rate = 0.05 / 4)
  time_fp <- pmin(t_fp, cens_fp)
  status_fp <- as.integer(t_fp <= cens_fp)
  fit_fp <- flexsurvreg(Surv(time_fp, status_fp) ~ 1, dist = "gompertz")
  cat(sprintf("fitted shape = %.5f (se = %.5f) -- near zero, tightly estimated, NOT a problem\n",
              fit_fp$res.t["shape", "est"], fit_fp$res.t["shape", "se"]))
  ok_fp <- check_survival_fit(fit_fp, horizon = 40)
  if (!isTRUE(ok_fp)) fail("false-positive scenario (Gompertz shape truly 0) was flagged -- the SE-ratio false positive has returned")

  ## 5. Spline with extreme (structural) basis-coefficient correlation --------
  ## Adjacent natural-spline basis coefficients are often correlated above
  ## 0.99 on perfectly healthy fits (reproduced on ~10/25 seeds at k=2).
  ## Regression test: such a fit must NOT be blocked when the covariance is
  ## positive definite and the prediction checks pass -- the correlation is
  ## reported as a note instead. (A non-spline near-ridge fit, e.g. test 2's
  ## 12-observation gengamma, must remain blocked.)
  cat("\n=== Spline fit with structural basis-coefficient correlation (expect: no problems) ===\n")
  set.seed(22)
  n_spl <- 500
  t_spl <- rweibull(n_spl, shape = 1.3, scale = 10)
  cens_spl <- runif(n_spl, 0, 30)
  time_spl <- pmin(t_spl, cens_spl)
  status_spl <- as.integer(t_spl <= cens_spl)
  fit_spline <- flexsurvspline(Surv(time_spl, status_spl) ~ 1, k = 2, scale = "hazard")
  cc_spl <- cov2cor(vcov(fit_spline))
  max_rho_spl <- max(abs(cc_spl[lower.tri(cc_spl)]))
  cat(sprintf("max |correlation| between spline coefficients: %.4f\n", max_rho_spl))
  if (max_rho_spl <= 0.99) fail(sprintf(
    "spline self-test no longer exercises the >0.99 structural-correlation note path (max |rho| = %.4f under this R/flexsurv version) -- adjust the seed/knots so the branch is genuinely tested", max_rho_spl))
  ok_spline <- check_survival_fit(fit_spline, horizon = 30)
  if (!isTRUE(ok_spline)) fail("healthy spline fit was blocked (structural basis-coefficient correlation must be a note, not a problem)")

  ## 5b. Spline with genuinely collinear COVARIATES (expect: still blocked) --
  ## The spline relaxation must apply only to basis-coefficient pairs
  ## (gamma0..gammaK+1). Two near-duplicate covariates create a real
  ## likelihood ridge between their coefficients; a spline fit containing
  ## them must NOT be waved through.
  cat("\n=== Spline fit with collinear covariates (expect: problems) ===\n")
  set.seed(7)
  x1 <- rnorm(n_spl)
  x2 <- x1 + rnorm(n_spl, 0, 0.02)
  d_col <- data.frame(time = time_spl, status = status_spl, x1 = x1, x2 = x2)
  fit_spline_col <- flexsurvspline(Surv(time, status) ~ x1 + x2, data = d_col,
                                    k = 1, scale = "hazard")
  ok_spline_col <- check_survival_fit(fit_spline_col, horizon = 30)
  if (!isFALSE(ok_spline_col)) fail("spline fit with collinear covariates was NOT blocked (covariate near-ridge must remain a problem even in spline fits)")

  ## 6. bg_hazard demonstration ------------------------------------------------
  cat("\n=== bg_hazard demonstration: scalar background above the fitted early hazard (expect: flagged) ===\n")
  ok_bg_scalar <- check_survival_fit(fit_weibull, horizon = 1, bg_hazard = 0.08)
  if (!isFALSE(ok_bg_scalar)) fail("bg_hazard scalar demo did not flag a model hazard below background")

  cat("\n=== bg_hazard demonstration: function of t, comfortably below the fitted hazard (expect: clean) ===\n")
  ok_bg_fun <- check_survival_fit(fit_weibull, horizon = horizon,
                                   bg_hazard = function(t) 0.005 + 0.0001 * t)
  if (!isTRUE(ok_bg_fun)) fail("bg_hazard function demo unexpectedly flagged a problem")

  cat("\n=== ALL SELF-TESTS PASSED ===\n")
}
