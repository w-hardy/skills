# Bayesian estimation of the numbers that go into a Markov model

> Sources: *Bayesian Models in Health Technology Assessment* — Baio (CRC Press, published 7 August
> 2026), §9.2 (Examples 9.2-9.3), read and verified against the online edition
> <https://gianluca.statistica.it/books/online/bmhta/> on 2026-09-09. §9.2.1 gives the
> Multinomial-Dirichlet transitions (Eqs 9.4-9.6), the pooled relative risk and the waning curve;
> §9.2.2 the rescaling algebra (Eqs 9.8-9.11); §9.2.3 the per-draw trace. The worked example is the
> four-state HIV model of Chancellor et al. (1997): transition counts in the ZDV arm, a relative risk
> pooled across four published studies, and a Weibull treatment-waning curve fitted to pseudo-counts.
> Companion code: <https://github.com/giabaio/bmhta-examples> (MIT) commit `d2a6298` (2026-08-07),
> `09-markov-models/markov-models.R`.
>
> §9.3 of the same chapter covers the three-state cancer model and partitioned survival analysis;
> that material is owned by `survival-analysis-hta`, `multistate-models-hta` and the TSD 19 reference
> in `nice-economic-evaluation`, and is deliberately not duplicated here.

`SKILL.md` owns the model **structure**: states, the transition matrix, cycles, discounting, and the
`heemod` workflow. This file is about where the **numbers in that matrix come from** when they are
estimated rather than assumed, and how their uncertainty gets into the results. It does not
introduce a second way to build a Markov model, and there is no separate Bayesian-Markov skill —
the structure is the same either way.

Almost all of it is **engine-independent**. A Dirichlet posterior over a transition matrix, a
relative risk applied without producing an impossible probability, and a trace propagated per draw
are facts about the parameters, not about the package that consumes them — so they apply to any
discrete-time **cohort** transition matrix, hand-rolled or packaged. The relative-risk identity
applies to any bounded probability parameter, and per-draw propagation to any engine. Only the
final section is heemod-specific.

Mind the boundary with continuous-time models. A row-simplex Dirichlet describes a matrix of
one-cycle transition *probabilities*; an individual-level continuous-time model
(`hesim-ctstm-hta`, `multistate-models-hta`) is parameterised by transition *intensities* fitted as
survival models, where there is no row simplex to be conjugate to. The Dirichlet material can still
inform an upstream parameter such as a starting-state distribution, but it does not transfer to an
`IndivCtstm`'s transition mechanism.

## Transition probabilities from counts: Multinomial-Dirichlet

Given a state, the probabilities of moving to each destination form a **simplex**: they are
non-negative and sum to exactly 1. If you have observed transition counts — a matrix `y` where
`y[r, c]` is the number of patients who moved from state `r` to state `c` in one cycle — then row
`r` is a multinomial sample and the conjugate posterior for its probabilities is Dirichlet:

```
lambda[r, ] | y ~ Dirichlet(alpha[r, ] + y[r, ])
```

with `alpha[r, ]` the prior counts (`rep(1, S)` for a uniform prior over the simplex; smaller values
such as 0.5 or the Jeffreys 1/2 are less committal). The source uses a flat scale of **3** on every
admissible cell, which it calls reasonably vague given cell counts in the hundreds, and recommends
checking sensitivity to that choice — with row counts that large the prior scale barely matters, but
say which you used and test it when any row is sparse. Sampling is one line and needs no MCMC:

```r
# one posterior draw of the full transition matrix
draw_matrix <- function(y, alpha) {
  t(apply(y + alpha, 1, \(a) { g <- rgamma(length(a), shape = a, rate = 1); g / sum(g) }))
}
```

Set inadmissible transitions (backwards progression, anything out of an absorbing state) to a count
of zero **and** a prior of zero so they stay at zero in every draw.

**Why not a Beta per cell.** The obvious PSA shortcut — give each transition probability its own Beta
and draw them independently — is wrong in three compounding ways:

1. **The rows will not sum to 1.** Independent draws have no simplex constraint, so every draw needs
   a fudge (renormalise, or force the complement into one cell). Renormalising silently changes the
   marginal distribution you thought you specified; forcing the complement dumps all the error into
   whichever cell you chose, which then has a distribution nobody intended and can go negative.
