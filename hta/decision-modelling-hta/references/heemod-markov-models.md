# Cohort Markov models in heemod

> Sources: *R for Health Technology Assessment* (Baio et al.) Ch. 9 (cohort Markov models) —
> rate↔probability conversion `p = 1 − exp(−r·t)` / `r = −log(1 − p)/t` per §9.3.2;
> exhaustive/mutually-exclusive states, rows-sum-to-1 and absorbing-state constraints per §9.3;
> probabilistic analysis as base case per §9.6. heemod signatures per the CRAN reference manual
> (incl. `compute_surv(x, time, cycle_length = 1, type = c("prob", "survival"))` and
> `define_surv_dist()`). Accessed 2026-07-03. The book hand-rolls these models in base R;
> the heemod implementation here is this skill's deliberate choice (see SKILL.md).
>
> The Bayesian transition-parameter material this file points to is from *Bayesian Models in Health
> Technology Assessment* — Baio (CRC Press, 2026), online edition
> <https://gianluca.statistica.it/books/online/bmhta/>, verified 2026-09-09 — §9.2; see
> `bayesian-transition-parameters.md`.

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

## Competing exits convert only jointly, in both directions

Both options above give the probability of **one** event out of a state with **one** exit. Both
*transient* states in the matrix above have several — `Stable` leaves to `Progressed`,
`Dead_disease` and `Dead_other` in the same cycle, and `Progressed` to two causes of death — and
that changes the conversion in each direction. (`Dead_disease` and `Dead_other` are absorbing, so
they convert either way trivially.)

