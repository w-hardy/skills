# MAIC and STC in R

Both are mixed-IPD+AgD, two-study, AgD-population-only methods. MAIC reweights; STC regresses. Worked example mirrors the book: IPD on B-vs-A (ixekizumab vs etanercept, from UNCOVER trials), AgD on C-vs-A (secukinumab vs etanercept, FIXTURE), wanting B-vs-C in the FIXTURE (AgD) population, on the probit scale.

> Sources: R-HTA Ch. 13 (MAIC/STC worked example — UNCOVER/FIXTURE plaque-psoriasis data); NICE DSU TSD 18 (MAIC and STC methods and their two-study, AgD-population limitations). Accessed 2026-07-03.

## MAIC — base R (optim + weighted glm + sandwich)

MAIC needs no special package; the chapter's code is adapted from TSD 18. Several R packages wrap it (`MAIC`, `maicplus`, `maicChecks`, `maic`) but the base-R version is transparent and worth understanding.

### 1. Centre IPD covariates on the AgD summaries
Match the first and second moments of continuous covariates (so the reweighted variance matches too), and proportions for binary covariates. Centre so the AgD targets become zero.

```r
# AgD (FIXTURE) covariate summaries: mean, and mean^2 + sd^2 for the 2nd moment
X_agd <- with(fixture_agd, cbind(
  durnpso_mean, durnpso_mean^2 + durnpso_sd^2,
  prevsys / 100,
  bsa_mean, bsa_mean^2 + bsa_sd^2,
  weight_mean, weight_mean^2 + weight_sd^2,
  psa / 100))
# if summaries are per-arm, collapse to overall by sample-size weighting
X_agd <- apply(X_agd, 2, weighted.mean, w = fixture_agd$sample_size_w0)

# Centre the IPD design matrix (raw covariate AND its square for continuous covars)
X_ipd <- sweep(with(uncover_ipd, cbind(
  durnpso, durnpso^2, prevsys, bsa, bsa^2, weight, weight^2, psa)),
  MARGIN = 2, STATS = X_agd, FUN = "-")
```

### 2. Estimate weights by method of moments
Minimise `Σ exp(x'α)` over the centred covariates; the weights are `w = exp(x'α̂)`. Do it **per IPD study** so each matches the AgD population.

```r
objfn  <- function(a1, X) sum(exp(X %*% a1))
gradfn <- function(a1, X) colSums(sweep(X, 1, exp(X %*% a1), "*"))

opt <- optim(par = rep(0, ncol(X_ipd)), fn = objfn, gr = gradfn,
             X = X_ipd[study == "UNCOVER-2", ], method = "BFGS")
wt  <- exp(X_ipd[study == "UNCOVER-2", ] %*% opt$par)
```

### 3. Diagnose overlap — mandatory
```r
ess <- sum(wt)^2 / sum(wt^2)          # effective sample size
hist(wt, breaks = 50)                  # look for extreme weights
ess / length(wt)                       # ESS as a fraction of original N
```
A large ESS reduction or extreme weights = poor overlap. MAIC **cannot extrapolate**, so poor overlap means bias and unstable variance — there's no fixing it by reweighting harder. Report ESS and the histogram always.

### 4. Estimate the within-study effect with robust SEs, then combine
Weighted GLM (probit link here) with sandwich SEs; combine the IPD studies by inverse-variance (fixed-effect) meta-analysis.

```r
library(sandwich)
fit <- glm(cbind(pasi75, 1 - pasi75) ~ trtc,
           data = uncover_ipd[study == "UNCOVER-2", ],
           family = binomial(link = "probit"), weights = wt)
d_AB   <- coef(fit)[["trtcIXE_Q2W"]]                       # probit difference B vs A
var_AB <- vcovHC(fit)["trtcIXE_Q2W", "trtcIXE_Q2W"]        # robust sandwich variance
# ... repeat for UNCOVER-3, then inverse-variance combine d_AB, var_AB
```

### 5. Form the anchored indirect comparison
```r
# AgD side: C vs A from FIXTURE (ordinary glm, no weights)
fit_agd <- glm(cbind(pasi75_r, pasi75_n - pasi75_r) ~ trtc,
               data = fixture_agd, family = binomial(link = "probit"))
d_AC <- coef(fit_agd)[["trtcSEC_300"]]; se_AC <- sqrt(vcov(fit_agd)[2, 2])

d_BC  <- d_AB - d_AC                       # anchored PAIC: B vs C in AgD pop
se_BC <- sqrt(se_AB^2 + se_AC^2)
```

### Unanchored MAIC (only if forced — single-arm / disconnected)
No common A arm: instead of a relative effect, predict the **absolute** outcome on B in the AgD population (intercept-only weighted glm), and contrast directly with the AgD absolute outcome on C. This invokes **conditional constancy of absolute effects** — needs *all prognostic and effect-modifying* covariates, is untestable, and gives much larger/different estimates than anchored. Flag the elevated decision risk. The book shows the anchored estimate (probit diff 0.39) and unanchored (1.13) diverging sharply — a reminder of how much rides on the much stronger assumption.

### MAIC's structural limits (state them in any report)
- Estimable **only** in the AgD study population — not an arbitrary target population.
- **Two-study** only — doesn't synthesise a network; separate MAICs against different AgD studies live in different, non-comparable populations and reuse the IPD.
- Can't extrapolate; sensitive to overlap.
If any of these bite (target ≠ AgD population, network > 2 studies), the answer is ML-NMR, not a more elaborate MAIC.

## STC — outcome regression, and the trap

STC fits a regression in the IPD and predicts into the AgD population. The **common "plug-in means" form substitutes the AgD mean covariates into the model** — and is **biased** when:
- the model is **non-linear** in covariates (aggregation bias — a function of the mean ≠ the mean of the function), or
- the effect measure is **non-collapsible** (log OR, log HR) — the conditional effect produced isn't compatible with the marginal effect from the AgD study.

Both are exactly the HTA-relevant cases. Don't use plug-in-means STC with an OR/HR outcome.

**Use G-computation STC instead** (Remiro-Azócar 2022): simulate individuals from the AgD covariate distribution, predict each one's outcome from the IPD-fitted model, and average to a proper **marginal** effect — avoiding both biases and capturing uncertainty correctly (R code is in that paper's supplement). The older simulation STC (Caro & Ishak) had the right idea but fixed the simulated sample size to the AgD N, adding avoidable simulation noise.

STC shares MAIC's structural limits: two-study, AgD-population-only. The "MAIC has fewer assumptions" claim is a myth — MAIC's matched moments and chosen scale imply an outcome model linear in those moments; the assumptions are implicit, not absent.

## When MAIC/STC is legitimately the right call
A two-study indirect comparison where the AgD study population genuinely *is* the decision target population, and you want a quick, transparent analysis. There MAIC is reasonable and well-understood. Outside that — any time the target population differs, or the network has more than two studies — move to ML-NMR (`references/ml-nmr-multinma.md`).
