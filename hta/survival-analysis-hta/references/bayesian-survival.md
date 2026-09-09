# Bayesian parametric survival and extrapolation

> Sources: *Bayesian Modelling in Health Technology Assessment* — Baio (Chapman & Hall/CRC, 2026),
> Ch. 8 (survival analysis in HTA). Method and API claims anchored to the companion repository
> <https://github.com/giabaio/bmhta-examples> (MIT), commit `d2a6298` (2026-08-07), file
> `08-survival/survival.R` and its chapter `README.md`; accessed 2026-09-09. The book's own text
> and CRAN were not reachable from the authoring environment, so **function signatures below are
> those observed in working code at that commit, not re-verified against current CRAN** — check
> `?fit.models` / `?survextrap` against the installed version before relying on an argument name.

This file covers the Bayesian route through the workflow in `SKILL.md`. It does not replace it: the
framing that model choice is governed by extrapolation plausibility rather than fit, the hazard-shape
inspection, the mean-not-median rule and the pitfalls all still apply. What changes is how
uncertainty is represented and how external evidence enters.

## Why Bayesian here, specifically

Not ideology — three concrete payoffs, all of which bite hardest in extrapolation.

**Regularisation where the data cannot identify a parameter.** The clearest case in the source is the
Generalised F, which has three ancillary parameters (`sigma`, `p`, `q`). Fitted by maximum
likelihood on realistic trial data, `p` is effectively non-identifiable: its 95% interval spans
essentially the whole positive line, and the fit is useless despite converging. With mildly
regularising priors — the source uses `log(p) ~ Normal(0, 0.5)`, `sigma ~ Gamma(0.1, 0.1)`,
`q ~ Normal(0, 2.5)` — the posterior for `p` is finite and clinically sensible. Flexible
distributions are attractive for extrapolation precisely because they can bend, and that flexibility
is what makes them weakly identified; priors are how you use them anyway. Say what the priors are
and check the posterior is not simply reproducing them.

**Uncertainty that propagates without a normal approximation.** The frequentist route samples
parameters from a multivariate normal on the transformed scale using the fit's `vcov`. That is an
approximation, and it degrades exactly where the likelihood is skewed — small samples, heavy
censoring, weakly identified shape parameters. The posterior is the joint uncertainty, no
approximation, and it carries the parameter correlations that matter when a survival curve is
reconstructed from several parameters at once.

**External evidence enters as evidence.** Background mortality, registry data or elicited long-term
survival can be added to the likelihood or the prior and updated jointly with the trial data, rather
than bolted on afterwards as a constraint or a scenario. See the `survextrap` section below.

## Fitting with survHE

`survHE`'s Bayesian back-ends live in companion packages — `survHEhmc` (Stan/HMC) and `survHEinla`
(INLA) — installed separately from the maintainer's r-universe, not from CRAN with `survHE` itself.
Only `survHEhmc` is needed for the HMC route.

```r
m <- survHE::fit.models(
  formula = Surv(time, status) ~ treatment,
  data    = trial,
  distr   = c("wei", "gom", "lno"),   # Weibull (AFT), Gompertz, log-Normal
  method  = "hmc"
)
```

`fit.models()` batch-fits the whole set in one call and stores each fit plus its DIC. Inspecting a
fit has two modes, and the second is the one that matters for a Bayesian workflow:

```r
print(m, mod = 1)                                        # survHE notation, natural scale
print(m, mod = 1, original = TRUE, print_priors = TRUE)  # Stan parameter names, priors, Rhat, n_eff
rstan::traceplot(m$models[[1]])                          # chains
rstan::stan_ac(m$models[[1]])                            # autocorrelation
```

**Run `original = TRUE, print_priors = TRUE` on every model before reading any result.** It is the
only place the priors actually used and the convergence diagnostics are shown together. `survHE`
supplies default priors; defaults are a choice, and an unstated one is not reportable. The
diagnostic thresholds are the ordinary ones — see `brms-modelling`'s `references/core-workflow.md`
for Rhat/ESS/divergence handling; nothing about survival changes them.

## Posterior survival bands — the extrapolation uncertainty that matters

```r
plot(m, mods = 1, nsim = 1000, t = seq(0, 180), add.km = TRUE)
plot(m, mods = 1, nsim = 1000, t = seq(0, 180), what = "hazard")
```

With `nsim > 1`, `survHE` calls `make.surv()` internally to propagate the **joint** posterior over
all parameters into a distribution of survival curves, and the plot gains a credible band. Two
things follow:

- The band widens with extrapolation distance, which is the honest picture and the one to show a
  committee. A single extrapolated line implies a precision that does not exist.
- Plot `what = "hazard"` as well as survival. The `SKILL.md` rule — inspect the extrapolated hazard,
  not just `S(t)` — is unchanged, and the posterior band on the hazard is more revealing than the
  band on survival, because implausible hazard behaviour is visible long before it shows up as a
  visibly odd survival curve.

`plot()` returns a `ggplot`, so layers can be edited directly (the source removes the KM confidence
ribbon with `p$layers[[4]] <- NULL` to leave the step function against the parametric band —
brittle, since the layer index depends on what was plotted; check what you are deleting).

## Model comparison

