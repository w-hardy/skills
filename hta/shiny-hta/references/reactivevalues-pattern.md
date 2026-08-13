# The DSLR reactiveValues pattern for scaling a CEA

The chapter's signature contribution: a central `reactiveValues` data-management approach for cost-effectiveness models with many interdependent, dynamic inputs. It keeps the code simple and QC-able no matter how complex the model gets, and solves problems (state save/load, nested dynamic UI memory) that ad-hoc `reactive`s and Shiny bookmarking cannot.

> Sources: R-HTA Ch. 14 (the chapter's central `reactiveValues` data-management pattern for CEA apps). Accessed 2026-07-03.

## The problem it solves

A realistic HTA CEA can need *thousands* of inputs, many of them in **dynamic UIs that move in and out of existence** — e.g. "up to 10 drugs, each one of several types (flat-dosed / IV / dose-banded / pill-tracking), each type with a different input set". Two failures result from the naive approach:
- Manually writing a `reactive`/`isolate` per input gives an unmanageable codebase (tens of thousands of lines).
- When a higher-level control (e.g. "number of drugs") refreshes, the nested UI elements below it are regenerated and **lose their values** — Shiny's bookmarking can't restore nested dynamic state, because restoring the top-level input refreshes and resets the children.

## The four lists: D / S / L / R

All are `reactiveValues` (or plain lists, for `D`) sharing **identical structure**:

- **`D` — Defaults.** Every possible permutation of inputs, *including those not currently shown in the UI* (e.g. inputs for all 10 drugs even if only 3 are in play). Defined outside the server, in `global.R`.
- **`R` — Responsive.** Updates **instantly** as the user edits the UI (high priority), via one `observeEvent` per input. Holds the "uncommitted" live edits, plus heavier data (patient-level data, analysis results) that `L` doesn't need.
- **`L` — Live.** Updates **only when the user commits** a change (a button), via `L$section <- R$section`. **All UI elements render their values from `L`, never from `R`.**
- **`S` — Saved.** A snapshot for save/load. `reactiveValuesToList(L)` + `saveRDS()` writes it; reading it back and replacing `L` (and `D`) restores a previous analysis *live*, without restarting the app.

## Why render from L, never R (the infinite-loop point)

If UI elements rendered from `R` (which updates instantly), you'd get an **infinite loop**: user edits UI → server updates `R` → UI re-renders from `R` → the tiny render delay makes the server see a "change" → updates `R` again → … Rendering from `L` (which only changes on a deliberate commit) breaks the loop. Commits via buttons become intuitive **"choke points"** — the user edits freely, then commits, exactly like a well-built Excel model funnelling everything through a parameters sheet.

## Why it preserves nested dynamic-UI state

Because `D`/`R`/`L` hold **all permutations** of inputs (not just the rendered ones), a UI element that vanishes and reappears is re-rendered with its value pulled from `L` — which never fell out of existence. So changing "number of drugs" from 2 to 3 brings in drug #3's inputs already populated from `L`, and switching a drug's type swaps to a different input set that's *remembered* separately. This is the thing bookmarking can't do.

## The seven-step build (condensed)

1. **In `global.R`: define `D`** — all defaults, all permutations. For nested/interdependent elements, generate `n` sets of defaults with `lapply` inside a function so structure stays standardised.
2. **At the top of `server`: define `R` and `L` from `D`.** `reactiveValues` can't take `R <- D` directly; pass first-level elements: `R <- reactiveValues(basic = D$basic, drug = D$drug, ...)` (tip: nest everything under one element like `D$dat` so it's `reactiveValues(dat = D$dat)`). Do the same for `L`. Now model data matches defaults at launch.
3. **Generate all UI in `renderUI`, always referencing `L`** (never `R`) for `value`/`selected`/`choices`. Write dynamic UI as functions taking `n` and the relevant slice of `L`.
4. **Track every input's changes into `R` (not `L`)** with `observeEvent`:
   ```r
   observeEvent(input[[nm]], { if (!is.null(input[[nm]])) R$drug$inputs[[i]] <- input[[nm]] })
   ```
   Define these iteratively with `lapply` over input names (`paste0("MyInput_", 1:n)`) so you don't hand-write thousands.
5. **Buttons commit `R` → `L`** at chosen granularity: `L$drug <- R$drug` (all drug inputs at once), or deeper (`L$drug$inputs[[2]]$flat$n_unit_sizes <- R$...`) for fine control. These are the choke points.
6. **In the `ui`: just lay out `uiOutput`s.** All real content is server-rendered from `L`.
7. **Download/upload `L` as `.rds`** for save/load of the whole model state.

## Payoffs

- **One line moves thousands of inputs**: `L$drug <- R$drug` replaces hundreds of `isolate()`/`reactive` calls.
- **Offline debugging**: because `D`/`R`/`L` share structure, set `R <- D; L <- D` outside Shiny and step through the server logic line-by-line — neutralising Shiny's worst weakness (no line-by-line debugging) and greatly improving transparency.
- **Save/load**: clone `L` to disk and back to restore any prior state live.
- **Scales without added complexity**: the app stays "a series of functions manipulating two lists (`R` and `L`)" however complex the model.

## When NOT to use it

It's real upfront groundwork. For a simple app — a handful of inputs, no dynamic UI — a few `reactive`s are clearer and DSLR is overkill. Reach for it when the model has many interdependent inputs, dynamic UIs that change which inputs exist, or a need to save/restore state. A useful structure for the lists mirrors a conventional Excel CEA: first-level entries like `basic`, `pld`, `survival`, `drug`, `hcru`, `utility`, `results`, `psa`, `owsa`, `evpi`, each a sub-list with `inputs`/`outputs`/intermediate slots — familiar to health economists and easy to QC.
