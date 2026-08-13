# pwexp-in-matrix mortality with state-specific SMRs (hesim 0.5.8)

Provenance: **[vignette]** = confirmed in the hesim 0.5.8 vignettes; **[EXPO 0.5.8]** = observed/resolved in the EXPO build — re-verify on upgrade. This reference covers the *mechanism*. SMR **values** and their sources live in the evidence note, never here, and are never fitted from EXPO.

## The principle

Background mortality is a **death transition inside the intensity matrix**, parameterised as piecewise-exponential (`pwexp`) with age-varying rates — **not** a survival curve multiplied on afterward. Every living state has a death edge in `tmat`; each such edge is a `pwexp` `params_surv` whose rate is `background_rate(age) × SMR(state)`.

This is the hesim-idiomatic form (the inhomogeneous-individual vignette models all four mortality edges as `pwexp` on age breakpoints). It composes correctly with `clock = "mixt"`; a post-hoc overlay does not.

## From an ONS lifetable to `log_mr`

The pwexp `coefs` are per-period **log rates** on the model-time axis. Build them from the lifetable by re-basing the age bands to model time for a given `start_age`, taking the rate active in each band, and logging. **[EXPO 0.5.8]** (mechanism; the lifetable itself is the ONS `qx`→rate table.)

```r
# ons: data.table(age, rate)  -- one-year annual mortality rate (mx) per attained age, to ~110
# start_age: scalar entry age for the axis being built
lifetable_to_pwexp <- function(ons, start_age, axis_end = 110) {
  ages   <- start_age:axis_end                 # attained ages within the horizon
  t      <- ages - start_age                    # model time (forward clock)
  rate   <- ons[match(ages, age), rate]         # rate active from each attained age on
  # collapse to breakpoints only where the rate changes (pwexp carries a rate forward):
  keep   <- c(TRUE, diff(rate) != 0)
  list(time = t[keep],                          # -> aux = list(time = ...)
       log_rate = log(rate[keep]))              # -> one 1-col ("cons") coef table per period
}

lt        <- lifetable_to_pwexp(ons, start_age = 42)   # e.g. trial mean age
log_mr    <- lt$log_rate                                # length = n breakpoints
age_breaks <- lt$time
```

`age_breaks` feeds `aux = list(time = ...)`; `log_mr` feeds `as_dt_list()` (one 1-column table per period). With heterogeneous `start_age`, build per-patient (or verify the shared axis covers the oldest attainable age — the check in `scripts/check_ctstm_build.R`). Confirm `axis_end` reaches the lifetable top and matches `$sim_disease(max_age=)`.



```r
# background lifetable rates at the breakpoints, on the LOG scale, as a per-period coef list
params_surv(coefs = as_dt_list(log_mr),          # one 1-col table ("cons") per period
            aux   = list(time = age_breaks),      # <-- see the trap below
            dist  = "pwexp")
```

`aux$time` is the vector of breakpoints at which the rate changes. For a **forward-clock, age-based** death edge these breakpoints are on the **model time axis, which for a forward clock equals time-since-start = attained-age − start_age**. In the vignette a 60-year-old uses `mr_times <- c(0, 5, 15, 25)` with rates `c(.0067, .0193, .0535, .1548)` — i.e. the ONS bands re-expressed relative to entry age. **[vignette]**

### The trap: the age axis must cover the whole horizon **[EXPO 0.5.8]**

- The breakpoints are **absolute attained age** re-based to model time, and the **last rate is carried forward** to infinity. If the breakpoint grid stops short of the oldest attainable age, the wrong (too-low) band applies at the top of the horizon — or, combined with a lifetable lookup that runs off its own index, the simulation returns **NA life-years**. The fixed-axis version failed exactly here.
- Build the axis to the **end of the lifetable (~age 110)**, re-based per `start_age`, and keep it consistent with `$sim_disease(max_age=)` (default **100** — raise it, or the axis and the truncation disagree).
- Because `start_age` varies across patients, the age→model-time re-basing is per-patient; verify the oldest patient's axis still covers age 110.

## State-specific SMRs

Each state scales the background rate by its own relative-mortality key:

```r
smr_for <- function(mortality_key, smr_tbl) {
  s <- smr_tbl[[paste0("smr_", mortality_key)]]     # e.g. smr_ontx, smr_offtx, smr_recovered,
  if (is.null(s) || !all(is.finite(s)) || any(s <= 0))  #      smr_offtx_exit4wk, smr_prison,
    stop("unresolved/invalid mortality_key: ", mortality_key)   #  smr_postrelease
  s
}
# rate scaling is multiplicative -> log-additive:
log_state_rate <- log_mr + log(smr_for(key, smr_tbl))
```

- Keys resolve by string: `paste0("smr_", key)` aligns the state's `mortality_key` to its SMR column. **[EXPO 0.5.8]**
- SMRs are **multiplicative on the rate**, so **additive on the log scale** — add `log(SMR)` to the per-period `log_mr`, per period, before building the `pwexp` coef list.
- On the all-OAT simplification, on-treatment states share one `smr_ontx` (arm-conditional cost/retention differ, but mortality does not); after the OnOther→OnTx collapse there is a single on-treatment mortality key.
- Peri-exit is a **time-in-state** elevation (first 4 weeks off), so it is either a reset death edge or an `OffTx_early` sub-state (resolve via the D4/P2b spike in `parameterisation-and-clocks.md`), not an attained-age band.

### Fail loud, not quiet **[EXPO 0.5.8]**

The dangerous default is `if (is.null(s)) 1` — an unresolved key silently applies **background** mortality (SMR = 1). That is fail-*quiet*: safe-looking, wrong, invisible. Convert it to fail-*closed* — an unresolved key makes the production gate **object** — so a mis-specified state can never ship with background mortality. This is why the resolver above `stop()`s. The tunnel/prison keys (`smr_offtx_exit4wk`, `smr_prison`, `smr_postrelease`) were exactly the keys the earlier resolver didn't surface, so fuller specs hit the quiet fallback.

## Validating the mortality spine

1. **Analytic background equivalence.** With all SMRs = 1, the simulated background survival must reproduce the closed-form pwexp survival for the lifetable. Track **RMST-relative** difference; it shrinks with `n` (EXPO: ~0.003 at 5,000; ~0.0004 at 20,000). This is the primary error-detector — a real analytic target, not a self-comparison. **[EXPO 0.5.8]**
2. **`smr = 1` recovers background**, and **state differentiation**: prototype SMRs (higher off-treatment) must *lower* cohort life-years relative to background. **[EXPO 0.5.8]**
3. **Absolute-level calibration.** The pwexp+SMR in-treatment mortality *level* should be checked against an external in-treatment mortality anchor (e.g. national deaths-in-treatment observed/expected), separately from the *relative* SMR structure — with the partial-dependence caveat (same-system aggregates are not fully independent validation).

Values are gated: the resolver and axis are built on **prototype** SMRs behind the production gate; the real SMRs + CIs wire the lognormal/`multi_normal` PSA in only after the evidence-side checks close.
