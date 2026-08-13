# ML-NMR with multinma

Multilevel network meta-regression: the general population-adjustment method. It defines an individual-level regression (as in IPD-NMR) and incorporates AgD studies by **integrating** that model over each AgD study's covariate distribution — correctly linking the two levels and avoiding the aggregation / non-collapsibility bias that "plug-in means" approaches incur. It synthesises networks of any size and any IPD/AgD mix, and — crucially — produces estimates in **any target population**. Implemented in `multinma` (Stan). Example: plaque psoriasis, PASI 75 binary outcome, 9 studies (4 IPD: UNCOVER-1/2/3, IXORA-S; 5 AgD), target = PROSPECT cohort.

> Sources: R-HTA Ch. 13 (ML-NMR; plaque-psoriasis network); Phillippo et al. (ML-NMR methodology, per TSD 18 and subsequent papers); `multinma` pkgdown docs — `set_ipd()`, `set_agd_arm()`, `combine_network()`, `add_integration()`, `nma()`, `relative_effects()`, `marginal_effects()`, `predict()` confirmed current. Accessed 2026-07-03.

## Pipeline overview
`set_ipd()` + `set_agd_arm()` → `combine_network()` → `add_integration()` → `nma()` → `relative_effects()` / `predict()` / `marginal_effects()` for the target population.

## 1. Prepare data and build the network

Transform covariates sensibly: binary covariates / percentages to 0–1 proportions, continuous covariates approximately unit-scaled (improves sampling and interpretation). Add treatment classes (used for the shared-effect-modifier assumption).

```r
library(multinma)
options(mc.cores = parallel::detectCores())

pso_net <- combine_network(
  set_ipd(pso_ipd, study = studyc, trt = trtc, r = pasi75, trt_class = trtclass),
  set_agd_arm(pso_agd, study = studyc, trt = trtc,
              r = pasi75_r, n = pasi75_n, trt_class = trtclass)
)
plot(pso_net, weight_nodes = TRUE, weight_edges = TRUE, show_trt_class = TRUE)
```

