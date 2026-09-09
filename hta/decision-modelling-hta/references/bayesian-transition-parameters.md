# Bayesian estimation of the numbers that go into a Markov model

> Sources: *Bayesian Modelling in Health Technology Assessment* — Baio (Chapman & Hall/CRC, 2026),
> Ch. 9 (Markov models). Anchored to the companion repository
> <https://github.com/giabaio/bmhta-examples> (MIT) commit `d2a6298` (2026-08-07), file
> `09-markov-models/markov-models.R` — a four-state HIV model estimated from transition counts, a
> relative risk pooled across four published studies, and a treatment-waning curve; accessed
> 2026-09-09.

`SKILL.md` owns the model **structure**: states, the transition matrix, cycles, discounting, and the
`heemod` workflow. This file is about where the **numbers in that matrix come from** when they are
estimated rather than assumed, and how their uncertainty gets into the results. It does not
introduce a second way to build a Markov model, and there is no separate Bayesian-Markov skill —
the structure is the same either way.

## Transition probabilities from counts: Multinomial-Dirichlet

Given a state, the probabilities of moving to each destination form a **simplex**: they are
non-negative and sum to exactly 1. If you have observed transition counts — a matrix `y` where
`y[r, c]` is the number of patients who moved from state `r` to state `c` in one cycle — then row
`r` is a multinomial sample and the conjugate posterior for its probabilities is Dirichlet:

```
lambda[r, ] | y ~ Dirichlet(alpha[r, ] + y[r, ])
```

with `alpha[r, ]` the prior counts (`rep(1, S)` for a uniform prior over the simplex; smaller values
such as 0.5 or the Jeffreys 1/2 are less committal). Sampling is one line and needs no MCMC:

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

Apply it only to the **off-diagonal** cells (the transitions the treatment acts on), then restore the
row-sum constraint and the absorbing state:

```r
lambda2 <- apply_rr(lambda1, rr)
diag(lambda2) <- diag(lambda2) + (1 - rowSums(lambda2))   # diagonal absorbs the remainder
lambda2[S, ]  <- 0; lambda2[S, S] <- 1                    # death stays absorbing
stopifnot(all(lambda2 >= 0), all(abs(rowSums(lambda2) - 1) < 1e-8))
```

Putting the correction on the diagonal is the right default because the diagonal is "stay where you
are", which has no independent evidence behind it — it is a residual. Check for negative entries
afterwards regardless: a large `RR` on several transitions out of one state can drive the diagonal
below zero, which means the RR is inconsistent with the baseline matrix and needs addressing, not
clipping.

> The companion script's implementation and its own stated formula differ in the final term (one
> uses `RR`, the other `1 - RR`). The identity above is the one that reproduces `lambda2 = RR *
> lambda1`; derive it rather than copying either.

## Treatment effects from evidence synthesis

Where the relative risk comes from several published studies, pool it with a hierarchical model
rather than taking a single study or a fixed-effect average, and carry the **posterior** into the
transition matrix. In the source this is a random-effects Normal model on the log-RR across four
studies, with the pooled `exp(mu)` feeding `apply_rr()` above. For fitting that model see
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

**The heemod bridge.** `heemod`'s normal PSA path resamples parameters from named distributions in
`define_psa()`. When a parameter already has a posterior, that resampling is redundant and lossy —
you would be fitting a parametric distribution to draws you already have. `define_distribution()`
is heemod's hook for a user-supplied set of draws (see `SKILL.md`), and it is the route for an MCMC
posterior; check its signature against the installed version, since heemod's PSA helpers have moved
across releases. Where the posterior is a whole correlated transition matrix rather than a handful of
scalars, running the trace directly as above is often simpler than expressing it through heemod's
PSA machinery — and either way, the correlation between parameters from the same posterior must
survive, which independent per-parameter resampling would destroy.

Once the model produces paired cost and effect draws per strategy, hand them to
`bayesian-cea-r-hta` for the CE plane, CEAC and value of information.
