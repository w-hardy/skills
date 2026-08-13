#' Severity shortfall calculator (NICE PMG36 Table 6.1, method per DSU TSD 23)
#'
#' Computes absolute and proportional QALY shortfall and the resulting severity
#' QALY weight (1, 1.2, or 1.7). The general-population QALYs are built from a
#' life table (mortality) and general-population EQ-5D utility norms; the
#' "with condition" QALYs come from YOUR model's established-practice arm.
#'
#' IMPORTANT — reference data: this script does NOT ship ONS life tables or
#' EQ-5D population norms. You must supply them (see the template below) from
#' authoritative, current sources before any real use:
#'   * mortality (qx) — ONS National Life Tables (by single year of age and sex)
#'   * utility      — a recent published general-population EQ-5D utility source
#' The tiny `.demo_reference()` table at the bottom is SYNTHETIC and for checking
#' the mechanism only — it is not valid for any submission.
#'
#' Requires only base R.

# ---- core: general-population expected discounted QALYs --------------------

#' @param start_age integer, age at model start
#' @param sex "male"/"female" (must match the reference table's `sex` values)
#' @param ref data.frame with columns: age (int), sex (chr), qx (num, prob. of
#'   dying within the year at that age/sex), utility (num, mean pop EQ-5D utility)
#' @param discount annual discount rate (reference case 0.035)
#' @param max_age horizon cap (life table should extend to here)
#' @param half_cycle apply a half-cycle correction (TRUE recommended)
genpop_qalys <- function(start_age, sex, ref, discount = 0.035,
                         max_age = 100, half_cycle = TRUE) {
  r <- ref[ref$sex == sex, ]
  r <- r[order(r$age), ]
  ages <- start_age:max_age
  # survival to the START of each year (S[1] = 1 at start_age)
  qx <- sapply(ages, function(a) {
    v <- r$qx[r$age == a]
    if (length(v) == 0) 1 else v[1]          # no data => assume death (cap)
  })
  px <- 1 - qx
  S_start <- c(1, cumprod(px))[seq_along(ages)]   # survival to start of year t
  util <- sapply(ages, function(a) {
    v <- r$utility[r$age == a]
    if (length(v) == 0) 0 else v[1]
  })
  t_idx <- ages - start_age                       # 0,1,2,...
  disc <- 1 / (1 + discount) ^ t_idx
  # within-year lived survival: half-cycle uses mean of start and end survival
  S_lived <- if (half_cycle) (S_start + c(S_start[-1], S_start[length(S_start)] * px[length(px)])) / 2 else S_start
  sum(S_lived * util * disc)
}

#' General-population QALYs for a MIX of ages/sexes (weighted average).
#' @param pop data.frame with columns age, sex, weight (weights need not sum to 1)
genpop_qalys_mix <- function(pop, ref, discount = 0.035, max_age = 100,
                             half_cycle = TRUE) {
  w <- pop$weight / sum(pop$weight)
  vals <- mapply(genpop_qalys, pop$age, pop$sex,
                 MoreArgs = list(ref = ref, discount = discount,
                                 max_age = max_age, half_cycle = half_cycle))
  sum(w * vals)
}

# ---- Table 6.1 weight ------------------------------------------------------

severity_weight <- function(absolute_shortfall = NA_real_,
                            proportional_shortfall = NA_real_) {
  w_abs <- if (is.na(absolute_shortfall)) NA
           else if (absolute_shortfall >= 18) 1.7
           else if (absolute_shortfall >= 12) 1.2 else 1.0
  w_prop <- if (is.na(proportional_shortfall)) NA
            else if (proportional_shortfall >= 0.95) 1.7
            else if (proportional_shortfall >= 0.85) 1.2 else 1.0
  cands <- c(w_abs, w_prop); cands <- cands[!is.na(cands)]
  if (!length(cands)) stop("Provide at least one shortfall.")
  weight <- max(cands)
  binding <- if (!is.na(w_abs) && w_abs == weight && (is.na(w_prop) || w_prop < weight)) "absolute"
             else if (!is.na(w_prop) && w_prop == weight && (is.na(w_abs) || w_abs < weight)) "proportional"
             else "both"
  list(weight = weight, from_absolute = w_abs, from_proportional = w_prop, binding = binding)
}

# ---- end-to-end ------------------------------------------------------------

#' @param condition_qalys discounted total QALYs under established practice,
#'   taken from the comparator/established-care arm of YOUR model.
#' @param pop data.frame (age, sex, weight) for the treated population's start
#'   age/sex distribution.
severity_shortfall <- function(condition_qalys, pop, ref, discount = 0.035,
                               max_age = 100, half_cycle = TRUE) {
  gp <- genpop_qalys_mix(pop, ref, discount, max_age, half_cycle)
  abs_sf <- gp - condition_qalys
  prop_sf <- abs_sf / gp
  wt <- severity_weight(abs_sf, prop_sf)
  out <- list(genpop_qalys = gp, condition_qalys = condition_qalys,
              absolute_shortfall = abs_sf, proportional_shortfall = prop_sf,
              severity = wt)
  cat(sprintf("General-population QALYs : %.2f\n", gp))
  cat(sprintf("Condition QALYs (est.care): %.2f\n", condition_qalys))
  cat(sprintf("Absolute shortfall       : %.2f  -> x%s\n", abs_sf, wt$from_absolute))
  cat(sprintf("Proportional shortfall   : %.3f -> x%s\n", prop_sf, wt$from_proportional))
  cat(sprintf("Severity QALY weight     : x%s (binding: %s)\n", wt$weight, wt$binding))
  invisible(out)
}

# ---- reference-data template ----------------------------------------------
# Expected CSV columns: age, sex, qx, utility
# read.csv("my_reference.csv") -> pass as `ref`. Example loader:
#   ref <- read.csv("reference_lifetable_utilities.csv",
#                   colClasses = c("integer","character","numeric","numeric"))

.demo_reference <- function() {
  # SYNTHETIC, NOT REAL DATA — mechanism check only.
  ages <- 0:100
  mk <- function(sex, base_q) data.frame(
    age = ages, sex = sex,
    qx = pmin(0.99, base_q * exp(0.092 * ages)),       # crude Gompertz-ish
    utility = pmax(0.2, 0.95 - 0.0045 * pmax(0, ages - 25))
  )
  rbind(mk("male", 3e-4), mk("female", 2.5e-4))
}

if (sys.nframe() == 0) {        # run as `Rscript severity_shortfall.R`
  cat("DEMO with SYNTHETIC reference data (not for submission)\n\n")
  ref <- .demo_reference()
  pop <- data.frame(age = c(62, 62, 68), sex = c("male","female","male"),
                    weight = c(0.4, 0.4, 0.2))
  severity_shortfall(condition_qalys = 4.0, pop = pop, ref = ref)
}
