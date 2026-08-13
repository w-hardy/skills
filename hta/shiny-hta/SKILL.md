---
name: shiny-hta
description: "Wrap an existing R health-economic / cost-effectiveness model in an interactive Shiny web application for HTA, making a model accessible to non-R users (clients, payers, ERG/EAG reviewers) without exposing the R code. Use whenever the task is building, structuring, debugging, or reviewing the Shiny front-end of a health economic model: ui/server design, reactivity, controlling when a CEA recomputes, editable input tables (rhandsontable), dynamic/conditional UI (uiOutput, renderUI, modules), start-up object-availability errors (req, is.null), saving/restoring model state, or scaling a model with many interdependent inputs. Trigger on phrases like \"Shiny\", \"shiny app\", \"interactive model\", \"ui and server\", \"reactivity\", \"reactiveValues\", \"rhandsontable\", \"renderUI\", or \"deploy my HTA model\". This is a software-engineering skill, not a statistical one. For the model's methods defer to the relevant methods skill and to nice-economic-evaluation; build and validate the model first, then wrap it here."
---

# Shiny front-ends for HTA models

Wrapping an existing R cost-effectiveness model in an interactive web app, following R-HTA chapter 14.

> Sources: *R for Health Technology Assessment* (Baio et al., online at <https://gianluca.statistica.it/books/online/r-hta/>) — chapter mapping verified against the live ToC (Ch. 14 = R and Shiny in HTA), accessed 2026-07-03. Shiny function references cross-checked against the shiny package documentation, accessed 2026-07-03. Shiny lets a model's audience — clients, payers, ERG/EAG reviewers, decision-makers — change inputs and see results in a browser, Excel-style, without touching (or installing) R. The analogy that orients everything: a Shiny HTA model is to an R model what a VBA-driven workbook is to Excel — an interactive layer over a calculation engine, with the same "recalculate on change" behaviour.

## The one rule that governs everything: build the model first, wrap it second

**Develop and validate a complete, working model in plain R before involving Shiny.** This isn't a stylistic preference — it's the single most important practical lesson of the chapter, for concrete reasons:
- **QC and debugging get much harder once code is wrapped in `ui`/`server`.** You can't run a Shiny app line-by-line; it executes as two large functions. Plain R is linear and traceable.
- Structural/uncertainty-analysis ideas (first-order, second-order, structural) surface during model development and are far easier to build in *before* the reactivity layer exists.
- You can only decide *what to expose* in the UI once you know which calculations matter.
- **Keep the standalone R script and update it alongside the app** — it's your cross-check that the app produces identical results, which is essential once reactivity gets layered.

Write that core model so it's *wrap-ready*: every value used downstream (as an input to another function, or shown in a plot/table) returned to the top level, and **all inputs gathered into one central `parameters` list**. That central list is the seam the app will plug into, and the discipline pays off enormously in a reactive setting (see the DSLR pattern below).

## Anatomy: ui + server

A Shiny app is a `ui` (layout + interactive widgets the user sees) and a `server` (the engine — an R function of `input`, `output`, `session`). `input` carries widget values into the server; `output` carries rendered results back. They form a continuous feedback loop while the app runs — change an input, the server reruns dependent code, outputs update — exactly like Excel set to "Automatic". Launch with `shinyApp(ui, server)`, or `runApp()` with separate `ui.R`/`server.R`/`app.R` files (the recommended structure for anything non-trivial). `shinydashboard` gives a header/sidebar/body layout (the chapter's choice); `bslib` + `bs_theme()` is the more modern theming layer and works equally well.

## Reactivity is the whole skill — choose the right primitive

Getting reactivity right is what separates a responsive, reviewable model from a slow, fragile one. The four core primitives, and the judgement for each:

- **`reactive()`** — produces a *cached value*, recomputed when any input it uses changes; called like a function (`x()`). Use for intermediate calculations consumed downstream.
- **`observe()`** — runs *side effects* (e.g. printing intermediate values to console for QC), no return value. Recomputes on any change.
- **`eventReactive()`** — like `reactive()` but recomputes *only* when a specified trigger fires (e.g. a "Run model" button). Returns a value.
- **`observeEvent()`** — like `observe()` but fires only on a specified trigger. No return value.

The governing trade-off is **functionality vs speed**:
- **Too much reactivity** → the whole CEA recomputes on every keystroke, which is slow and can run steps out of order (a later step firing before an upstream value updates, silently using a stale value).
- **Too little reactivity** → the user must press a confusing sequence of buttons; the app feels broken.

The chapter's concrete recommendation: make inputs *reactive* up to the central `parameters` list, then gate the **expensive model run behind an `eventReactive`/`observeEvent` on a "Run model" button**, so the user sets all inputs live but the CEA only computes when they choose. This gives you control over calculation order — important when many steps depend on one event. (Modern Shiny also offers `bindEvent()`, which unifies the event-handling idiom; the `ignoreNULL`/`ignoreInit` arguments control start-up behaviour.)

Break the calculation into a chain of small reactive chunks, not a few monolithic blocks: small chunks let you print intermediate results for QC and keep reactivity monitorable. See `references/reactivity.md`.

## The start-up object-availability trap

The most common Shiny-breaking bug, and one specific to the reactive model: **reactive expressions run at start-up, but some inputs don't exist yet.** Inputs defined in the `ui` (`numericInput`, `selectInput`) *are* available at start-up; but anything **not yet rendered** is not — crucially, `actionButton` events, and **any input defined as an `output` in the server** (notably `rhandsontable` tables, and inputs created by `renderUI`). A `reactive` that uses such an input will error on launch.

Three tools, with a clear decision rule:
- **`req(x)`** — halts the reactive until `x` exists. Use when the downstream calc can simply *wait*.
- **`is.null(x)`** — test existence and fall back to base-case data if absent. Use when the input has **downstream dependencies that are needed at start-up** (so you can't just wait).
- **`eventReactive` on a button**, optionally auto-clicked at start-up with `shinyjs::click()` (guarded by an `is.null` check) — when you want explicit control.

`outputOptions(..., suspendWhenHidden = FALSE)` can force an output to exist before its tab renders, but it still won't make the *input* exist at start-up — so `req`/`is.null` remain necessary. Default to `req` extensively; use `is.null` where there are start-up downstream dependencies. See `references/dynamic-ui-and-startup.md`.

## Editable tables and dynamic UI

- **`rhandsontable`** — an Excel-like editable table as a single input, holding many values at once (with validation, formats, colour). Because it's defined as an `output` in the server, it's subject to the start-up trap above — guard it. A common pattern: edit in the table → push to the input list via `hot_to_r()` on a "commit" button (`eventReactive`), with an `is.null` fallback to base-case values so the user needn't visit the page for the model to run.
- **`conditionalPanel`** — show/hide UI by an input's value (e.g. only reveal results after "Run model" pressed: `"input.Run_model > 0"`).
- **`uiOutput` + `renderUI`** — generate UI reactively from the server, so inputs can depend on other inputs (switching comparator type changes which dosing inputs appear). Powerful but `renderUI` is computationally expensive — don't over-nest it.
- **Modules** — package a `ui`+`server` section as reusable functions with namespacing; good for recycling components across models, at the cost of `return`-only data flow out of the module.

## Scaling: the DSLR reactiveValues pattern (the chapter's signature contribution)

For a realistic CEA — potentially *thousands* of interdependent inputs, dynamic UIs that move in and out of existence (e.g. up to N drugs, each of several types with different input sets) — naming a `reactive` per input is unmanageable, and Shiny's bookmarking can't restore nested dynamic UI state. The chapter's solution is a central `reactiveValues` data-management pattern, often labelled **D / S / L / R**:

- **`D` (defaults)** — every possible permutation of inputs, including those not currently shown. Defined outside the server (in `global.R`).
- **`R` (responsive)** — updates *instantly* as the user edits the UI (high priority), via `observeEvent` per input.
- **`L` (live)** — updates *only when the user commits* (a button), via `L$section <- R$section`. **UI elements render from `L`, never `R`.**
- **`S` (saved)** — a snapshot for save/load (`reactiveValuesToList()` + `saveRDS()`); replacing `L`/`D` with `S` restores a previous analysis live.

Why it works: rendering UI from `L` (not `R`) avoids the infinite update loop (UI→server→`L`→UI…) that direct binding causes; committing via buttons creates intuitive "choke points"; and because the lists hold *all* permutations, nested UI elements keep their values even when they vanish and reappear. One line — `L <- R` — does the work of thousands of `isolate()`/`reactive` calls, and because `D`/`R`/`L` share structure you can **debug the model offline** by setting `R <- D; L <- D` and stepping through the server logic without launching the app. It's more groundwork than a few `reactive()`s, so it's overkill for simple apps — but for a full HTA CEA it's what keeps the code simple, QC-able, and scalable. See `references/reactivevalues-pattern.md`.

## Transparency — the thing reviewers actually need

Code-based models carry a "black box" reputation, and a Shiny UI alone does **not** let a reviewer understand the model's mechanism. Counter it deliberately: surface intermediate calculations and QC checks in the UI (not just final results), present input/output tables (`DT` package), use `observe()` to print intermediate values to console during development, and generate reproducible QC/results reports with `rmarkdown` (runnable from a button in the app). Section and comment the `ui`/`server` heavily — they read as two long functions you can't run incrementally, so navigation aids matter far more than in linear scripts. A well-built Shiny app *can* be highly transparent; that takes intent, and reviewers (ERG/EAG) will expect it.

## Common pitfalls

- **Wrapping in Shiny before the R model works.** QC and debugging get much harder afterwards; build and validate the plain-R model first, and keep it as a cross-check.
- **Over-reactivity.** Recomputing the whole CEA on every keystroke is slow and can run steps out of order; gate the expensive run behind a button (`eventReactive`).
- **Under-reactivity.** Forcing a confusing button sequence makes the app feel broken; balance against the above.
- **Start-up errors from not-yet-existing inputs.** `actionButton`, `rhandsontable`, and `renderUI` inputs don't exist at launch; guard every dependent reactive with `req` or `is.null`.
- **Binding dynamic UI directly to the responsive object.** Rendering UI from `R` (instant) instead of `L` (committed) creates infinite update loops; render from the committed/live copy.
- **Over-nesting `renderUI`.** It's expensive; deep nesting makes the app laggy with elements flickering in and out — prefer an `rhandsontable` over a `lapply`-in-`renderUI` for repeated rows.
- **A UI that implies false transparency.** The interface doesn't explain the model; expose intermediate calcs, QC checks, and an `rmarkdown` report, or reviewers will (rightly) treat it as a black box.
- **No state save/load for a complex model.** Nested dynamic UIs can't be restored by Shiny bookmarking alone; use the `reactiveValues` (D/S/L/R) approach with `saveRDS`.
- **Letting users edit inappropriate cells.** E.g. costs after death — restrict editable `rhandsontable` cells to where input is valid.

## Validating app design before building

`scripts/check_shiny_design.R` checks the architecture decisions the chapter warns about, before you write the app: whether a working standalone R model exists first, whether the expensive model run is gated behind an event (vs recomputing on every input change), whether inputs that don't exist at start-up (`rhandsontable`, `renderUI`, `actionButton`) are guarded with `req`/`is.null`, whether dynamic UI renders from the committed (`L`) rather than responsive (`R`) object, and whether a model of the stated complexity warrants the `reactiveValues` pattern over ad-hoc `reactive`s. It's a design checklist, not a code linter — run it at the planning stage.