2. **The correlations are wrong, not just absent.** Within a row the probabilities are *negatively*
   correlated by construction — a draw with more progression must have less staying put. Independent
   Betas assert zero correlation, which overstates the joint uncertainty in some directions and
   understates it in others. The Dirichlet has that structure built in.
3. **The information is not shared.** Cells in the same row come from the same denominator, so their
   precisions are linked. Independent Betas need that denominator supplied by hand per cell, and it
   is easy to give a cell a sample size the data never supported.

`SKILL.md` already gives the heemod-side rule — use `multinomial(...)` in `define_psa()` rather than
independent draws. This file is the estimation side of the same point: where the data are transition
counts, the Dirichlet posterior *is* the distribution to resample from, and it is available in
closed form.

## Applying a relative risk to a transition matrix

The common HTA pattern: baseline transition probabilities come from an observational cohort, and the
treatment effect arrives from the literature as a relative risk. Multiplying naively —
`lambda2 = RR * lambda1` — can push a probability above 1, and then row-normalising hides it.

Do it on the logit scale, which is an **exact algebraic identity**, not an approximation:

```
logit(lambda2) = logit(lambda1) + log(RR) + log(1 - lambda1) - log(1 - RR * lambda1)
```

Back-transforming with the inverse logit reproduces `lambda2 = RR * lambda1` exactly, but has two
practical virtues. The inverse logit **cannot return a value outside (0, 1)**, so no downstream
clipping is needed. And when `RR * lambda1 >= 1` — the case where the multiplication was never going
to be valid — the final term takes the log of a non-positive number and yields `NaN`, so the problem
surfaces loudly instead of being normalised away.

```r
logit  <- function(p) log(p / (1 - p))
ilogit <- function(x) 1 / (1 + exp(-x))

apply_rr <- function(lambda1, rr) {
  ilogit(logit(lambda1) + log(rr) + log(1 - lambda1) - log(1 - rr * lambda1))
}
```

Apply it to the transitions the relative risk actually describes — **named explicitly, cell by
cell** — then rebuild the diagonal as that row's complement:

```r
treated <- rbind(c(1, 2), c(2, 3))                        # the cells the pooled RR describes
lambda2 <- lambda1
lambda2[treated] <- apply_rr(lambda1[treated], rr)
stopifnot(!any(is.nan(lambda2[treated])))                 # rr * lambda1 >= 1 surfaces here
diag(lambda2) <- 0
diag(lambda2) <- 1 - rowSums(lambda2)                     # diagonal is the residual
lambda2[S, ]  <- 0; lambda2[S, S] <- 1                    # death stays absorbing
stopifnot(isTRUE(all(lambda2 >= 0)), isTRUE(all(abs(rowSums(lambda2) - 1) < 1e-8)))
```

Three things this gets right that `apply_rr(lambda1, rr)` on the whole matrix does not — all checked
by execution on the Chancellor matrix. **One RR does not describe every transition:** row `A` exits
to `B`, `C` and `D`, and a pooled progression RR describes `A → B`, not other-cause death `A → D`;
rescaling every off-diagonal cell applies the treatment effect to transitions no study measured.
**The identity is undefined off those cells:** on the absorbing row the whole-matrix call evaluates
`log(1 - rr * 1)` and returns `NaN` — with a warning when `rr > 1`, and with **no warning at all**
for the commoner protective `rr < 1`, where it arrives as `logit(1) - log(0)` = `Inf - Inf`. It
survives solely because the next line
overwrites row `S` by hand — after which a bare `stopifnot(all(...))` *passes* on a matrix that held
`NaN`. **The `RR ≤ 1/p1` bound belongs to the treated cells:** read off the diagonal instead it
becomes `RR ≤ 1/0.7211 = 1.39` rather than `1/0.3564 = 2.81`, so any `rr` in between turns an
admissible effect into a `NaN` diagonal and a false transportability alarm.