**Hazards → probabilities.** Do not fit each exit's survival independently and put `1 -
exp(-ΔH_k)` in each cell. That treats the competing events as independent, and the cells can sum
past 1. heemod catches that one loudly — `heemod:::check_matrix()` runs inside `run_model()` and on
every `run_psa()` draw, and stops with `Some transition probabilities are outside the interval
[0 - 1]` once `C` goes negative (heemod 1.1.0, executed) — but it stops the run rather than telling
you which conversion was wrong. Split the *total* exit
probability in proportion to the cause-specific cumulative-hazard increments `ΔH_j = H_j(t) −
H_j(t−1)`:

```
p_k = (ΔH_k / Σ_j ΔH_j) · (1 − exp(−Σ_j ΔH_j))
```

`survival-analysis-hta`'s `references/survival-to-economic-model.md` owns this formula — read it
there for the derivation, the condition under which the split is exact (cause-specific hazards
constant within the cycle, or more generally holding a fixed ratio to one another across it), the
size and direction of the error when they do not, and the criteria for handing the problem to
`multistate-models-hta` instead. Do not restate the derivation here; a second copy of the maths
will drift from the first.

**Probabilities → rates.** The book's `r = −log(1 − p)/t` (§9.3.2) inverts `p = 1 − exp(−r·t)`
**only for a state with a single exit**. Where several exits compete, the per-cycle probability
matrix `P` and the rate (transition-intensity) matrix `Q` — off-diagonals the cause-specific
rates, rows summing to zero — are related jointly through the matrix exponential, `P =
expm::expm(Q * t)`, and there is **no valid edge-by-edge inverse**. Converting each cell with
`−log(1 − p_rs)/t` and summing (or renormalising) is not the inverse of that embedding, for two
reasons that act in different directions and have no reason to cancel. First, ignoring competition
understates a rate: the probability that the *first* exit in the interval is via cause k is the
split above — exact here, because a constant `Q` holds the cause-specific hazards in fixed ratio —
and it sits strictly below `1 − exp(−r_k·t)` whenever anything else can happen. Second, `p_rs` in
`P` is not a count of direct r → s transitions at all — it is an *occupancy* probability, so it
adds everyone who arrived via r → x → s and removes everyone who has left s again before the
interval ends (the point `multistate-models-hta` makes about `Exp(uQ)`'s off-diagonals). Which
effect wins is cell-specific, so the naive inverse has no reliable sign. Treating the numbers in
the matrix above as annual rates and embedding them properly, the naive inverse returns `Stable →
Dead_disease` **43% too high** (0.0285 against a true 0.020 — a third of that cell is arrival via
`Progressed`, not direct disease death from `Stable`) and `Stable → Progressed` **12% too low**
(0.1062 against 0.120, because `Progressed` is itself left within the year). This is a live bug,
not a theoretical one, and it runs cleanly: the giveaway is that the recovered rates, put back
through `expm(Q * t)`, do not reproduce the matrix you started from (max cell error 0.011 on that
example) — a two-line check worth running whenever you invert a published matrix.

The joint inverse is the matrix logarithm, `Q <- expm::logm(P) / t`. It can legitimately fail,
because not every probability matrix is the `t`-step marginal of a time-homogeneous
continuous-time chain — the embeddability problem. Failure does not arrive as an error, and the
round-trip check above does not catch it. With `expm`'s default `Higham08` method (checked against
expm 1.0.1), a `P` with a negative real eigenvalue returns a matrix of `NaN` with a warning, while
a merely non-embeddable `P` returns a clean real `Q` whose rows sum to zero and which reproduces
`P` through `expm()` to machine precision — but with **negative off-diagonal entries**. The sign
check is what catches it:

```r
Q <- expm::logm(P) / t
stopifnot(
  # isTRUE(): a NaN comparison gives NA, and all(NA) is NA, not FALSE
  isTRUE(all(Q[row(Q) != col(Q)] >= 0)),
  isTRUE(all(abs(rowSums(Q)) < 1e-8))
)
```

Read a failure substantively — the published matrix is not consistent with any constant-rate
process at that interval — rather than clipping the negatives away. Where rates are what you
actually have, keep them as rates and build in continuous time (`multistate-models-hta`,
`hesim-ctstm-hta`) rather than round-tripping through a probability matrix. (For the forward
direction from a fitted `msm` object, `pmatrix.msm()` is the packaged route — see
`multistate-models-hta`.)

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
- `beta()` takes **`shape1, shape2`**, not `mean`/`sd`. If you only have a mean and sd for a
probability, either convert to shapes via method of moments first, or just use `binomial(prob,
size)` instead, which takes the point estimate directly. The method-of-moments conversion, for a
mean `mu` and SD `sigma` with `sigma^2 < mu*(1-mu)`:

  ```r
  beta_shapes <- function(mu, sigma) {
    k <- mu * (1 - mu) / sigma^2 - 1
    if (k <= 0) stop("sigma is too large for a Beta with this mean")
    c(shape1 = mu * k, shape2 = (1 - mu) * k)
  }
  ```

  The guard matters: a Beta cannot have an SD at or above `sqrt(mu*(1-mu))`, and a mean/SD pair
  lifted from a paper often violates it — which is a sign the reported SD is not describing a Beta,
  not a reason to fudge the shapes.
- The several outgoing probabilities from a single state are not independent (they must keep
summing to ≤1). Where a state splits its outflow across multiple destinations, prefer a single
`multinomial(...)` over several independent `binomial`/`beta` draws, so the simplex constraint is
respected.

If two or more parameters came from the same regression (e.g. correlated log-rate and log-rate-ratio from one survival fit), build a correlation structure with `define_correlation()` and pass it as the `correlation =` argument of `define_psa()` (it also accepts a raw correlation matrix). Independence is the default and understates joint uncertainty when parameters are actually correlated.

## Sanity checks before trusting the output

- `summary()` on the transition object (or the validator script) confirms every row sums to 1 across the full cycle range, not just at cycle 1 — a time-inhomogeneous matrix can drift out of bounds at late cycles if a hazard-to-probability conversion wasn't capped.
- Check the Markov trace (`get_counts()` or `plot(res, type = "counts")`) against clinical face validity the same way the book does by hand — does the cohort end up almost entirely in the dead states by the end of the time horizon, at a rate that matches expectations for the disease?
- For an irreversible model (no recovery), confirm the "recovery" cells really are `0` and not accidentally parameterised — a stray nonzero recovery probability is a common copy-paste error when adapting a remission/relapse template to an irreversible disease.
