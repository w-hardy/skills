# Cohort Markov models in heemod

> Sources: *R for Health Technology Assessment* (Baio et al.) Ch. 9 (cohort Markov models) —
> rate↔probability conversion `p = 1 − exp(−r·t)` / `r = −log(1 − p)/t` per §9.3.2;
> exhaustive/mutually-exclusive states, rows-sum-to-1 and absorbing-state constraints per §9.3;
> probabilistic analysis as base case per §9.6. heemod signatures per the CRAN reference manual
> (incl. `compute_surv(x, time, cycle_length = 1, type = c("prob", "survival"))` and
> `define_surv_dist()`). Accessed 2026-07-03. The book hand-rolls these models in base R;
> the heemod implementation here is this skill's deliberate choice (see SKILL.md).

Worked patterns for time-homogeneous, time-inhomogeneous (survival-derived transitions), and probabilistic Markov models, following the heemod workflow: `define_parameters()` → `define_transition()` → `define_state()` → `define_strategy()` → `run_model()`.

Illustrative example throughout: a 4-state irreversible disease model — Stable, Progressed, Dead (disease-specific), Dead (other-cause) — comparing "Standard care" vs "New treatment". Swap in real state names/values for the actual application; the code shape stays the same.

## Time-homogeneous model

Transition probabilities constant across cycles.

```r
library(heemod)

par_homog <- define_parameters(
  p_progress_std = 0.12,
  p_progress_new = 0.07,
  p_dcause_stable  = 0.02,
  p_dcause_prog    = 0.18,
  p_other          = 0.015     # same for both arms, both non-dead states
)

trans_std <- define_transition(
  state_names = c("Stable", "Progressed", "Dead_disease", "Dead_other"),
  C, p_progress_std, p_dcause_stable, p_other,
  0, C,               p_dcause_prog,  p_other,
  0, 0,               1,              0,
  0, 0,               0,              1
)

trans_new <- define_transition(
  state_names = c("Stable", "Progressed", "Dead_disease", "Dead_other"),
  C, p_progress_new, p_dcause_stable, p_other,
  0, C,               p_dcause_prog,  p_other,
  0, 0,               1,              0,
  0, 0,               0,              1
)

s_stable <- define_state(cost = 1200, utility = 0.85)
s_prog   <- define_state(cost = 6500, utility = 0.60)
s_dd     <- define_state(cost = 0,    utility = 0)
s_do     <- define_state(cost = 0,    utility = 0)

strat_std <- define_strategy(transition = trans_std,
  Stable = s_stable, Progressed = s_prog, Dead_disease = s_dd, Dead_other = s_do)
strat_new <- define_strategy(transition = trans_new,
  Stable = s_stable, Progressed = s_prog, Dead_disease = s_dd, Dead_other = s_do)

res_homog <- run_model(
  std = strat_std, new = strat_new,
  parameters = par_homog,
  cycles = 40,
  cost = cost, effect = utility,
  init = c(1, 0, 0, 0),
  method = "life-table"   # applies half-cycle-style correction
)

summary(res_homog)
```

## Time-inhomogeneous model: transitions that depend on `model_time`

Two common sources of time-dependency: age-related background mortality, and a fitted survival model for disease-specific transitions (e.g. from `flexsurv`).

**Option A — let heemod derive transition probabilities from a fitted survival model.** If progression-free survival was fit with `flexsurv::flexsurvreg()`, `compute_surv()` converts it to the conditional cycle-to-cycle transition probability, evaluated at each `model_time`:

```r
library(flexsurv)
fit_progression <- flexsurvreg(Surv(time, status) ~ 1, data = trial_data,
                                dist = "gompertz")

par_inhomog <- define_parameters(
  # type = "prob" returns the conditional probability of the event during the
  # cycle (not the survival probability); cycle_length matches the model cycle
  p_progress_std = compute_surv(fit_progression, time = model_time,
                                 cycle_length = 1, type = "prob"),
  p_dcause_stable  = 0.02,
  p_dcause_prog    = 0.18,
  p_other          = 0.015
)
```

