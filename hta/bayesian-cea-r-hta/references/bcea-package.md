# The BCEA package

> Source: *Bayesian Cost-Effectiveness Analysis with the R package BCEA* (Baio, Berardi &
> Heath, Springer, 2017); function signatures cross-checked against the current `BCEA` CRAN
> documentation, accessed 2026-07-03. **Argument names have drifted from the book across BCEA
> releases** — the corrections below reflect current CRAN. Always confirm against the installed
> version (`?bcea`, `packageVersion("BCEA")`) before running.

BCEA is the reference implementation of the summaries in `psa-and-summaries.md`: it takes
simulation matrices and produces the standard decision outputs with consistent conventions.
Use it when the deliverable is the standard battery (plane/CEAC/CEAF/EIB/EVPI) and you want the
book's conventions for free; use draws-native code (as this repository does) when the outputs
must integrate with an existing table/figure system — the two must agree numerically, which is
itself a useful cross-check.

## The bcea() call

```r
library(BCEA)
# current signature:
# bcea(eff, cost, ref = 1, interventions = NULL, .comparison = NULL,
#      Kmax = 50000, k = NULL, plot = FALSE)
m <- bcea(
  eff  = e_matrix,   # n_sim x n_strategies effects (QALYs), natural scale
  cost = c_matrix,   # n_sim x n_strategies costs (GBP), same row = same draw
  ref  = 2,          # column index of the intervention treated as reference
  interventions = c("SoC", "XR-BUP"),
  Kmax = 50000       # upper end of the willingness-to-pay grid
)
```

Requirements and gotchas:

- `eff`/`cost` are **per-strategy absolute** values per draw, not incrementals — BCEA forms the
  contrasts itself against `ref`. Feeding incrementals produces silently wrong multi-way output.
- Rows must be paired draws (same simulation). Columns must line up between `eff` and `cost`.
- `ref` **defaults to 1** (the first column); the example sets `ref = 2` deliberately. `ref` is
  the *intervention* whose INB is reported (BCEA's sign convention: positive EIB favours the
  reference). Getting `ref` backwards flips every plot's reading.
- Custom WTP grid: in the **`bcea()` call itself the argument is `k`** (a vector of thresholds),
  *not* `wtp` — `wtp` is deprecated at construction time. The **plotting** functions
  (`ceplane.plot`, `ceac.plot`, `eib.plot`, `evi.plot`) still take `wtp` to pick the λ they
  draw. Default grid otherwise runs `0 … Kmax`. Evaluate at the decision threshold(s) exactly
  rather than interpolating by eye.

## The object and its summaries

`summary(m, wtp = 30000)` prints expected costs/effects per strategy, EIB (expected incremental
benefit), CEAC value and EVPI at the chosen λ. Key components/functions:

| Function | Output |
|---|---|
| `ceplane.plot(m, wtp = …)` | CE plane with λ line and cloud |
| `ceac.plot(m)` | CEAC (pairwise vs `ref`) |
| `mce <- multi.ce(m)` then `ceac.plot(mce)` / `ceaf.plot(mce)` | multi-comparator CEACs and the frontier |
| `eib.plot(m)` | expected incremental benefit over λ, with break-even λ* |
| `evi.plot(m)` | per-person EVPI over λ |
| `evppi(m, param, input)` | regression-based EVPPI; `input` from `createInputs()`, needs parameter draws (calls the `voi` package internally) |
| `CEriskav(m) <- r` | risk-aversion sensitivity — a **replacement** function (also spelled `CEriskAv`), assigns a vector of risk-aversion parameters `r` onto the object |
| `struct.psa()` | structural/model-averaging PSA across candidate models |

`multi.ce()` matters whenever >2 strategies: it takes the `bcea` object and returns the
multi-comparator decision quantities that `ceac.plot`/`ceaf.plot` then render; the default
`ceac.plot(m)` on the raw object is pairwise against `ref` and overstates each option (see the
multi-comparator rules in `psa-and-summaries.md`). Note `CEriskav` is used as an assignment —
`CEriskav(m) <- r` — not a plain function call; `evppi()` expects the parameter-input object
built by `createInputs()` rather than a bare index.

## Interoperating with a draws-native pipeline

- From a brms/posterior pipeline: build `eff`/`cost` matrices by binding the per-strategy
  posterior-predictive (or g-computation) draws — one column per strategy, one row per draw,
  imputation blocks stacked.
- From `heemod`: `run_psa()` output converts via the strategy-wise cost/effect columns
  (heemod also has its own summaries; prefer one system per report).
- Cross-check: expected INB and P(INB>0) from BCEA at λ must match the hand-rolled versions to
  Monte Carlo error. If they differ, the usual suspects are `ref` orientation, incremental vs
  absolute inputs, or unpaired rows.

## When NOT to reach for BCEA

- The report already has a consistent draws-native table/figure system (this repository's
  `cu_summary()` / `incremental_results_table()`); adding BCEA duplicates conventions and
  invites sign-convention drift. Use it there only as a numerical cross-check.
- Non-QALY effect scales are fine (BCEA is agnostic), but the plots' labels/λ interpretation
  assume a QALY-like "more is better" effect — flip signs first for disutility-style outcomes.
