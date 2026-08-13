#' NICE-aligned survival extrapolation (DSU TSD 14 & 21)
#'
#' A workflow tool for parametric survival extrapolation in the style NICE
#' expects: fit the standard parametric set (and splines), compare on fit AND
#' plausibility, test proportional hazards, overlay fits on the KM, inspect
#' smoothed hazards, extrapolate with an optional general-population mortality
#' floor, and build a "no continued treatment benefit" scenario.
#'
#' This tool helps you DO the analysis; it does not by itself satisfy NICE —
#' selection must still rest on visual fit, external/long-term plausibility and
#' clinical input, not AIC alone (see references/tsd-methods/survival-extrapolation-tsd14-21.md).
#'
#' Requires: flexsurv, survival. (ggplot2 optional, only for plotting.)
#'   install.packages(c("flexsurv","survival"))

suppressMessages({ library(flexsurv); library(survival) })

STD_DISTS <- c("exp","weibull","gompertz","lnorm","llogis","gengamma")

#' Fit the standard parametric set to one arm (or pooled).
#' @param time,status numeric vectors (status: 1 = event, 0 = censored)
#' @param dists character vector of flexsurv distributions
#' @param spline_k integer >=1 to also fit a Royston-Parmar spline (NULL to skip)
#' @param spline_scale "hazard","odds", or "normal"
fit_survival_set <- function(time, status, dists = STD_DISTS,
                             spline_k = NULL, spline_scale = "hazard") {
  d <- data.frame(time = time, status = status)
  S <- Surv(d$time, d$status)
  fits <- list()
  for (dist in dists) {
    fit <- tryCatch(flexsurvreg(S ~ 1, data = d, dist = dist), error = function(e) NULL)
    if (!is.null(fit)) fits[[dist]] <- fit
  }
  if (!is.null(spline_k)) {
    for (k in spline_k) {
      nm <- paste0("spline_", spline_scale, "_k", k)
      fit <- tryCatch(flexsurvspline(S ~ 1, data = d, k = k, scale = spline_scale),
                      error = function(e) NULL)
      if (!is.null(fit)) fits[[nm]] <- fit
    }
  }
  fits
}

#' AIC/BIC comparison table (lower = better fit; judge with plausibility too).
compare_fits <- function(fits) {
  tab <- data.frame(
    model = names(fits),
    logLik = sapply(fits, function(f) as.numeric(f$loglik)),
    npars = sapply(fits, function(f) f$npars),
    AIC = sapply(fits, function(f) f$AIC),
    BIC = sapply(fits, function(f) {
      ll <- as.numeric(f$loglik); k <- f$npars; n <- f$N
      -2 * ll + k * log(n)
    }),
    row.names = NULL
  )
  tab[order(tab$AIC), ]
}

#' Proportional-hazards check between two arms.
#' Returns the cox.zph result; inspect $table (small p => PH doubtful).
ph_check <- function(time, status, group) {
  cox <- coxph(Surv(time, status) ~ group)
  zph <- cox.zph(cox)
  cat("Proportional-hazards test (small p suggests PH is violated):\n")
  print(zph$table)
  invisible(zph)
}

#' Predicted survival (or hazard) over a time grid, tidy long format,
#' for overlaying on the KM or plotting hazards.
predict_curves <- function(fits, times, type = c("survival","hazard")) {
  type <- match.arg(type)
  do.call(rbind, lapply(names(fits), function(nm) {
    s <- summary(fits[[nm]], t = times, type = type, ci = FALSE)[[1]]
    data.frame(model = nm, time = s$time, est = s$est, type = type)
  }))
}

#' Kaplan-Meier as a tidy data frame, for overlaying observed vs fitted.
km_frame <- function(time, status, group = NULL) {
  f <- if (is.null(group)) survfit(Surv(time, status) ~ 1)
       else survfit(Surv(time, status) ~ group)
  data.frame(time = f$time, surv = f$surv, n.risk = f$n.risk,
             strata = if (is.null(f$strata)) "all"
                      else rep(names(f$strata), f$strata))
}

#' Restricted mean survival to horizon `tau` (trapezoidal on predicted S(t)).
#' Version-independent; for discounted RMST pass a discount rate.
rmst <- function(fit, tau, by = tau/2000, discount = 0) {
  tg <- seq(0, tau, by = by)
  s <- summary(fit, t = tg, type = "survival", ci = FALSE)[[1]]$est
  disc <- 1 / (1 + discount) ^ tg
  sum((head(s*disc, -1) + tail(s*disc, -1)) / 2 * diff(tg))
}

#' Apply a general-population mortality FLOOR to an extrapolated curve.
#' A modelled curve must not imply lower yearly mortality than the matched
#' general population (TSD 14). Supply background yearly conditional survival
#' p_bg[t] = prob. surviving year t in the general population (from a life table,
#' starting at the cohort's age). Returns floored survival on yearly grid.
#' @param model_surv numeric vector S_model at years 0,1,2,...,H
#' @param p_bg numeric vector length H of general-pop conditional yearly survival
apply_background_floor <- function(model_surv, p_bg) {
  H <- length(p_bg)
  stopifnot(length(model_surv) == H + 1)
  p_m <- model_surv[-1] / head(model_surv, -1)        # model conditional survival
  p_m[!is.finite(p_m)] <- 0
  p_capped <- pmin(p_m, p_bg)                          # cannot beat the gen pop
  c(1, cumprod(p_capped))
}

#' "No continued treatment benefit" scenario: after `cutoff`, the treatment
#' arm's conditional survival follows the control arm's. Returns yearly survival.
#' @param years 0,1,...,H grid
#' @param surv_active,surv_control S(t) for the two arms on `years`
#' @param cutoff time after which benefit stops accruing
no_continued_benefit <- function(years, surv_active, surv_control, cutoff) {
  p_a <- surv_active[-1] / head(surv_active, -1)
  p_c <- surv_control[-1] / head(surv_control, -1)
  mids <- years[-1]
  p_mix <- ifelse(mids > cutoff, p_c, p_a)
  c(1, cumprod(p_mix))
}

# ---------------------------------------------------------------------------
if (sys.nframe() == 0) {        # `Rscript survival_extrapolation.R`
  data(bc, package = "flexsurv")               # breast cancer demo data
  bc$status <- bc$censrec                       # 1 = event
  cat("== PH check across prognostic groups ==\n")
  ph_check(bc$rectime, bc$status, bc$group)

  good <- subset(bc, group == "Good")
  cat("\n== Fit standard set + 1-knot spline (Good group) ==\n")
  fits <- fit_survival_set(good$rectime, good$status, spline_k = 1)
  print(compare_fits(fits))

  cat("\n== RMST to 5 years (1825 days), best-AIC model ==\n")
  best <- names(sort(sapply(fits, function(f) f$AIC)))[1]
  cat(sprintf("Model %s: RMST = %.1f days\n", best, rmst(fits[[best]], tau = 1825)))

  cat("\nReminder: choose the extrapolation on fit + plausibility + external\n",
      "data, apply the general-population mortality floor, and take a range of\n",
      "scenarios (incl. no-continued-benefit) to the model — not AIC alone.\n", sep = "")
}
