# hesim API gotchas (0.5.8) — walls hit and their fixes

All **[EXPO 0.5.8]** unless marked **[vignette]**. Each is a place where hesim runs but is silently wrong, or errors cryptically. Re-verify on any hesim upgrade.

## Build / parameterisation

- **`params_surv` takes no `uncertainty=` argument.** PSA lives in the rows of the `coefs` matrices. Passing `uncertainty=` is a silent no-op; the run is deterministic-looking but actually uses whatever the coef rows contain. Draw uncertainty upstream (`define_rng`/`create_params`).
- **Coefficient names must match the fitted model in a mixed list.** `create_params()` on a flexsurv fit emits the fit's names — `(Intercept)`, `armsoc`. A hand-built entry sharing those covariates but named `cons` mis-maps silently (mismatched columns → wrong linear predictor). Intercept-only standalone tables *may* use `cons` (the vignette helper does), so the trap is specifically **mixed** assemblies. **[vignette for the helper; EXPO for the mismatch]**
- **`create_IndivCtstmTrans()` accepts one transition object, not two.** No `and/or` — pass a `flexsurvreg_list` *or* a `params_surv_list`. Mixed models must be assembled into a single `params_surv_list` via `create_params()`.
- **`params_surv_list` order must follow the transition IDs in `tmat`.** A misordered list runs and silently attaches the wrong distribution to a transition. Pre-flight it.
- **`expand()` `by=` must match the fit type.** Transition-specific fits → `by = c("strategies","patients")`; a joint fit → add `"transitions"`. Wrong `by` misaligns covariates on every row. **[vignette]**
- **Non-positive-definite vcov surfaces at `create_params(uncertainty="normal")`.** That's the draw step; a non-PD fitted vcov errors there. Wire the fallback (nearest-PD / bootstrap) at that point, not downstream.

## Mortality / pwexp

- **`aux$time` is the model-time (attained-age, re-based) axis, and the last rate carries forward.** A grid that stops short of ~age 110 applies the wrong top-of-horizon band or returns **NA** life-years. Build the axis to the lifetable end, per `start_age`.
- **`$sim_disease(max_age=)` defaults to 100.** Individuals are truncated at 100 unless raised; keep it consistent with the mortality age axis or the two disagree. **[vignette default]**
- **Composite rates add on the natural scale.** `log(rate_a + rate_b)`, not `log(rate_a) + log(rate_b)` (the latter multiplies). SMRs *are* multiplicative → they add on the log scale. Mixing these up is a common, invisible error.
- **Fail-quiet mortality-key resolver.** `if (is.null(s)) 1` silently applies background mortality to any unresolved state. Convert to fail-closed (`stop()` / gate objects) so a mis-keyed state can't ship as background.

## Simulation metrics / validation

- **Average the survival metric over arms; don't sum.** Summing across arms double-counts and yields a spurious `max|Δ| = 1.0` — a red herring, not a real discrepancy. The equivalence metric must average.
- **INMB precision comes from `n_individuals`, not within-call CRN.** Measured on 0.5.8 (diag-crn-pairing.R): within one seeded `$sim_disease()` call the arms' individual-level noise is UNCORRELATED (r ≈ 0.03; paired/unpaired SD ratio 0.895) — identical per-draw seeding gives reproducibility, not variance cancellation. Size `n_individuals` via the INMB MC-SE convergence check; a true-CRN design needs per-strategy re-seeded calls (see `psa-cea-and-validation.md` §2).
- **`uncertainty = "none"` is for diagnostics only.** It gives a point-estimate model — correct for hazard-shape checks and analytic equivalence, biased as a reported base case.

## Discounting / CEA

- **Discount rate is set at `$sim_qalys(dr=)`/`$sim_costs(dr=)`, not at `cea()`.** On a `ce` object, `cea()`/`cea_pw()` then *select* among the simulated `dr` values with `dr_qalys=`/`dr_costs=`; they don't apply discounting. Expecting to discount at the CEA step yields undiscounted results. **[vignette]**
- **`cea()` vs `cea_pw()` column identification differs by input.** On a `ce` object the columns are known; on a raw `data.table` you must name `sample=`,`strategy=`,`grp=`,`e=`,`c=` as strings. **[vignette]**

## Engineering hygiene (transferable, not hesim-specific)

- **Load-order fragility.** A stale build stub shadowed only because the real definition is `source()`d last is harmless until the order changes. Remove shadowed stubs when convenient rather than relying on source order.
- **Notebook load chunks must source the engine files.** A preview that "can't find `<fn>`" is usually an un-sourced dependency masquerading as an API error — check the load order before assuming a hesim bug.
