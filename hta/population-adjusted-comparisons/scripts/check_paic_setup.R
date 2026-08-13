#' Design-stage checker for a population-adjusted indirect comparison (PAIC),
#' encoding NICE DSU TSD 18 routing logic. A PAIC's validity is decided by the
#' method/assumption/target-population fit, BEFORE any model is fitted -- the
#' wrong method for the target population is a problem no execution can fix.
#' Flags:
#'   - MAIC/STC chosen when the target population != the AgD study population
#'     (they can only estimate in the AgD study population)
#'   - MAIC/STC chosen for a network larger than two studies (they don't
#'     synthesise networks coherently)
#'   - anchored vs unanchored mismatched to covariate adjustment
#'     (anchored: effect modifiers only; unanchored: prognostic + EM + baseline)
#'   - unanchored analyses (flag the much stronger, untestable assumption)
#'   - MAIC with low ESS / poor overlap
#'   - plug-in-means STC with a non-collapsible effect measure
#'   - small-network ML-NMR relying on the shared-effect-modifier assumption
#'
#' Usage:
#'   source("check_paic_setup.R")
#'   check_paic_setup(
#'     method = "maic",                 # "maic" / "stc" / "ml_nmr" / "ipd_nmr"
#'     anchored = TRUE,
#'     ipd = "mixed",                   # "full" / "mixed" / "none"
#'     n_studies = 2,
#'     target_is_agd_study_pop = FALSE, # is the decision target the AgD study pop?
#'     ess = 406, original_n = 707,     # MAIC overlap (optional)
#'     stc_form = NA,                   # "plug_in_means" / "g_computation" / NA
#'     effect_measure = "OR",           # OR/HR (non-collapsible) vs RD/probit/identity
#'     adjusts = "effect_modifiers",    # "effect_modifiers" / "prognostic_and_em" / "none"
#'     shared_em_assumption = NA,       # ML-NMR: TRUE/FALSE/NA
#'     ess_frac_warn = 0.5)