Putting the correction on the diagonal is the right default because the diagonal is "stay where you
are", which has no independent evidence behind it — it is a residual. (Where the baseline rows sum
to 1 and nothing goes `NaN`, `diag + (1 - rowSums)` after a whole-matrix rescale returns the same
numbers as the complement above; the difference is where it fails, not what it computes.) Check for
negative entries regardless: a large `RR` on several transitions out of one state can drive the diagonal
below zero, which means the RR is inconsistent with the baseline matrix and needs addressing, not
clipping. The source reads this failure substantively rather than numerically: `RR ≤ 1/p1` is forced
by the algebra (Eq 9.9), so a violation says the pooled RR's source populations are **not
exchangeable** with the population your baseline matrix describes — a transportability problem, not
a rounding one. It recommends keeping `which(lambda2 < 0, arr.ind = TRUE)` in the workflow as a
standing check on the whole draws × cycles × states array. Wrap any `all()` that could meet a `NaN`
in `isTRUE()`: `all(NA)` is `NA`, which an `if()` cannot branch on, so the guard fails closed
instead of erroring on the wrong thing — the same idiom `heemod-markov-models.md` uses in its
embeddability check. It does not improve `stopifnot()`'s message, which is uninformative either way;
the `is.nan()` check above the block is what names the actual problem.

> **A slip in the source, worth knowing before you copy it.** The book states this identity
> correctly (Eq 9.10, derived via the odds ratio the RR implies), but the R code implementing it in
> §9.2.3 computes the final term as `log(1 - lambda1 * (1 - rho.star))` — `1 − lambda1(1 − RR)` where
> the equation says `1 − RR·lambda1`. The printed equation is the correct one: it is what reproduces
> `lambda2 = RR * lambda1` to machine precision. The code form does not: on the Chancellor
> off-diagonals it is out by up to 0.0012 at the book's own `RR ≈ 0.509`, and by 0.14 at `RR = 1.2`.
> Derive it rather than copying either.

## Treatment effects from evidence synthesis

Where the relative risk comes from several published studies, pool it with a hierarchical model
rather than taking a single study or a fixed-effect average, and carry the **posterior** into the
transition matrix. In the source this is a random-effects Normal model on the log-RR across four
studies, with the pooled `exp(mu)` feeding `apply_rr()` above. Where the studies report a relative
risk and a 95% interval rather than a standard error, it recovers the likelihood's scale as
`sd = (log(upper) - log(lower)) / (2 * 1.96)`. For fitting that model see
`brms-modelling`'s `references/model-families/meta-analysis.md`; for a network of more than two
treatments see `network-meta-analysis-hta`.

Two things to get right at the hand-off:

- **Feed the draws, not the point estimate.** The whole reason to pool Bayesianly is that the
  posterior for the RR is the uncertainty; collapsing it to a mean before it reaches the matrix
  discards exactly what PSA is meant to represent.
- **Decide between the pooled effect and the predictive distribution, and say which.** The pooled
  `mu` is the average effect across the studies observed; the predictive distribution for a *new*
  exchangeable study is wider, because it adds the between-study heterogeneity. For a decision about
  a population not identical to any trial's, the predictive distribution is usually the more honest
  input, and it is materially wider whenever heterogeneity is non-trivial.

**Treatment-effect waning** can be given the same treatment: model the proportion still benefiting as
a survival curve over cycles (the source uses a Weibull fitted to pseudo-counts encoding expert
assumptions), and let the per-cycle RR move toward 1 along that curve. This makes waning a
parameter with a posterior rather than a deterministic scenario — though scenarios remain the right
presentation for a committee, since the waning assumption is a structural choice, not something the
trial data identify. `survival-analysis-hta` covers the curve-fitting side.

## Propagating the posterior through the model

Once the transition matrix is a set of posterior draws rather than a point estimate, run the trace
**per draw** and keep every draw to the end:

```r
# m[i, j, ] : occupancy at cycle j under draw i
for (i in seq_len(n_draws)) {
  m[i, 1, ] <- start_state
  for (j in 2:(n_cycles + 1)) m[i, j, ] <- m[i, j - 1, ] %*% lambda[i, , ]
}
```

