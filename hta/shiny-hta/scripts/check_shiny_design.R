#' Design-stage checklist for a Shiny front-end on an HTA model, encoding the
#' architecture warnings from R-HTA chapter 14. A Shiny app can't be run
#' line-by-line, so getting the architecture right BEFORE building saves the most
#' painful debugging. This is a design checker, not a code linter. It flags:
#'   - wrapping in Shiny before a standalone R model exists & is validated
#'   - the expensive model run NOT gated behind an event (recompute-on-keystroke)
#'   - inputs that don't exist at start-up (rhandsontable / renderUI / actionButton)
#'     used in reactives without a req/is.null guard
#'   - dynamic UI rendered from the responsive (R) object instead of live (L)
#'   - a complex model not using the reactiveValues (DSLR) pattern
#'   - no state save/load for a complex model with dynamic UI
#'   - transparency: intermediate calcs / QC not surfaced for reviewers
#'
#' Usage:
#'   source("check_shiny_design.R")
#'   check_shiny_design(
#'     standalone_model_first = TRUE,   # built & validated plain-R model first?
#'     run_gated_by_event = TRUE,       # heavy CEA run behind a button (eventReactive)?
#'     startup_inputs = c("rhandsontable","renderUI"),  # inputs absent at start-up
#'     startup_guarded = TRUE,          # are dependent reactives req/is.null guarded?
#'     n_inputs = 2000,                 # rough input count
#'     dynamic_ui = TRUE,               # UI elements move in/out of existence?
#'     uses_reactivevalues_pattern = FALSE,  # DSLR central data management?
#'     ui_renders_from = "R",           # "L" (live) or "R" (responsive)
#'     has_state_saveload = FALSE,      # save/restore model state?
#'     exposes_intermediate_qc = FALSE) # intermediate calcs / QC shown in UI?

check_shiny_design <- function(standalone_model_first = NA,
                               run_gated_by_event = NA,
                               startup_inputs = character(0),
                               startup_guarded = NA,
                               n_inputs = NA,
                               dynamic_ui = NA,
                               uses_reactivevalues_pattern = NA,
                               ui_renders_from = NA,
                               has_state_saveload = NA,
                               exposes_intermediate_qc = NA,
                               complex_threshold = 200) {

  problems <- character(0); notes <- character(0)
  startup_risky <- intersect(tolower(startup_inputs),
                             c("rhandsontable","renderui","uioutput","actionbutton"))

  complex <- (!is.na(n_inputs) && n_inputs >= complex_threshold) || isTRUE(dynamic_ui)
  notes <- c(notes, sprintf("App complexity: %s (%s inputs%s).",
                            if (complex) "COMPLEX" else "simple",
                            ifelse(is.na(n_inputs), "?", n_inputs),
                            if (isTRUE(dynamic_ui)) ", dynamic UI" else ""))

  # --- 1. Build the model first ----------------------------------------
  if (isFALSE(standalone_model_first)) {
    problems <- c(problems, paste(
      "No validated standalone R model before Shiny. QC/debugging get much harder once code is",
      "wrapped in ui/server (can't run line-by-line). Build & validate the plain-R model first,",
      "and keep it as a cross-check that the app gives identical results."))
  } else if (isTRUE(standalone_model_first)) {
    notes <- c(notes, "Standalone R model built first -- keep it updated as a result cross-check.")
  }

  # --- 2. Event-gating the expensive run -------------------------------
  if (isFALSE(run_gated_by_event)) {
    problems <- c(problems, paste(
      "The CEA run is not gated behind an event (eventReactive/observeEvent on a 'Run' button).",
      "Recomputing the whole model on every input change is slow and can run steps out of order,",
      "silently using stale values. Make inputs reactive up to the parameters list, then gate the",
      "run on a button."))
  } else if (isTRUE(run_gated_by_event)) {
    notes <- c(notes, "Expensive run gated behind an event -- good control over computation order.")
  }

  # --- 3. Start-up object availability ---------------------------------
  if (length(startup_risky) > 0) {
    if (isFALSE(startup_guarded)) {
      problems <- c(problems, sprintf(paste(
        "Inputs that DON'T exist at start-up are used without guards: %s. Reactives run at launch",
        "and will error. Guard with req() (if the calc can wait) or is.null() with a base-case",
        "fallback (if it has start-up downstream dependencies)."),
        paste(startup_risky, collapse = ", ")))
    } else if (isTRUE(startup_guarded)) {
      notes <- c(notes, sprintf("Start-up-absent inputs (%s) are req/is.null guarded -- good.",
                                paste(startup_risky, collapse = ", ")))
    } else {
      notes <- c(notes, sprintf("Confirm req/is.null guards on start-up-absent inputs: %s.",
                                paste(startup_risky, collapse = ", ")))
    }
  }

  # --- 4. Dynamic UI must render from L, not R -------------------------
  if (isTRUE(dynamic_ui) && !is.na(ui_renders_from)) {
    if (toupper(ui_renders_from) == "R") {
      problems <- c(problems, paste(
        "Dynamic UI renders from the RESPONSIVE object (R), which updates instantly -- this creates",
        "an infinite update loop (UI->server->R->UI...). Render UI from the LIVE/committed object",
        "(L), updated only on a commit button."))
    } else if (toupper(ui_renders_from) == "L") {
      notes <- c(notes, "Dynamic UI renders from the live/committed object (L) -- avoids the update loop.")
    }
  }

  # --- 5. reactiveValues pattern for complex models --------------------
  if (complex && isFALSE(uses_reactivevalues_pattern)) {
    problems <- c(problems, paste(
      "A complex model (many interdependent / dynamic inputs) without the reactiveValues (D/S/L/R)",
      "pattern. Per-input reactives become unmanageable and nested dynamic UI loses its values on",
      "refresh. Use a central reactiveValues data-management approach."))
  } else if (complex && isTRUE(uses_reactivevalues_pattern)) {
    notes <- c(notes, "Complex model using the reactiveValues (D/S/L/R) pattern -- scalable and QC-able.")
  } else if (!complex && isTRUE(uses_reactivevalues_pattern)) {
    notes <- c(notes, "Simple app using the DSLR pattern -- workable, but a few reactive() objects may be clearer here.")
  }

  # --- 6. State save/load for complex/dynamic models -------------------
  if (isTRUE(dynamic_ui) && isFALSE(has_state_saveload)) {
    problems <- c(problems, paste(
      "Dynamic UI with no state save/load. Shiny bookmarking can't restore nested dynamic UI state;",
      "use the reactiveValues approach with reactiveValuesToList() + saveRDS() to save/restore L."))
  }

  # --- 7. Transparency for reviewers -----------------------------------
  if (isFALSE(exposes_intermediate_qc)) {
    problems <- c(problems, paste(
      "Intermediate calculations / QC checks not surfaced in the UI. A Shiny interface alone does",
      "NOT explain the model -- reviewers (ERG/EAG) will treat it as a black box. Expose intermediate",
      "calcs and QC (DT tables), and offer an rmarkdown report."))
  } else if (isTRUE(exposes_intermediate_qc)) {
    notes <- c(notes, "Intermediate calcs / QC surfaced for transparency -- good for ERG/EAG review.")
  }

  # --- Report ------------------------------------------------------------
  for (nt in notes) message("  - ", nt)
  if (length(problems) == 0) {
    message("OK: Shiny app design looks sound. (Section/comment ui & server heavily -- they can't be run incrementally.)")
    return(invisible(TRUE))
  }
  message(sprintf("%d issue(s) to resolve at design stage:", length(problems)))
  for (p in problems) message("  ! ", p)
  invisible(FALSE)
}
