# Implementing a DES in R with simmer

The process-based `simmer` workflow: a **trajectory** (the pathway logic) plus a **simulation environment** (who enters and what's monitored). Illustrative example mirrors the book's colon-cancer cost-utility model — individuals move through adjuvant treatment cycles, long-term follow-up, recurrence, and death, accumulating discounted costs and QALYs.

> Sources: R-HTA Ch. 12 (simmer DES; colon-cancer cost-utility example); `simmer` reference docs at <https://r-simmer.org/reference/> — `trajectory()`, `set_attribute(keys, values, mod = c(NA, "+", "*"), init = 0)`, `set_global()`, `timeout()`/`timeout_from_attribute(key)`, `branch(option, continue, ...)`, `seize()`/`release()`/`add_resource()`, `add_generator()`, `run(until = )` all confirmed current; `set_attribute(global = TRUE)` deprecation confirmed in the package changelog. Accessed 2026-07-03.

## The five trajectory building blocks

```r
library(simmer)

traj <- trajectory() %>%
  # ATTRIBUTES: per-individual numeric memory. Multiple at once; mod="+" to increment.
  set_attribute(keys   = c("TreatmentArm","BS","RFS","dCosts","dQALYs"),
                values = function() fn_initialisation()) %>%

  # TIMEOUT: delay = time to next event. timeout_from_attribute() reads a stored time.
  timeout_from_attribute(key = "FollowUpTime") %>%

  # BRANCH: fork into competing sub-trajectories. option picks the branch;
  #   continue = FALSE means the individual does NOT return to the main trajectory.
  branch(
    option   = function() get_attribute(.env = sim, keys = "FollowUpEvent"),
    continue = FALSE,
    traj_death,        # option = 1
    traj_recurrence    # option = 2
  )
```

The full set of blocks:
- **Attributes** — `set_attribute()` / `get_attribute()` (per individual), `set_global()` / `get_global()` (shared). NB `set_attribute(global=TRUE)` is **deprecated**; use `set_global()`. `mod = "+"` (or `"*"`) increments/scales rather than overwrites — how you accumulate costs/QALYs.
- **Timeouts** — `timeout(task = function() ...)` for an inline sampled delay, `timeout_from_attribute(key=)` when the time-to-event is already stored in an attribute.
- **Branches** — `branch(option, continue, ...sub-trajectories)`. `option` returns the index of the sub-trajectory to enter (or 0 to skip). The standard competing-events and decision construct. Sequential single-option branches and one multi-option branch are interchangeable.
- **Rollbacks** — `rollback(target, check)` jumps `target` activities back if `check` is TRUE; the natural way to repeat treatment cycles (loop back until max cycles reached). `target` can also be a `tag` on an earlier activity.
- **Resources** — `seize(resource)` / `release(resource)` for capacity-constrained assets (paired with `add_resource()` in the environment). Only needed for queue/capacity models; omit for standard threshold-based HTA.

Other useful trajectory verbs: `join()` to splice one trajectory into another (e.g. every path ends by joining `traj_death`), `log_()` for debug messages, and `plot()` (via `simmer.plot`) to visualise the trajectory diagram. Define sub-trajectories (`traj_death`, `traj_recurrence`) *before* the main trajectory that references them.

## Repeating events with rollback (treatment cycles)

```r
# inside the adjuvant-treatment branch, after processing one cycle:
rollback(
  target = 5,   # jump back 5 activities to the start of the cycle block
  check  = function() {
    get_attribute(.env = sim, keys = "AdjuvantCycles") < n_max_adjuvant_cycles
  }
)
```

## Competing events via "earliest time wins" (strategy 1)

The book samples a time for each competing event, stores them as attributes, then takes the minimum — robust under censoring:

```r
set_attribute(
  keys = c("FollowUpTime","FollowUpEvent"),
  values = function() {
    times <- get_attribute(.env = sim, keys = c("BS","RFS"))  # background death, recurrence
    c(FollowUpTime  = min(times) - now(.env = sim),
      FollowUpEvent = which.min(times))                       # 1 = death, 2 = recurrence
  }
)
```

## The simulation environment

```r
n_individuals <- 50000

# The trajectory hard-codes the env name `sim`, so the environment MUST be named sim.
sim <- simmer() %>%
  add_generator(
    name_prefix  = "Patient_",
    trajectory   = traj_main,
    distribution = at(rep(0, n_individuals)),  # everyone enters at t = 0 (usual for HTA)
    mon          = 2                            # 2 = monitor attributes over time
  )
  # add_resource("Nurse", capacity = 2)  # only if modelling capacity/queues

# Run once per strategy. Seed before each run for reproducibility AND common random
# numbers across strategies (reduces noise in the incremental comparison).
treatment_arm <- 0; set.seed(1); sim %>% reset() %>% run(until = Inf)
df_0 <- fn_summarise(get_mon_attributes(sim))     # last-recorded value per individual

treatment_arm <- 1; set.seed(1); sim %>% reset() %>% run(until = Inf)
df_1 <- fn_summarise(get_mon_attributes(sim))

treatment_arm <- 2; set.seed(1); sim %>% reset() %>% run(until = Inf)
df_2 <- fn_summarise(get_mon_attributes(sim))
```

`run(until = Inf)` runs each individual to their absorbing event (death). For a capped horizon use a finite `until`. The strategy is switched here via a global `treatment_arm` read inside `fn_initialisation()`; alternatively set it as a `set_global()` attribute.

## Extracting and analysing outcomes

```r
df_arrivals   <- get_mon_arrivals(sim)    # entry/exit times per individual
df_attributes <- get_mon_attributes(sim)  # full long-format log of attribute changes
# df_resources <- get_mon_resources(sim)  # utilisation/queue, if resources used

# Mean discounted costs and QALYs per strategy -> CEA
v_costs <- c(mean(df_0$dCosts), mean(df_1$dCosts), mean(df_2$dCosts))
v_effs  <- c(mean(df_0$dQALYs), mean(df_1$dQALYs), mean(df_2$dQALYs))
df_ce   <- data.frame(Costs = v_costs, Effs = v_effs,
                      Strategies = c("Obs","Lev","Lev+5FU"))

# e.g. dampack::calculate_icers() for the efficiency frontier, or feed BCEA
res <- calculate_icers(df_ce$Costs, df_ce$Effs, df_ce$Strategies)
plot(res)
```

## Internal validation tip

Record overall survival as its own attribute at death (`set_attribute("OS", values = function() now(.env = sim))`) even though it's derivable from the component event times. Cross-checking the recorded OS against `RFS`/`BS`/`CSS` is a cheap internal verification that the trajectory logic is wired correctly.

## Custom functions

Real models push most logic into custom functions (`fn_initialisation`, `fn_adjuvant_cycle`, `fn_advanced_time`, `fn_discount_QALYs`, `fn_summarise`) called from `set_attribute(values = function() ...)`. Keep these pure and testable in isolation — they're where the clinical and economic content lives, and where most bugs hide. The trajectory is the control flow; the functions are the substance.
