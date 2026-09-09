# Bayesian NMA with multinma

Full workflow for a Bayesian NMA in `multinma` (Stan-backed). Illustrative example: a binary outcome (events `r` out of `n` per arm) — surgical-site-infection prevention, reference treatment "nonantibacterial", arm-level (aggregate) data in long format (one row per study arm).

> Sources: R-HTA Ch. 10 (surgical-site-infection example, Bayesian NMA via multinma); `multinma`
> pkgdown docs (`set_agd_arm()`, `set_agd_contrast()`, `set_ipd()`, `combine_network()`, `nma()`,
> `relative_effects()`, `predict()` confirmed). Accessed 2026-07-03.
>
> The heterogeneity-prior ladder is from *Bayesian Models in Health Technology Assessment* — Baio
> (CRC Press, 2026), online edition <https://gianluca.statistica.it/books/online/bmhta/>, verified
> 2026-09-09 — §6.2.5, which recommends PC priors as a default
> and half-Cauchy (Gelman 2006) as the main alternative, and discourages `Gamma(eps, eps)` on the
> precision and `Uniform(0, K)` on the SD.

## Setup and network

```r
library(multinma)
options(mc.cores = parallel::detectCores())   # parallel chains

# Arm-based aggregate data -> network object.
# trt_class groups treatments for a class-based meta-regression later (optional).
net <- set_agd_arm(
  icl_data_long,
  study = study, trt = trt,
  r = r, n = n,
  trt_ref = "nonantibacterial",                  # set the reference explicitly
  trt_class = as.numeric(trt != "nonantibacterial")
)

net                       # prints n studies, treatments, classes, outcome type,
                          # reference, and whether the network is CONNECTED
plot(net, weight_nodes = TRUE, weight_edges = TRUE)   # node ~ patients, edge ~ studies
```

Check the printed "Network is connected" line before going further — a disconnected network cannot be estimated by standard NMA.

For other outcome types, the same `set_agd_arm()` takes different data arguments: `y` + `se` for continuous (Normal/identity), `r` + `n` with `link = "cloglog"` and a time offset for rates, `multi()` for ordered categorical. IPD studies use `set_ipd()` / `set_agd_contrast()` and can be combined with `combine_network()`.

## Fit fixed and random effects

```r
fit_fe <- nma(net, trt_effects = "fixed",
              prior_intercept = normal(scale = 100),
              prior_trt       = normal(scale = 100))

fit_re <- nma(net, trt_effects = "random",
              prior_intercept = normal(scale = 100),
              prior_trt       = normal(scale = 100),
              prior_het       = half_normal(scale = 2.5))   # prior on heterogeneity SD
```

**Set priors deliberately.** `multinma`'s defaults raise a warning by design — a prior that's vague for a log-OR (e.g. `normal(scale = 100)`) may be informative on another scale. For random effects, an informative heterogeneity prior from published meta-analyses (e.g. Rhodes et al.) is often better than a vague one given how few trials inform τ.

**Choosing the heterogeneity prior's scale.** The example above uses `half_normal(scale = 2.5)`; the
scale is the entire content of that prior and deserves a reason. Three defensible routes, in
increasing order of how much you are claiming:

- **Half-Cauchy** — heavier-tailed than half-normal, so it is more permissive of large τ when few
  trials inform it. A common weakly-informative default.
- **Half-normal** — lighter tails; a stronger statement that very large heterogeneity is implausible.
- **Penalised-complexity / exponential on τ**, calibrated from a tail statement: `lambda =
  -log(alpha)/U` encodes `Pr(tau > U) = alpha`, so `Pr(tau > 1) = 0.1` gives `Exponential(2.31)`.
  This is the most defensible in a submission because the prior *is* a sentence a reviewer can
  disagree with. See `brms-modelling`'s `references/core-workflow.md` §1 for the derivation. Check
  which prior families the installed `multinma`'s `prior_het` accepts before assuming `exponential()`
  is among them — a half-normal or half-Cauchy calibrated to the same tail statement is the fallback.