(For full IPD, the same workflow drops `set_agd_arm()` and `add_integration()` — it's just an IPD-NMR. For no covariates, it reduces to a standard AgD-NMA, the `network-meta-analysis-hta` skill.)

## 2. Set up numerical integration for the AgD studies

`add_integration()` reconstructs each AgD study's joint covariate distribution from its marginal summaries, using assumed marginal forms (via `distr()`) and a correlation matrix. Choose marginal forms to match the IPD (e.g. Gamma for skewed positive covariates, logit-Normal for a proportion, Bernoulli for binary).

```r
pso_net <- add_integration(pso_net,
  durnpso = distr(qgamma,     mean = durnpso_mean, sd = durnpso_sd),
  prevsys = distr(qbern,      prob = prevsys),
  bsa     = distr(qlogitnorm, mean = bsa_mean,     sd = bsa_sd),
  weight  = distr(qgamma,     mean = weight_mean,  sd = weight_sd),
  psa     = distr(qbern,      prob = psa))
# Correlation matrix: if cor is omitted it's computed automatically from the IPD
# and stored in pso_net$int_cor (reuse it later for the target population).
```

ML-NMR results are typically **insensitive** to misspecifying these reconstruction assumptions (simulation evidence), though a highly non-linear model or targeting marginal effects can raise sensitivity. Integration uses Quasi-Monte Carlo; accuracy is now checked automatically by default.

## 3. Fit the model

The individual-level linear predictor has study-specific intercepts (preserving randomisation), prognostic main effects `β1`, effect-modifying treatment-covariate interactions `β2,k`, and treatment effects `γ_k`. Specify it through the `regression` formula with `*.trt` for interactions.

```r
pso_fit <- nma(pso_net,
  trt_effects = "fixed",
  link = "probit",
  likelihood = "bernoulli2",                 # 2-par Binomial approx for AgD level
  regression = ~(durnpso + prevsys + bsa + weight + psa) * .trt,
  class_interactions = "common",             # shared effect modifier within class
  prior_intercept = normal(scale = 10),
  prior_trt       = normal(scale = 10),
  prior_reg       = normal(scale = 10),
  init_r = 0.1,                              # narrow init; probit can be hard to start
  QR = TRUE)                                  # QR decomposition: big efficiency gain
print(pso_fit, pars = "d")                    # check Rhat ~ 1, adequate n_eff
```

**Shared effect modifier assumption** (`class_interactions = "common"`): sets `β2,k` equal within a treatment class. Often needed to identify interactions when AgD studies are few, and reasonable when treatments share a class/mode of action — but a real assumption. In a two-study comparison without it, ML-NMR is limited like MAIC/STC to the AgD population. In larger networks, **assess it** (relax one covariate at a time) or drop it given enough data, and assess the underlying conditional-constancy-of-relative-effects assumption via residual heterogeneity / inconsistency using standard NMA tools (UME, etc. — the `network-meta-analysis-hta` skill) *within* the ML-NMR framework.

## 4. Estimates for the target population

Without a target, estimates are produced per study population. For a decision you want the **target population** (here PROSPECT) — supply its covariate summaries as `newdata`.

### Conditional population-average relative effects
```r
prospect_dat <- data.frame(studyc = "PROSPECT",
  durnpso = 1.96, durnpso_sd = 1.35, prevsys = 0.9095,
  bsa = 0.187, bsa_sd = 0.184, weight = 8.75, weight_sd = 2.03, psa = 0.202)

relative_effects(pso_fit, newdata = prospect_dat, study = studyc,
                 all_contrasts = TRUE)        # all pairwise conditional effects
```
Conditional effects need only the **effect-modifier** means in the target population (the expression collapses to the mean covariates by linearity) — not prognostic or baseline-risk information.

### Absolute outcomes (the economic-model inputs)
Absolute predictions need integration set up for the target population *and* a baseline-risk distribution. Reuse the IPD correlation matrix.

```r
prospect_dat <- add_integration(prospect_dat,
  durnpso = distr(qgamma,     mean = durnpso, sd = durnpso_sd),
  prevsys = distr(qbern,      prob = prevsys),
  bsa     = distr(qlogitnorm, mean = bsa,     sd = bsa_sd),
  weight  = distr(qgamma,     mean = weight,  sd = weight_sd),
  psa     = distr(qbern,      prob = psa),
  cor     = pso_net$int_cor)                  # reuse IPD correlations

# Baseline risk: e.g. 1156/1509 achieved PASI 75 on SEC_300 in PROSPECT
prospect_pred <- predict(pso_fit, type = "response",
  newdata = prospect_dat, study = studyc,
  baseline = distr(qbeta, 1156, 1509 - 1156),
  baseline_type = "response", baseline_level = "aggregate",
  baseline_trt = "SEC_300")
prospect_pred; plot(prospect_pred)
```
Absolute outcomes require **effect-modifying and prognostic** covariate distributions *and* a baseline-risk distribution `μ_(P)` — usually obtained by inverting a distribution on the average response on a reference treatment, as above. (Newer `multinma` can also summarise over individual `newdata` rows instead of pre-integrated points.)

### Marginal population-average effects
`marginal_effects()` wraps `predict()` to give marginal effects from the absolute predictions:
```r
marginal_effects(pso_fit, mtype = "link",     # "link" => probit-scale marginal diff
  newdata = prospect_dat, study = studyc,
  baseline = distr(qbeta, 1156, 1509 - 1156),
  baseline_type = "response", baseline_level = "aggregate",
  baseline_trt = "SEC_300", all_contrasts = TRUE)
```
Marginal effects also need effect-modifying + prognostic + baseline-risk information. See `assumptions-and-estimands.md` for when marginal and conditional diverge.

## 5. Why ML-NMR over MAIC here
In the worked example, ML-NMR gives a more precise ixekizumab-vs-secukinumab estimate than the MAIC — partly because it uses *all* the evidence (the MAIC discarded 6 of 9 studies lacking an etanercept arm), partly because it can extrapolate where MAIC can't. Most importantly, the ML-NMR estimate is in the **PROSPECT target population**, whereas the MAIC was stuck in the FIXTURE study population. That target-population point, not the precision, is usually the decisive one for the decision problem.

## Survival outcomes
The most common PAIC application (oncology) is on survival, not binary. `multinma` implements ML-NMR survival (parametric and flexible M-spline baseline hazards, non-PH via `aux_regression = ~.trt`), producing survival curves per treatment in the target population — the inputs the `survival-analysis-hta` and downstream economic-model skills consume. The network/integration/target-population workflow above is unchanged; the outcome setup and likelihood differ.