check_paic_setup <- function(method,
                             anchored = NA,
                             ipd = NA,
                             n_studies = NA,
                             target_is_agd_study_pop = NA,
                             ess = NA, original_n = NA,
                             stc_form = NA,
                             effect_measure = NA,
                             adjusts = NA,
                             shared_em_assumption = NA,
                             ess_frac_warn = 0.5) {

  method <- tolower(method)
  problems <- character(0); notes <- character(0)
  noncollapsible <- !is.na(effect_measure) &&
    toupper(effect_measure) %in% c("OR","HR","ODDS RATIO","HAZARD RATIO","LOG OR","LOG HR")

  notes <- c(notes, sprintf("Method: %s | %s | IPD: %s | %s studies.",
                            toupper(method),
                            if (isTRUE(anchored)) "anchored" else if (isFALSE(anchored)) "UNANCHORED" else "anchoring NA",
                            ifelse(is.na(ipd), "NA", ipd),
                            ifelse(is.na(n_studies), "?", n_studies)))

  # --- Target population reachability (the decisive TSD 18 check) --------
  if (method %in% c("maic","stc")) {
    if (isFALSE(target_is_agd_study_pop)) {
      problems <- c(problems, sprintf(paste(
        "%s can only estimate in the AgD STUDY population, but the decision target population",
        "differs. Using this estimate for the target reintroduces the bias adjustment was meant",
        "to remove. Use ML-NMR (or full-IPD NMR) to target an arbitrary population."), toupper(method)))
    } else if (isTRUE(target_is_agd_study_pop)) {
      notes <- c(notes, sprintf("%s is OK here only because the AgD study population IS the decision target.", toupper(method)))
    } else {
      notes <- c(notes, sprintf("Confirm the decision target population: %s is valid ONLY if it equals the AgD study population.", toupper(method)))
    }
  }

  # --- Network size vs method ------------------------------------------
  if (method %in% c("maic","stc") && !is.na(n_studies) && n_studies > 2) {
    problems <- c(problems, sprintf(paste(
      "%s is a two-study method and cannot coherently synthesise a %d-study network. Separate",
      "MAICs against different AgD studies sit in different, non-comparable populations and reuse",
      "the IPD. Use ML-NMR."), toupper(method), n_studies))
  }

  # --- Anchored / unanchored vs covariate adjustment -------------------
  if (isFALSE(anchored)) {
    notes <- c(notes, paste(
      "UNANCHORED: relies on conditional constancy of ABSOLUTE effects -- much stronger,",
      "untestable, residual bias unknown. Flag elevated decision risk explicitly."))
    if (!is.na(adjusts) && adjusts == "effect_modifiers") {
      problems <- c(problems, paste(
        "Unanchored analysis adjusting for effect modifiers ONLY. Unanchored needs PROGNOSTIC",
        "factors and effect modifiers (and baseline risk for absolute outcomes)."))
    }
  }
  if (isTRUE(anchored) && !is.na(adjusts) && adjusts == "prognostic_and_em") {
    notes <- c(notes, paste(
      "Anchored analysis adjusting for prognostic factors too -- usually unnecessary (they cancel",
      "by randomisation), though may be needed under a non-collapsible measure with differing baseline risk."))
  }
  if (isFALSE(anchored) && !is.na(adjusts) && adjusts == "none") {
    problems <- c(problems, "Unanchored analysis with no covariate adjustment declared -- absolute-effect prediction needs all prognostic + effect-modifying covariates.")
  }

  # --- MAIC overlap / ESS ----------------------------------------------
  if (method == "maic" && !is.na(ess) && !is.na(original_n) && original_n > 0) {
    frac <- ess / original_n
    if (frac < ess_frac_warn) {
      problems <- c(problems, sprintf(paste(
        "MAIC ESS is %.0f of %d (%.0f%% of original N) -- below %.0f%%, indicating poor overlap.",
        "MAIC cannot extrapolate; expect bias and unstable variance. Inspect the weight histogram."),
        ess, original_n, 100 * frac, 100 * ess_frac_warn))
    } else {
      notes <- c(notes, sprintf("MAIC ESS %.0f of %d (%.0f%% of original N) -- overlap reasonable; still inspect the weight histogram.",
                                ess, original_n, 100 * frac))
    }
  } else if (method == "maic" && (is.na(ess) || is.na(original_n))) {
    notes <- c(notes, "MAIC: compute ESS = (Σw)²/Σw² and inspect the weight histogram -- mandatory overlap diagnostics.")
  }

  # --- STC plug-in-means trap ------------------------------------------
  if (method == "stc") {
    if (!is.na(stc_form) && stc_form == "plug_in_means") {
      if (noncollapsible) {
        problems <- c(problems, sprintf(paste(
          "Plug-in-means STC with a non-collapsible measure (%s) is biased (aggregation +",
          "non-collapsibility). Use G-computation STC (Remiro-Azocar 2022)."), toupper(effect_measure)))
      } else {
        notes <- c(notes, "Plug-in-means STC: fine only if the model is linear in covariates AND the measure is collapsible; otherwise use G-computation STC.")
      }
    } else if (!is.na(stc_form) && stc_form == "g_computation") {
      notes <- c(notes, "G-computation STC -- avoids aggregation/non-collapsibility bias and captures uncertainty correctly.")
    }
  }

  # --- ML-NMR shared effect modifier assumption ------------------------
  if (method == "ml_nmr") {
    if (isTRUE(shared_em_assumption) && !is.na(n_studies) && n_studies <= 2) {
      problems <- c(problems, paste(
        "Small (<=2 study) ML-NMR relying on the shared-effect-modifier assumption: without it the",
        "model isn't identified and estimates are limited to the AgD population (like MAIC). State",
        "the assumption; it's only reasonable for treatments sharing a class/mode of action."))
    } else if (isTRUE(shared_em_assumption)) {
      notes <- c(notes, "ML-NMR uses the shared-effect-modifier assumption -- assess it (relax one covariate at a time) or drop it given enough data.")
    }
    if (isFALSE(target_is_agd_study_pop) || is.na(target_is_agd_study_pop))
      notes <- c(notes, "ML-NMR can target any population -- supply the target covariate summaries as newdata, and a baseline-risk distribution for absolute effects.")
  }

  # --- Report ------------------------------------------------------------
  for (nt in notes) message("  - ", nt)
  if (length(problems) == 0) {
    message("OK: PAIC design looks coherent with TSD 18. (Still assess assumptions on the fitted model: ESS/overlap for MAIC; residual heterogeneity/inconsistency for ML-NMR.)")
    return(invisible(TRUE))
  }
  message(sprintf("%d issue(s) to resolve at design stage:", length(problems)))
  for (p in problems) message("  ! ", p)
  invisible(FALSE)
}
