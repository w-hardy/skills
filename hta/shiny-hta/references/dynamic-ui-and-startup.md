# Dynamic UI, editable tables, and the start-up trap

The features that make a Shiny HTA model feel like Excel — editable tables, UI that adapts to selections — all share one hazard: objects that don't exist when the app starts. This reference covers the tools and the guarding discipline.

> Sources: R-HTA Ch. 14 (dynamic UI, editable tables, start-up guarding in HTA Shiny apps); `shiny` reference docs (`renderUI()`/`uiOutput()`, `req()`, `isTruthy()`). Accessed 2026-07-03.

## The start-up object-availability problem

Reactive expressions (`reactive`, `observe`) **run at start-up**. But not every input exists yet:

| Available at start-up | NOT available at start-up |
|---|---|
| `numericInput`, `selectInput`, and other `ui`-defined inputs | `actionButton` events (read as `0`/unpressed) |
| | inputs defined as **outputs in the server** (`rhandsontable`) |
| | inputs created by `renderUI` / `uiOutput` |

A `reactive` that reads a not-yet-existing input **errors on launch**. This is the most common Shiny-breaking bug and it's specific to the reactive execution model.

### Three guards, with a decision rule

- **`req(x)`** — halt the reactive until `x` exists, then proceed normally. **Use when the downstream calc can simply wait** for the input. Default to this; use it extensively.
  ```r
  observe({ req(input$Drug_costs_table); ... })   # won't run until the table exists
  ```
- **`is.null(x)`** — test existence; if absent, fall back to base-case data. **Use when the input feeds downstream objects that ARE needed at start-up** (so waiting isn't an option).
  ```r
  Drug_cost_table <- eventReactive(input$Cost_update, {
    if (is.null(input$Drug_costs_table)) base_case_costs           # fallback
    else as.data.frame(hot_to_r(input$Drug_costs_table))          # user edits
  })
  ```
- **`eventReactive` on a button, auto-clicked at start-up** — gate on a button and, if it must run at launch, trigger it with `shinyjs::click("btn")` inside an `observe`, guarded by an `is.null`/`== 0` check.
  ```r
  observe(if (input$Cost_update == 0) shinyjs::click("Cost_update"))
  ```

`outputOptions(output, "id", suspendWhenHidden = FALSE)` forces an *output* to exist before its tab renders — but it still does **not** make the corresponding *input* exist at start-up, so `req`/`is.null` are still required. Don't rely on it alone.

Rule of thumb: **`req` when the calc can wait; `is.null` (with a base-case fallback) when it has start-up downstream dependencies.**

## rhandsontable — Excel-like editable tables

`rhandsontable` turns a table into a single input holding many values, with validation, number formats, and cell colouring — the closest thing to an Excel input range. It's defined as an **output in the server** and rendered with `renderRHandsontable`, so it's subject to the start-up trap.

Standard pattern: edit in the table → convert back to a data frame with `hot_to_r()` on a "commit" button (`eventReactive`), with an `is.null` fallback so the user needn't open the page for the model to run.

```r
# server: render the editable table (cells validated to a sensible range)
output$Drug_costs_table <- renderRHandsontable({
  rhandsontable(base_case_costs) |> hot_validate_numeric(cols = 1, min = 0, max = 20000)
})

# commit edits to an input list, falling back to base case if never rendered
Drug_cost_table <- eventReactive(input$Cost_update, {
  if (is.null(input$Drug_costs_table)) base_case_costs
  else as.data.frame(hot_to_r(input$Drug_costs_table))
})

# auto-commit once at start-up so downstream objects exist
observe(if (input$Cost_update == 0) shinyjs::click("Cost_update"))
```

**Only allow edits where input is valid** — e.g. don't let users enter a cost in a "death" state; restrict editable cells. An invalid editable cell is a modelling error waiting to happen.

## conditionalPanel — show/hide by input value

Render UI conditionally on an input (JavaScript-side expression, so `input.x` not `input$x`). Common use: hide results until the model has been run.

```r
conditionalPanel("input.Run_model > 0",  fluidRow(box(...)))      # results
conditionalPanel("input.Run_model == 0", h3("Press 'Run the model' to see results"))
```

## uiOutput + renderUI — UI that depends on inputs

A placeholder in the `ui` (`uiOutput("x")`) filled reactively from the server (`output$x <- renderUI({ ... })`). Lets inputs depend on other inputs — e.g. switching an IV comparator to oral changes which dosing inputs appear. Wrap multiple elements in a single `tagList`/`fluidRow`.

```r
# ui
uiOutput("Model_settings_UI")
# server
output$Model_settings_UI <- renderUI({
  tagList(numericInput("THorizon", "Time horizon", 20),
          numericInput("combo_HR", "HR for combo", 0.509))
})
```

Inputs created this way are referenced normally (`input$THorizon`) but **don't exist at start-up** — guard dependent reactives with `is.null`/`req`. **`renderUI` is computationally expensive**; deep nesting (a `renderUI` inside a `lapply` inside a `renderUI`) makes the app laggy with elements flickering. For repeated rows (e.g. per-drug unit sizes/costs), prefer an `rhandsontable` (one input, add rows) over `lapply`-in-`renderUI` — fewer buttons, more Excel-like, far more efficient.

## Modules

Package a `ui`+`server` section as paired functions with a namespace, for reuse across models and to tame large apps. Define the same `input`/`output` ids in multiple modules (only ever activate same-id modules one at a time). Drawback: like any function, objects inside a module can't be referenced outside it — use `return()` to surface values, then reference them like a `reactive`. Good when components are recycled between projects; the `reactiveValues` pattern (`references/reactivevalues-pattern.md`) is an alternative way to manage complexity without namespacing overhead.
