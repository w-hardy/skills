# Core brms workflow

This is the backbone referenced by SKILL.md. Read the relevant sections in full rather than skimming — the thresholds and remedies here are what make a review or a new model defensible.

## 1. Priors

brms will fit a model with no explicit priors at all, silently falling back to its own defaults (typically flat/improper for fixed effects, weakly informative for variance components). That's often a reasonable starting point, but it's *not* the same as having made a deliberate prior choice, and it should never be the unstated default in a finished script.

**When writing:**
- Call `get_prior(formula, data, family)` first and look at what brms would use by default before deciding whether to override it.
- Set explicit, weakly-informative priors for fixed effects unless there's a specific reason to use flat priors (e.g. replicating a frequentist benchmark). A normal prior centred at 0 with an SD chosen to be plausible on the link-function scale is a reasonable default starting point. `normal(0, 2.5)` is a common choice (it is `rstanarm`'s autoscaled default) but it is only meaningful for *standardised* predictors — on a raw predictor it can be wildly informative or wildly diffuse depending on that predictor's units. State the scale a prior assumes, and standardise predictors first if you want a scale-free default to be defensible (cf. Gelman, Hill & Vehtari, *Regression and Other Stories*, chs. 10 and 12 — ch. 12 opens "it is not always best to fit a regression using data in their raw form" and develops standardising and log/other transformations; on priors read jointly with the likelihood, Gelman, Simpson & Betancourt 2017, *Entropy* 19:555). Note that brms's *own* default here is a flat improper prior on population-level effects (and `student_t(3, 0, 2.5)` on the intercept and group-level SDs), not `normal(0, 2.5)` — so leaving `prior` unset is not the same as having set a weakly-informative normal.
- Run a **prior predictive check** before fitting to data: `brm(..., sample_prior = "only")`, then inspect with `pp_check(fit, ndraws = 100)`. This catches priors that imply absurd outcomes (e.g. negative counts, probabilities that pile up at 0/1) before you've spent compute fitting to real data.
- For variance/group-level SD parameters, weakly-informative half-normal or exponential priors (brms defaults are usually reasonable here) are preferable to flat priors, which can cause sampling problems in models with few groups.

**When reviewing:**
- Flag any model with no `prior = ` argument and no comment indicating that brms defaults were a deliberate choice.
- Flag priors copied from another project/paper without a one-line justification for why they're appropriate here (same scale? same plausible effect range?).
- Check whether a prior predictive check was run anywhere in the script or its history. If not, this is worth raising even if the posterior looks fine — it's about defensibility, not just outcome.

## 2. Recover: fake-data simulation

Before fitting to real data, simulate data from the model with *known* parameter values, fit the model to that simulated data, and check it recovers the values you put in. This is the step most easily skipped and the one that catches the errors `pp_check()` and the convergence diagnostics can't: a model can sample cleanly, pass posterior predictive checks, and still mis-estimate the parameter you care about because the likelihood or the parameterisation is subtly wrong. *Regression and Other Stories* (Gelman, Hill & Vehtari, ch. 5, *Simulation* — "you don't understand your model until you can simulate from it") treats fake-data simulation as foundational, not optional, and *Bayesian Workflow* (Gelman, Vehtari et al. 2020, arXiv:2011.01808, §4.1) formalises the systematic version as simulation-based calibration (SBC, §4.2); see `bayesian-workflow-sources.md` for how the stages hang together.

**When writing:** for anything beyond a textbook GLM — and especially for the harder families this skill targets (hurdle/zero-inflated, censored survival, few-group multilevel, small-study meta-analysis) — generate one fake dataset from known coefficients, fit, and confirm the true values fall within the bulk of their posteriors. A minimal version:

```r
set.seed(1)
# 1. choose true parameters and simulate an outcome from the model's own
#    data-generating process (here a simple example; match yours to the family)
n <- 500
x <- rnorm(n)
true_b <- 0.4
y <- rnorm(n, mean = 0.2 + true_b * x, sd = 1)
sim_df <- data.frame(y, x)

# 2. fit the SAME model you intend to use on real data
fit_sim <- brm(y ~ x, data = sim_df, family = gaussian(),
               backend = "cmdstanr", seed = 1, refresh = 0)

# 3. check recovery: is true_b (0.4) inside the posterior?
posterior_interval(fit_sim, variable = "b_x")
```

For a fuller guarantee, repeat over many simulated datasets and check the rank statistics are uniform (`SBC` package) — worth doing once for a novel model structure you'll reuse, overkill for a routine GLM.

**When reviewing:** the absence of any fake-data check is a legitimate gap to raise for non-trivial models, framed as defensibility rather than a blocker — it's the difference between "the sampler worked" (diagnostics), "the model fits the data" (PPC), and "the model can recover truth at all" (fake-data simulation). These are three distinct questions and the third is the one most often left unasked.

## 3. Fitting

Key `brm()` arguments and what they're for:

- `chains` — use at least 4. Fewer makes Rhat/multimodality checks unreliable.
- `iter` / `warmup` — defaults (2000 iter, half warmup) are a reasonable starting point; increase if ESS is low (see diagnostics below) rather than reflexively increasing on every fit.
- `cores` — set to `chains` (or fewer if hardware-limited) for parallel chains; combine with `threads = threading(n)` for within-chain parallelisation on large datasets (cmdstanr backend only).
- `seed` — always set this for reproducibility. Its absence is a small but easy review flag.
- `control = list(adapt_delta = ..., max_treedepth = ...)` — raised in response to divergences or treedepth warnings. A high `adapt_delta` (0.95–0.99) is *expected and appropriate* in funnel-prone models — hierarchical models with few groups, small-study meta-analysis — so don't treat a high value as suspicious in itself; it's a normal part of fitting these models well. What matters is whether divergences were actually checked and resolved *after* raising it. The thing to flag is a high `adapt_delta` with no accompanying confirmation that divergences reached zero, or `adapt_delta` pushed toward 0.999 reflexively without ever inspecting *why* the geometry is hard — which usually points to a parameterisation fix (e.g. non-centring) rather than a higher acceptance target alone.

**When reviewing:** check that chains/iter are sufficient to make the diagnostics below meaningful, and that any `control` overrides are explained rather than copy-pasted as a generic "fixes divergences" move.

## 4. Diagnostics — concrete thresholds

Check `summary(fit)` or `rhat()`/`neff_ratio()` and the sampler's own warnings. Don't eyeball just the coefficient table.

| Diagnostic | Threshold | What it means if violated | What to do |
|---|---|---|---|
| Rhat | < 1.01 | Chains haven't mixed — could be too few iterations, or genuine multimodality | Run longer; check trace plots (`plot(fit)`) for multimodality vs. slow mixing |
| Bulk & tail ESS | ≥ 100 per chain (≈ 400 total at the usual 4 chains), checked separately for bulk and tail | Effective sample size too low for stable posterior summaries, especially in the tails (matters for tail-sensitive quantities like extreme quantiles or rare-event probabilities) | Run more iterations; consider non-centred parameterisation for multilevel models (see `model-families/multilevel.md`) |
| Divergent transitions | 0 | The sampler is failing to explore part of the posterior — results may be **biased**, not just imprecise | First try increasing `adapt_delta` (e.g. to 0.95–0.99); if divergences persist, this usually signals a parameterisation problem (e.g. funnel geometry in hierarchical models) rather than something `adapt_delta` alone fixes |
| Max treedepth hit | 0 exceedances | Sampler is being inefficient, possibly masking a deeper geometry problem | Increase `max_treedepth`; if it's still hit, look for non-centred parameterisation or strongly correlated predictors |

A model with divergences is the one case where "it ran without errors" is actively misleading — the posterior draws may not represent the true posterior at all. Treat any unresolved divergence as a blocker, not a caveat to mention in passing.

## 5. Posterior predictive checks