Whichever you choose, **sanity-check it by forward simulation** rather than by eye: draw from the
prior on τ, and look at the implied spread of study-level effects on the scale you care about (the
OR or HR scale, not the log scale). A prior that looks innocuous on the log-OR scale can imply odds
ratios of 20 between otherwise similar trials. Overlaying two candidate priors' implied spreads is a
quick way to see that a half-Cauchy and a calibrated exponential are often close in the region that
matters and differ mainly in the tail.

## Convergence — check before reading anything

```r
print(fit_re)             # look at Rhat (want < 1.05) and n_eff / ESS per parameter
```

Rhat ≥ 1.05 or low effective sample size means the chains haven't converged — the estimates aren't trustworthy yet. If convergence is poor, raise `adapt_delta` or `max_treedepth` via `control = list(...)`, or reconsider priors.

## Choose fixed vs random with DIC

```r
(dic_fe <- dic(fit_fe))   # Residual deviance, pD, DIC
(dic_re <- dic(fit_re))
plot(dic_re)              # per-arm residual deviance -- spot poorly-fitting arms
                          # (zero-event arms often fit badly)
```

Lower DIC/residual deviance favours that model; differences of ~5+ are considered important (advice ranges 3–7). Combine with prior expectation of heterogeneity — don't pick on DIC alone.

## Relative effects and ranking

```r
# Relative effects vs reference, on the linear-predictor (log-OR) scale
(re <- relative_effects(fit_re, trt_ref = "nonantibacterial"))

# Exponentiate to odds ratios for interpretation
or <- summary(exp(as.array(re)))
# CrI excluding 1 (OR) / 0 (log-OR) => evidence of a difference

# Ranking
posterior_ranks(fit_re)                         # mean rank per treatment
probs <- posterior_rank_probs(fit_re)           # P(each rank)
plot(probs)                                     # rankogram (spiky = certain rank)
posterior_rank_probs(fit_re, cumulative = TRUE) # -> cumulative rankogram via plot()
```

Report ranks *with* the relative effects, never instead. "Probability best" is unstable under high uncertainty.

## Network meta-regression (effect modifiers only)

```r
fit_reg <- nma(net, trt_effects = "random",
               regression = ~.trt:contamination_level,   # .trt = treatment special
               class_interactions = "common",            # share coef across treatments
               prior_intercept = normal(scale = 100),
               prior_trt       = normal(scale = 100),
               prior_reg       = normal(scale = 100),
               prior_het       = half_normal(scale = 2.5))
print(fit_reg); dic(fit_reg)
```

Interpret the `beta[...]` coefficient (a ratio-of-ORs per covariate unit). Compare DIC/residual deviance/τ to the unadjusted model — little change means no evidence the covariate modifies the effect, but remember aggregate-data meta-regression is underpowered, so "no evidence" isn't "no effect". `class_interactions` can be `"common"` (one shared coefficient, strong but often necessary), `"exchangeable"` (random across treatments), or `"independent"`.

## Inconsistency (covered fully in inconsistency-testing.md)

```r
fit_ume       <- nma(net, consistency = "ume", trt_effects = "random",
                     prior_intercept = normal(scale = 100), prior_trt = normal(scale = 100),
                     prior_het = half_normal(scale = 2.5),
                     control = list(max_treedepth = 15))   # only if warnings appear
fit_nodesplit <- nma(net, consistency = "nodesplit", trt_effects = "random",
                     prior_intercept = normal(scale = 100), prior_trt = normal(scale = 100),
                     prior_het = half_normal(scale = 2.5),
                     control = list(max_treedepth = 15))
dic(fit_ume)                       # compare to dic(fit_re)
summary(fit_nodesplit)             # per-comparison direct vs indirect + Bayesian p-values
plot(fit_nodesplit)                # visual direct/indirect/NMA comparison
```

## Survival NMA

Recent `multinma` versions implement survival NMA with standard parametric, piecewise-exponential, and flexible M-spline hazards, all allowing non-proportional hazards — set the survival outcome in `set_agd_*()`/`set_ipd()` and the corresponding `likelihood`/distribution in `nma()`. This is the modern alternative to the older two-step multivariate NMA-of-survival-parameters approach. The per-arm survival fitting that precedes a two-step approach is in the `survival-analysis-hta` skill; the resulting per-arm survival inputs feed `hesim` via `params_surv_list` in the `multistate-models-hta` skill.
