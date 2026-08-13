# Reactivity in a Shiny HTA model

Reactivity is the engine of a Shiny app and the main thing to get right in a CEA front-end. The goal: inputs feel live, but the expensive model run happens only when the user asks for it, in a controlled order.

> Sources: R-HTA Ch. 14 (reactivity in HTA Shiny apps); `shiny` reference docs (`reactive()`, `observeEvent()`, `eventReactive()`, `isolate()`, `req()`). Accessed 2026-07-03.

## The four primitives

| Primitive | Returns a value? | Triggered by | Use for |
|---|---|---|---|
| `reactive()` | yes (call as `x()`) | any input it reads changes | cached intermediate calculations |
| `observe()` | no | any input it reads changes | side effects (console QC prints, UI updates) |
| `eventReactive()` | yes | a specified trigger only | a value computed on a button (the model run) |
| `observeEvent()` | no | a specified trigger only | an action on a button (commit inputs, save) |

`reactive`/`observe` recompute on *any* change to inputs they reference; `eventReactive`/`observeEvent` recompute *only* on the named trigger. The latter pair are equivalent to the former wrapped in `isolate()` on everything except the trigger.

```r
# reactive: an object recomputed whenever its inputs change
drug_costs <- reactive({
  list(
    AZT_mono   = rep(unit$AZT_mono, input$THorizon),
    lamivudine = c(rep(unit$lamivudine, 2), rep(0, input$THorizon - 2))
  )
})
# referenced downstream as drug_costs()  (note the parentheses)

# observe: side effect only, e.g. QC print of intermediate values
observe(print(input$THorizon * 5))

# eventReactive: compute only when the Run button is pressed
disc_cost <- eventReactive(input$Run_model, {
  sapply(1:parameters()$settings$THorizon,
         function(n) 1 / (1 + parameters()$settings$Dr_C)^n)
})

# observeEvent: action only when a button is pressed
observeEvent(input$save, saveRDS(reactiveValuesToList(L), "state.rds"))
```

## The central pattern: reactive up to parameters, event-gated after

The chapter's recommended architecture:

1. Inputs flow **reactively** into a central `parameters` list (so the parameters sheet shows live values and you can QC them as the user types).
2. The **expensive model run is gated behind a "Run model" button** via `eventReactive`/`observeEvent`, so the CEA computes only on demand and in a controlled order.

```r
parameters <- reactive({                  # live, recomputes as inputs change
  list(
    settings = list(THorizon = input$THorizon, Dr_C = input$Dr_C, Dr_Ly = input$Dr_Ly),
    Costs    = list(drug_costs = drug_costs(), state_costs = state_costs())
  )
})

results <- eventReactive(input$Run_model, {   # heavy run, only on button
  run_markov_model(parameters())
})

output$icer_table <- renderTable(results())   # renders when results() updates
```

## Functionality vs speed — the governing trade-off

- **Too much reactivity**: the whole CEA recomputes on every keystroke. Slow, and worse, steps can fire **out of order** — a downstream calc running before its upstream value has updated, silently using a stale/superseded value with no visible error. In cost-effectiveness modelling, prefer `eventReactive` so *you* control the order of computation.
- **Too little reactivity**: the user must press a sequence of buttons in the right order, and if dependencies are obscure the app is confusing or unusable.

Balance them: live inputs, but gate the expensive run. Within the run, **break the calculation into a chain of small reactive chunks** rather than a few monolithic blocks — small chunks can be `observe`-printed for QC, and reactivity stays monitorable (you can see what recomputes when). Large uninteractable blocks can't be QC'd.

## Start-up behaviour: ignoreNULL / ignoreInit

`eventReactive`/`observeEvent` take two arguments that control what happens at launch:
- **`ignoreNULL`** (default `TRUE`): don't fire while the trigger is `NULL`/`0` (an unpressed `actionButton` is `0`) — i.e. wait for the user. Set `FALSE` to compute once at start and let the user re-trigger (a "Recalculate" button).
- **`ignoreInit`** (default `FALSE`): by default the handler runs once when created. Set `TRUE` to suppress that initial run — useful for dynamically created buttons so the action fires only on a real click.

`actionButton` events are **not available at start-up** (the button reads `0`), so anything gated on a button won't run on launch unless you arrange it to (see the start-up reference). `numericInput`/`selectInput` values *are* available at start-up.

## Modern idiom: bindEvent

As of Shiny 1.6.0, `bindEvent()` unifies event handling: `reactive(...) |> bindEvent(input$go)` is the modern equivalent of `eventReactive(input$go, ...)`, and likewise for observers. The chapter uses the classic `eventReactive`/`observeEvent`, which remain fully supported and are clearer for most CEA code; `bindEvent` is worth knowing for newer codebases.

## reactiveVal vs reactiveValues

- `reactiveVal(0)` — a single reactive value; get with `x()`, set with `x(1)`.
- `reactiveValues(a = 1, b = 2)` — a *list* of reactive values; get `r$a`, set `r$a <- 1`. Use this when tracking many related values, and as the basis of the D/S/L/R central-data pattern (`references/reactivevalues-pattern.md`).

Both have **reference semantics** (unlike normal R copy-on-modify), which is what lets the D/S/L/R pattern move whole sub-lists by assignment.