`pp_check(fit)` (default: density overlay) is a starting point, not the whole check. Match the check to what the model needs to get right:

- `pp_check(fit, type = "dens_overlay")` — overall distributional shape
- `pp_check(fit, type = "stat", stat = "mean")` / other summary stats — does the model recover key summary statistics?
- `pp_check(fit, type = "intervals")` or grouped checks — for multilevel models, check fit *within* groups, not just marginally
- For count/zero-heavy outcomes, explicitly check the proportion of zeros reproduced (`pp_check(fit, type = "rootogram")` or a custom zero-count check) — this is the single most common thing distributional models get reviewed for

**When reviewing:** a model with no posterior predictive check at all, anywhere in the script, is a gap worth flagging regardless of how good the diagnostics in section 4 look — diagnostics tell you the sampler worked; PPCs tell you the model is adequate.

## 6. Model comparison

- Always call `fit <- add_criterion(fit, "loo")` rather than computing `loo()` ad hoc each time — this caches the criterion in the fitted object and avoids silently recomputing it on different data if the workspace changes. Prefer PSIS-LOO over WAIC: current loo guidance treats LOO as the default and retains WAIC mainly for backward compatibility, so reach for `waic` only when there's a specific reason to.
- Use `loo_compare()` for comparing models, and inspect Pareto-k diagnostics (`loo::pareto_k_table()` or `plot(loo_result)`) before trusting the comparison. The reliability threshold for Pareto-k is **sample-size dependent**, not a fixed 0.7: an observation's k is reliable only if `k < min(1 - 1/log10(S), 0.7)`, where S is the number of posterior draws. The 2022 PSIS revision replaced the old fixed 0.5/0.7 cutoffs with this rule and removed the intermediate "ok" band, so the categories are now good / bad / very bad (k > 1). For the Stan default of ~4000 draws the bar is ≈0.7, but at smaller S it is lower — roughly 0.5 at S=100, 0.6 at S=320, 0.67 at S=1000 — which is exactly the small-data regime (few-study meta-analysis, small multilevel datasets) where it bites. Don't wave through a k of 0.65 just because it's under 0.7; read the threshold the current loo package reports rather than applying 0.7 by hand.
  - For points above the threshold, refit with `loo(fit, reloo = TRUE)` to do exact leave-one-out for those points (slow but correct), or try moment-matching (`loo::loo_moment_match()`) as a faster approximation.
- **Comparability check (the most common review gap):** models being compared must be fit to the *identical* dataset — same rows, same likelihood family if comparing predictive performance directly. Flag any comparison where one model's data went through different `filter()`/`drop_na()` steps than another's, or where the outcome was transformed differently — `loo_compare()` will run without complaint on mismatched data and produce a meaningless answer.
- For grouped/longitudinal data, marginal leave-one-observation-out validation can be optimistic — consider k-fold cross-validation with folds defined at the group level (`kfold(fit, folds = "group", group = "...")`) when the scientific question is about predicting new groups, not new observations within known groups.

## 7. Reporting

For a write-up (paper, internal report), report enough that someone else could refit the model:
- Exact prior specifications used (not just "weakly informative priors were used")
- brms/Stan backend and version, number of chains, iterations, warmup, and `adapt_delta`/`max_treedepth` if non-default
- Convergence diagnostics achieved (Rhat, ESS) and confirmation of zero divergences
- Posterior summaries as appropriate to the audience: posterior median/mean with a credible interval, not just a point estimate

This aligns with reporting checklists such as the Bayesian Analysis Reporting Guidelines (BARG) and the WAMBS checklist for Bayesian multilevel/structural models — useful as a sense-check for completeness rather than something to follow mechanically.

Use `conditional_effects(fit)` for a quick visual of marginal effects, `tidybayes` (`spread_draws()`, `gather_draws()`) for tidy posterior summaries feeding into custom plots/tables, and `marginaleffects` when contrasts or average marginal effects on a transformed scale are needed (e.g. risk differences from a logistic model).