`survHE` reports **DIC**, and `model.fit.plot(m, type = "DIC")` charts it across the fitted set;
`scale = "relative"` shows the percentage increase over the best model, which communicates "how much
worse" far better than raw values. Use it, and follow the repository's general position
(`trial-based-cea-hta`'s `references/model-comparison-and-handoff.md`): DIC where the package's
workflow supplies it, LOO where pointwise log-likelihood is available, never a silent mix within one
comparison.

The `SKILL.md` warning applies with full force and is not solved by going Bayesian: **DIC, like AIC,
measures fit to the observed follow-up only.** A Bayesian model with the best DIC can still
extrapolate absurdly. Rank on DIC, then decide on the hazard plot and external plausibility.

Where the arms are not well described by one distribution with a treatment covariate, fit them
separately with an intercept-only formula — this lets both location *and* ancillary parameters
differ by arm and so relaxes proportional hazards entirely:

```r
m_ctl <- survHE::fit.models(Surv(time, status) ~ 1, data = filter(trial, arm == "control"), ...)
m_trt <- survHE::fit.models(Surv(time, status) ~ 1, data = filter(trial, arm == "active"),  ...)
survHE::model.fit.plot(control = m_ctl, active = m_trt, type = "DIC", stacked = TRUE)
```

The cost is that no treatment effect parameter exists — the comparison is between two independently
extrapolated curves, so there is no hazard ratio to report and no way to apply a treatment-effect
waning assumption to a coefficient. Handle waning on the curves instead (see `SKILL.md`).

## survextrap: flexible hazards anchored by external data

`survextrap` is the most substantive Bayesian addition for HTA, because it addresses the actual
problem: the trial says almost nothing about the hazard after follow-up ends, and a standard
parametric family answers that question purely by extrapolating its own functional form.

It fits an **M-spline** on the hazard, so the shape over the observed period is flexible rather than
imposed by a two-parameter family, and it lets **external aggregate evidence** contribute to the
likelihood in the extrapolation region.

```r
spec <- survextrap::mspline_spec(Surv(time, status) ~ 1, data = trial, df = 6, add_knots = 180)

fit <- survextrap::survextrap(
  Surv(time, status) ~ treatment,   # PH in the treatment covariate by default
  data     = trial,
  mspline  = spec,
  external = extdat                 # optional; see below
)

surv <- survextrap::survival(fit)   # tidy tibble: t, treatment, mean, 2.5%, 97.5%
```

Parameters to expect in the output: `alpha` (log baseline hazard scale), `coefs` (the spline basis
weights), `loghr`/`hr` (treatment effect), and `hsd` — the **smoothing standard deviation**, given a
`Gamma(2, 1)` prior in the source. `hsd` is the parameter that controls overfitting: as it goes to
zero the hazard flattens toward constant. It is a prior on *shape flexibility*, so state it; a
spline model's extrapolation is largely a statement about this parameter.

`df = 6` sets the number of basis functions and `add_knots = 180` extends the knot grid to the
extrapolation horizon — without that, the spline has no basis functions where you are asking it to
predict.

**External data.** Supplied as aggregate counts: `r_j` of `n_j` individuals alive at `t_j^start`
were still alive at `t_j^stop`, for intervals in the extrapolation region. These contribute to the
likelihood through the conditional survival implied by the model,

```
pi_j = S(t_j^stop | theta) / S(t_j^start | theta)
```

so registry data, a life table, or elicited long-term survival becomes evidence the posterior must
be consistent with, rather than a scenario applied afterwards. The effect in the source is exactly
what you would want: the extrapolated curves are pulled toward the external evidence and the
credible band in the extrapolation region narrows.

This is the mechanism `SKILL.md` gestures at under "bring in external information", made concrete.
Two cautions. The external evidence must be about a **relevant population** — importing registry
survival for a broader or sicker cohort will confidently pull the extrapolation to the wrong place,
and the narrowed band will make that look like precision. And the flexibility that makes M-splines
good at fitting the observed hazard is exactly what makes them dependent on the external data or the
smoothing prior beyond it; a flexible model with nothing anchoring its tail is not better than a
parametric one, just less honest about where its tail comes from.

## Model uncertainty, not just model selection

The Bayesian machinery makes it easy to report parameter uncertainty within a chosen distribution and
easy to forget that **the distribution choice usually dominates it**. A posterior band from the best-DIC
Weibull can be narrow while the Gompertz, nearly as good on DIC, implies a mean survival years apart.

Report the spread across credible distributions as structural uncertainty — as scenarios, or by
averaging with explicit weights. `bayesian-cea-r-hta` owns the machinery for carrying several
candidate models through to the decision (`BCEA::struct.psa()`); this skill's job is to produce a
defensible candidate set and say which of them the data cannot distinguish.

## Feeding the economic model

Unchanged in structure from `references/survival-to-economic-model.md`, with one improvement: instead
of sampling parameters from a multivariate normal approximation, use the posterior draws directly.
Take the draws, compute the survival or transition probabilities per draw, and carry them through —
the joint parameter correlation comes along for free, and no normal approximation is imposed on a
skewed posterior. Keep the draws paired with everything else in the economic model, as
`trial-based-cea-hta` sets out for costs and effects.