Everything downstream — life-years, discounted costs, the incremental results — is then computed
within a draw and summarised only at the very end. The rules are the same as everywhere else in this
repository: do not average the matrix and then run the model once, and do not summarise the trace
before computing costs, because both collapse the uncertainty you built the model to represent.

`dplyr` handles the discounting cleanly once costs are in a per-draw, per-cycle frame:

```r
costs |> mutate(across(starts_with("c_"), ~ .x / (1 + d)^cycle))
```

**The heemod bridge** (the one engine-specific part of this file). `heemod`'s normal PSA path
resamples parameters from named distributions in `define_psa()`. When a parameter already has a
posterior, that resampling is redundant and lossy — you would be fitting a parametric distribution
to draws you already have. Two functions are involved and they are not interchangeable (heemod
1.1.0, executed):

- `use_distribution(draws, smooth = TRUE)` takes a **numeric vector of observations** — "usually the
  output from an MCMC fit", in its own help page — and builds an empirical quantile function from
  it. This is the route for a posterior.
- `define_distribution(f)` takes a **user-supplied quantile function** `f(x)`, with `x` a vector of
  quantiles in `(0, 1)`. Handed a vector of draws it returns quietly — it is literally
  `function(x) list(x)` — and the failure surfaces one level up, at `define_psa()`:
  `Distributions must be defined as functions.` `use_distribution()` is a thin wrapper around it.

Neither preserves joint dependence, and the loss is silent. `use_distribution()` **sorts** its
input, so the row-wise pairing between two parameters from one posterior is destroyed before
`run_psa()` starts; `run_psa()` then draws one Gaussian copula per replicate
(`pnorm(mvnfast::rmvn(sigma = psa$correlation))`) and applies each parameter's quantile function to
its own column, with `psa$correlation` defaulting to the identity. Four cases, of which only two
have an exact heemod route:

1. **One scalar posterior** — `param ~ use_distribution(draws)`. The default `smooth = TRUE` adds
   `N(0, bw)` kernel noise, inflating the variance by `bw^2` (1.9% on the SD of a 2,000-draw Normal
   posterior); pass `smooth = FALSE` when that matters.
2. **Several genuinely independent posteriors** — one `use_distribution()` per parameter, which is
   exactly what heemod assumes by default.
3. **Several correlated parameters from one posterior** — no heemod mechanism reproduces the
   empirical joint. Measured: two parameters correlating at **0.90** in the posterior, supplied as
   two `use_distribution()` calls, come back out of `run_psa()` correlating at **≈ 0** (measured
   -0.01, with a Monte Carlo SD around 0.02 at `N = 4,000` — the target is exactly zero). Adding
   `correlation = define_correlation(a, b, 0.9)` recovers **0.90** with `smooth = FALSE`, and about
   0.87 with the default smoothing of case 1 — but either way that is a Gaussian copula fitted to
   one number, not the posterior's dependence. Where the marginals plus one correlation is
   not an adequate summary, run the trace per draw as above.
4. **A whole transition-matrix row** — `p1 + p2 + p3 ~ multinomial(a1, a2, a3)` *is* exact. heemod
   draws `qgamma(u, shape = a_k)` per component and divides by the row total, which is a Dirichlet
   by construction, so with `a_k = prior + counts` it is the Multinomial-Dirichlet posterior of that
   row itself — verified against the closed-form Dirichlet mean, SD and pairwise correlation to
   Monte Carlo error at 200,000 draws. Put **every** destination of the row through the multinomial,
   the diagonal included, and write all of them into the matrix. List only the off-diagonals and
   leave `C` on the diagonal and the listed components already sum to 1, so `C` collapses to zero
   and heemod stops with `Some transition probabilities are outside the interval [0 - 1]`. Writing
   the diagonal as `C` while its component is still declared works but buys nothing; leaving that
   component out of `define_parameters()` makes heemod drop it and abort with
   `mu.n_elem != sigma.n_cols`.

Beyond a single row — several rows plus a treatment effect and costs out of one fit — run the trace
directly as above. It is shorter than the heemod detour and its dependence is the posterior's own.

Once the model produces paired cost and effect draws per strategy, hand them to
`bayesian-cea-r-hta` for the CE plane, CEAC and value of information.
