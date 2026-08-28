#' NICE-aligned survival extrapolation (DSU TSD 14 & 21)
#'
#' A workflow tool for parametric survival extrapolation in the style EAGs and
#' committees expect (the TSD 14/21 process is DSU guidance, not a PMG36
#' manual requirement — PMG36 itself asks for justified extrapolation, calls
#' scenario analyses "desirable", and says they "should include" the
#' no-further-benefit assumption, 4.2.24): fit the standard parametric set (and
#' splines), compare on fit AND plausibility, test proportional hazards,
#' overlay fits on the KM, inspect smoothed hazards, extrapolate with an
#' optional general-population mortality floor (a pragmatic alternative to
#' TSD 21's preferred internal excess-hazard route — see `bhazard` in the
#' survival-analysis-hta skill), and build "no continued treatment benefit" /
#' gradual-waning scenarios per PMG36 4.2.24.
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
    else message(dist, ": failed to fit — excluded from the comparison set")
  }
  if (!is.null(spline_k)) {
    for (k in spline_k) {
      nm <- paste0("spline_", spline_scale, "_k", k)
      fit <- tryCatch(flexsurvspline(S ~ 1, data = d, k = k, scale = spline_scale),
                      error = function(e) NULL)
      if (!is.null(fit)) fits[[nm]] <- fit
      else message(nm, ": failed to fit — excluded from the comparison set")
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
    # BIC uses n = observations (f$N); some prefer effective n = events for
    # right-censored data (Volinsky & Raftery 1998) — a known ambiguity, not
    # an error. With heavy censoring the two can rank models differently.
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
  cat("Proportional-hazards test (small p suggests PH is violated;",
      "a large p is weak evidence FOR PH when events are few):\n")
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
#' @param discount a rate PER UNIT OF `t` (the model's time axis), applied as
#'   (1+discount)^-t. This demo's time axis is DAYS (`rectime`). Passing an
#'   annual discount rate directly here silently discounts per day, not per
#'   year (on this demo, 5-year RMST 1621.7 days collapses to 29.1 with 0.035
#'   applied per day; the correct per-day rate gives 1497.1). Convert first:
#'   discount_per_day <- (1 + r_annual)^(1/365.25) - 1
rmst <- function(fit, tau, by = tau/2000, discount = 0) {
  tg <- seq(0, tau, by = by)
  s <- summary(fit, t = tg, type = "survival", ci = FALSE)[[1]]$est
  disc <- 1 / (1 + discount) ^ tg
  sum((head(s*disc, -1) + tail(s*disc, -1)) / 2 * diff(tg))
}

#' Apply a general-population mortality FLOOR to an extrapolated curve.
#'
#' A modelled all-cause curve should not imply lower yearly mortality than the
#' matched general population. TSD 14 uses external data only as a validity
#' comparator; TSD 21 (Rutherford et al., Jan 2020, p. 89) states that
#' incorporating background mortality is "recommended ... and is essential
#' for cure models". The principled route is an internal additive excess-
#' hazard / relative-survival model (general-population hazard + a modelled
#' excess hazard combined inside the likelihood, e.g. flexsurv's `bhazard` —
#' see the survival-analysis-hta skill), which by construction cannot go
#' below p_bg. This function instead implements the cruder, pragmatic
#' POST-HOC route: a floor on modelled mortality (equivalently a cap on
#' conditional survival) applied AFTER fitting. It is simple, but Sweeting
#' et al. (2023, p. 738) note this switching approach "causes a
#' discontinuity in the all-cause hazard function" where the floor first
#' binds, and describe excess-hazard modelling as the more statistically
#' coherent route. The floor should be
#' presented as a scenario/sensitivity check, not silently folded into the
#' base case. Apply exactly ONE background-mortality mechanism (this floor,
#' an additive excess-hazard model, or an SMR-based adjustment) — never both.
#'
#' Supply background yearly conditional survival p_bg[t] = probability of
#' surviving year t in the general population, matched to the cohort on age
#' (baseline age + elapsed years), sex, and calendar year (e.g. from national
#' life tables) — not a single unmatched population-average curve.
#' @param model_surv numeric vector S_model at years 0,1,2,...,H
#' @param p_bg numeric vector length H of matched general-pop conditional
#'   yearly survival (age-at-baseline + t, sex, calendar-year matched)
apply_background_floor <- function(model_surv, p_bg) {
  H <- length(p_bg)
  stopifnot(length(model_surv) == H + 1)
  p_m <- model_surv[-1] / head(model_surv, -1)        # model conditional survival
  p_m[!is.finite(p_m)] <- 0
  p_capped <- pmin(p_m, p_bg)                          # cannot beat the gen pop
  c(1, cumprod(p_capped))
}

#' "No continued treatment benefit" scenario (PMG36 4.2.24: "assuming the
#' technology does not provide further benefit beyond the technologies' use").
#' After `cutoff`, the active arm's conditional survival (hazard) is set equal
#' to the control arm's — benefit STOPS ACCRUING, but the benefit already
#' accrued up to `cutoff` is RETAINED, so the two survival curves stay
#' separated and run parallel thereafter; they do NOT converge. (Convergence
#' would be the distinct, more pessimistic "loss of accrued benefit" scenario,
#' obtainable simply by returning `surv_control` itself from `cutoff`
#' onwards.) For a gradual version of this scenario see `waning_scenario()`.
#' Returns yearly survival.
#' @param years 0,1,...,H grid
#' @param surv_active,surv_control S(t) for the two arms on `years`
#' @param cutoff time after which benefit stops accruing
no_continued_benefit <- function(years, surv_active, surv_control, cutoff) {
  p_a <- surv_active[-1] / head(surv_active, -1)
  p_c <- surv_control[-1] / head(surv_control, -1)
  p_a[!is.finite(p_a)] <- 0        # guard 0/0 once a curve hits exactly 0
  p_c[!is.finite(p_c)] <- 0
  t_end <- years[-1]               # interval end points
  p_mix <- ifelse(t_end > cutoff, p_c, p_a)
  c(1, cumprod(p_mix))
}

#' Gradual treatment-effect waning: the hazard ratio moves linearly to 1 over
#' [t_start, t_stop] (PMG36 4.2.24's "no further benefit" scenario, softened
#' from an immediate step to a ramp). Before t_start the active arm keeps its
#' full modelled benefit; after t_stop the two arms have equal hazards, as in
#' `no_continued_benefit()`, which is this function's step-change special case
#' (t_start == t_stop == cutoff). Annual conditional survival is interpolated
#' as p_w = p_a^(1-w) * p_c^w, i.e. exactly linear interpolation of the annual
#' hazards h_w = (1-w)*h_a + w*h_c (since p = exp(-h)), so the hazard ratio
#' ramps linearly from its trial value to 1 over the window.
#' Caveat: like `no_continued_benefit()`, this operates on marginal
#' (population-average) curves — forcing the marginal HR to 1 is only an
#' approximation of individual-level effect waning and can bias RMST when the
#' arms are heterogeneous (surviving patients are a selected subgroup).
#' @param years 0,1,...,H grid
#' @param surv_active,surv_control S(t) for the two arms on `years`
#' @param t_start,t_stop waning window: full benefit before t_start, none
#'   (equal hazards) from t_stop onwards
waning_scenario <- function(years, surv_active, surv_control, t_start, t_stop) {
  p_a <- surv_active[-1] / head(surv_active, -1)
  p_c <- surv_control[-1] / head(surv_control, -1)
  p_a[!is.finite(p_a)] <- 0        # guard 0/0 once a curve hits exactly 0
  p_c[!is.finite(p_c)] <- 0
  t_end <- years[-1]               # interval end points
  w <- if (t_stop <= t_start) {    # degenerate window = the step-change case
    as.numeric(t_end > t_start)    # (avoids 0/0 = NaN on a grid point)
  } else {
    pmin(pmax((t_end - t_start) / (t_stop - t_start), 0), 1)
  }
  p_w <- p_a^(1 - w) * p_c^w
  c(1, cumprod(p_w))
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

  cat("\n== Scenario helpers on a toy example (yearly grid, years 0-10) ==\n")
  years <- 0:10
  # two synthetic curves: active arm has the lower hazard (better survival)
  h_active <- 0.05; h_control <- 0.10; h_bg <- 0.07
  surv_active  <- exp(-h_active  * years)
  surv_control <- exp(-h_control * years)
  p_bg <- rep(exp(-h_bg), length(years) - 1)  # toy matched background conditional survival

  floored    <- apply_background_floor(surv_active, p_bg)
  no_benefit <- no_continued_benefit(years, surv_active, surv_control, cutoff = 4)
  waned      <- waning_scenario(years, surv_active, surv_control, t_start = 4, t_stop = 8)

  is_valid_curve <- function(s) {
    isTRUE(all.equal(s[1], 1)) && all(diff(s) <= 1e-8) && all(s >= -1e-8 & s <= 1 + 1e-8)
  }
  stopifnot(is_valid_curve(floored), is_valid_curve(no_benefit), is_valid_curve(waned))
  # floored conditional survival <= model's every year => floored S <= model S
  stopifnot(all(floored <= surv_active + 1e-8))
  # gradual waning sits between the immediate step-change and full benefit
  stopifnot(all(waned <= surv_active + 1e-8), all(waned >= no_benefit - 1e-8))
  cat("Invariants OK: each curve starts at 1, is non-increasing, stays in [0,1];\n",
      "floored <= model; no-continued-benefit <= gradual waning <= full-benefit active.\n", sep = "")

  cat("\nReminder: choose the extrapolation on fit + plausibility + external data;\n",
      "address general-population mortality (TSD 21 excess-hazard preferred; the\n",
      "post-hoc floor here is a pragmatic fallback); and take a range of scenarios\n",
      "(incl. no-continued-benefit / gradual waning) to the model — not AIC alone.\n", sep = "")
}