`compute_surv(..., type = "prob")` is the heemod equivalent of manually computing `1 - exp(-(H(t) - H(t-1)))`, and is worth using whenever the survival model is one heemod/flexsurv supports, since it removes a manual conversion step that's easy to get off-by-one on. (To wrap a parametric form you specify by hand rather than a fitted object, build it with `define_surv_dist()` first and pass that to `compute_surv()`.)

**Option B — manual hazard conversion**, needed for anything heemod's survival objects don't cover (mixture cure models, custom hazard functions):

```r
H <- function(t) flexsurv::Hgompertz(t, shape = fit_progression$res["shape", "est"],
                                      rate  = fit_progression$res["rate", "est"])

par_inhomog <- define_parameters(
  p_progress_std = 1 - exp(-(H(model_time) - H(model_time - 1)))
)
```

Either way, `model_time` is the only thing that needs to appear in the parameter expression for heemod to treat the resulting transition as time-varying — there's no separate "time-inhomogeneous mode" to switch on.

## Making it probabilistic

Re-specify the relevant parameters with resampling distributions, then `run_psa()`.

Distributions are written as **formulas** inside `define_psa()`, using heemod's
own density functions. **Mind the parameterisations — they are not all
`(mean, sd)`:**

| Quantity | heemod call | Parameterisation |
|---|---|---|
| Cost (right-skewed, ≥0) | `gamma(mean, sd)` | mean and sd directly |
| Utility / QALY | `normal(mean, sd)` | mean and sd directly |
| Single transition probability | `binomial(prob, size)` | point prob + effective sample size |
| Probability via Beta | `beta(shape1, shape2)` | **shape parameters, NOT mean/sd** |
| Split of one state's outflow across several destinations | `multinomial(...)` | counts (Dirichlet conjugate) |
| Hazard / rate / odds ratio | `lognormal(mean, sd, meanlog, sdlog)` | either natural-scale `mean, sd` or log-scale `meanlog, sdlog` |

```r
rsp <- define_psa(
  # transition probabilities: binomial with an effective denominator is the
  # idiomatic heemod choice; size = the n that informed the point estimate
  p_progress_std ~ binomial(prob = 0.12, size = 400),
  p_progress_new ~ binomial(prob = 0.07, size = 400),
  p_dcause_stable ~ binomial(prob = 0.02, size = 400),
  p_dcause_prog   ~ binomial(prob = 0.18, size = 250),
  # costs: gamma takes mean and sd directly
  cost_stable     ~ gamma(mean = 1200, sd = 200),
  cost_prog       ~ gamma(mean = 6500, sd = 900)
)

psa_res <- run_psa(res_homog, psa = rsp, N = 1000)

summary(psa_res)
plot(psa_res, type = "ce")        # cost-effectiveness plane
```

Two important gotchas confirmed from the heemod docs:
- `beta()` takes **`shape1, shape2`**, not `mean`/`sd`. If you only have a mean and sd for a probability, either convert to shapes via method of moments first, or just use `binomial(prob, size)` instead, which takes the point estimate directly.
- The several outgoing probabilities from a single state are not independent (they must keep summing to ≤1). Where a state splits its outflow across multiple destinations, prefer a single `multinomial(...)` over several independent `binomial`/`beta` draws, so the simplex constraint is respected.

If two or more parameters came from the same regression (e.g. correlated log-rate and log-rate-ratio from one survival fit), build a correlation structure with `define_correlation()` and pass it as the `correlation =` argument of `define_psa()` (it also accepts a raw correlation matrix). Independence is the default and understates joint uncertainty when parameters are actually correlated.

## Sanity checks before trusting the output

- `summary()` on the transition object (or the validator script) confirms every row sums to 1 across the full cycle range, not just at cycle 1 — a time-inhomogeneous matrix can drift out of bounds at late cycles if a hazard-to-probability conversion wasn't capped.
- Check the Markov trace (`get_counts()` or `plot(res, type = "counts")`) against clinical face validity the same way the book does by hand — does the cohort end up almost entirely in the dead states by the end of the time horizon, at a rate that matches expectations for the disease?
- For an irreversible model (no recovery), confirm the "recovery" cells really are `0` and not accidentally parameterised — a stray nonzero recovery probability is a common copy-paste error when adapting a remission/relapse template to an irreversible disease.
