# Multilevel (clustered) imputation

> Sources: van Buuren, *Flexible Imputation of Missing Data*, 2nd ed. (2018), Chapter 7
> ("Multilevel multiple imputation"), especially §7.5 (multilevel FCS), §7.8 (level-2
> variables) and §7.10 ("Guidelines and advice", worked examples §7.10.1–7.10.7, recipes
> §7.10.8, Tables 7.5–7.6). <https://stefvanbuuren.name/fimd/ch-multilevel.html>, verified
> against the online edition 3 July 2026. The §7.10 advice itself builds on Table 6 of
> Grund, Lüdtke & Robitzsch (2018). Worked example throughout is the `brandsma` dataset
> bundled with `mice` (pupils nested in schools `sch`), after Snijders & Bosker (2012).

Use this whenever rows are nested in clusters (pupils in schools, patients in hospitals,
repeated observations within a subject) **and** a variable with missing values is itself part
of, or related to, that multilevel structure. If the missingness is unrelated to the clustering
and the analysis model is itself single-level, the standard workflow in SKILL.md is enough.

## The core idea

Single-level imputation methods (`pmm`, `cart`, `logreg`, ...) ignore the clustering, which can
bias variance components and standard errors in the eventual multilevel analysis even if the
fixed effects come out roughly right. The `2l.*` family of methods imputes while accounting for
the cluster structure, either through fully conditional specification (FCS, iterating variable-
by-variable like ordinary `mice`, but each step uses a mixed model — FIMD §7.5) or joint
modeling (`jomoImpute`, `panImpute`, which impute several variables at once from one
multivariate mixed model — FIMD §7.4).

## Predictor matrix codes for multilevel imputation

This is the part that looks cryptic the first time. In `make.predictorMatrix(dat)`, instead of
just 0/1, multilevel methods read specific integer codes in the row for the target variable
(semantics per FIMD §7.10.2 and §7.10.6):

| Code | Meaning |
|---|---|
| `-2` | This column is the cluster/group identifier. Required in the row of every variable imputed with a `2l.*` method. |
| `1` | Ordinary fixed-effect predictor (the default for any 0/1 you set yourself). |
| `2` | Include as both a fixed effect *and* a random slope. |
| `3` | Include the predictor *and* its disaggregated cluster mean (contextual effect) as fixed effects. |
| `4` | Include the predictor, its cluster mean, *and* a random slope — all three. FIMD §7.10.7 warns the cluster mean and random effects are nearly linearly dependent, causing slow convergence and unstable estimates; often only the cluster means (code `3`) are included, or predictors are rescaled as deviations from cluster means. |

```r
d <- brandsma[, c("sch", "lpo", "iqv")]
pred <- make.predictorMatrix(d)
pred["lpo", ] <- c(-2, 0, 3)   # lpo imputed from iqv + cluster means of iqv
pred["iqv", ] <- c(-2, 3, 0)   # iqv imputed from lpo + cluster means of lpo

imp <- mice(d, pred = pred, meth = "2l.pmm", m = 10, maxit = 20,
            seed = 1, print = FALSE)
```

Adding the cluster means improves compatibility among the conditionally specified imputation
models (FIMD §7.10.2, referring back to §7.5.1).

## Which `2l.` method (and which package provides it)

| Method | Package | Use for |
|---|---|---|
| `2l.pmm` | **miceadds** | Level-1 continuous variable, random intercepts (and optionally slopes). FIMD §7.10.2's advice for the missing level-1 predictor case — donor-based, so stays in-range like ordinary `pmm`. Fitted via `lme4::lmer()`; `donors = 5` by default. |
| `2l.norm` | mice | Level-1 continuous, parametric normal draws; allows heterogeneous (heteroscedastic) within-cluster error variance. Otherwise prefer `2l.pmm`. |
| `2l.pan` | mice (needs `pan`) | Level-1 continuous under homoscedastic normal errors; FIMD §7.10.2 notes it is also a good choice when residuals are close to normal and within-cluster error variances are similar. |
| `2l.bin` / `2l.lmer` | mice | Level-1 binary variable (logistic mixed model) / lme4-based continuous alternative. |
| `2l.groupmean` | **miceadds** | Not really an imputation method — derives the cluster mean of a (possibly partially imputed) variable on the fly (used this way in FIMD §7.10.5 and §7.10.7). Builds the cluster-mean predictor for *other* variables' imputation models, alongside passive imputation for further derived terms. |
| `2lonly.pmm`, `2lonly.norm` | mice | A variable that is missing for an entire cluster at once (a true level-2 variable, e.g. school-level policy). Aggregates level-1 predictors automatically, then imputes at the cluster level (FIMD §7.8, §7.10.4). |
| `panImpute` / `jomoImpute` | **mitml** (also callable from `mice` as a block method, FIMD §7.10.2/§7.10.4) | Joint (not FCS) imputation of several variables together from one multivariate mixed model. Useful when several level-1 variables are missing simultaneously; categorical variables are handled naturally by `jomoImpute`. |

If a method string errors with "could not find function mice.impute.2l.pmm", the `miceadds`
package isn't loaded — `library(miceadds)` is required for `2l.pmm`, `2l.binary`, and
`2l.groupmean`.

`mitml` is a smaller, faster-moving companion package than `mice` itself, and its argument
names have changed before: `testEstimates()`'s `var.comp` argument was deprecated and replaced
by `extra.pars` in mitml 0.4-0 (January 2021; confirmed against the current CRAN source, where
`var.comp` is still accepted via a deprecation shim). If you're not certain a `mitml` call
matches its current API, a quick web search beats copying syntax from memory or from an older
source — the FIMD text itself still uses the pre-0.4-0 `var.comp` spelling.

## Should I add cluster means?

Generally yes (FIMD §7.5.1). Including the cluster mean of a level-1 predictor alongside its
raw value (code `3`) markedly improves the imputation in models where the analysis itself
distinguishes within- and between-cluster effects (a "contextual" model, FIMD §7.10.3), and
does little harm even when it doesn't. The main caveat: in *very* small clusters, the manifest
(raw, calculated) cluster mean can be an unreliable, biased stand-in for the true cluster
effect — in that situation, joint modeling approaches that treat the cluster mean as a latent
variable (shrunk appropriately) are more principled, but `2l.pmm` with disaggregated means is
still a reasonable, widely-used default.

## Worked pattern: random intercept model with one missing level-1 predictor (FIMD §7.10.2)

```r
d <- brandsma[, c("sch", "lpo", "iqv")]
pred <- make.predictorMatrix(d)
pred["lpo", ] <- c(-2, 0, 3)
pred["iqv", ] <- c(-2, 3, 0)
imp <- mice(d, pred = pred, meth = "2l.pmm", m = 10, maxit = 20, seed = 1, print = FALSE)

library(lme4)
fit <- with(imp, lmer(lpo ~ iqv + (1 | sch), REML = FALSE))
summary(pool(fit))

# Variance components aren't part of pool()'s default output; get them via mitml
library(mitml)
testEstimates(as.mitml.result(fit), extra.pars = TRUE)$extra.pars
# NB: mitml renamed this argument from `var.comp` to `extra.pars` in v0.4-0
# (2021); `var.comp = TRUE` still works via a deprecation shim, but
# `extra.pars` is the current name and the one to default to.
```

## Worked pattern: missing level-2 (cluster-level) predictor (FIMD §7.10.4)

```r
d <- brandsma[, c("sch", "lpo", "iqv", "den")]   # den = school denomination, level-2
meth <- make.method(d)
meth[c("lpo", "iqv", "den")] <- c("2l.pmm", "2l.pmm", "2lonly.pmm")

pred <- make.predictorMatrix(d)
pred["lpo", ] <- c(-2, 0, 3, 1)
pred["iqv", ] <- c(-2, 3, 0, 1)
pred["den", ] <- c(-2, 1, 1, 0)

imp <- mice(d, pred = pred, meth = meth, m = 10, maxit = 20, seed = 1, print = FALSE)
```

FIMD's advice for a level-2 target: include aggregates of all level-1 variables in the
cluster-level imputation model — `2lonly.norm` and `2lonly.pmm` add the means of all level-1
variables as predictors automatically, then follow single-level rules at level 2. `2lonly.pmm`
keeps imputations on the original (e.g. four-point) scale; a genuinely categorical method via
`jomoImpute` is the alternative if the linearity assumption behind matching on a predictive
mean is uncomfortable.

## Random slopes (FIMD §7.10.6)

If the analysis model has a random slope (`(1 + iqv | sch)`), the imputation model for that
predictor should generally include the cluster mean *and* the random slope (code `4`), and it's
good practice to center level-1 variables on their grand mean first — the random-slopes model
is not invariant to a shift in origin of the predictors, and FIMD reports that grand-mean
centering reduces instability warnings and improves speed; van Buuren recommends scaling
level-1 variables in deviations from their means for imputation purposes:

```r
d <- brandsma[, c("sch", "lpo", "iqv")]
d$lpo <- as.vector(scale(d$lpo, scale = FALSE))   # center on grand mean

pred <- make.predictorMatrix(d)
pred["lpo", ] <- c(-2, 0, 4)
pred["iqv", ] <- c(-2, 4, 0)

imp <- mice(d, pred = pred, meth = "2l.pmm", m = 10, maxit = 20, seed = 1, print = FALSE)
# remember to back-transform lpo (add the mean back) before/while analyzing if the
# original scale matters for interpretation
```

Inverting the random-slopes model to impute the predictor gives reasonable fixed effects and
intercept variance, but slope-variance estimates can be unstable and biased in small samples
(Grund et al. 2016, cited in FIMD §7.10.7); it is nonetheless the currently preferred FCS
approach unless the slope variance itself is the estimand.

## Interactions in multilevel imputation models (FIMD §7.10.5, §7.10.7)

There's no fully satisfactory automatic solution for interactions under FCS. The practical
approach (passive imputation, extended to the multilevel case) is to explicitly create every
interaction and cluster-mean term the analysis model needs as its own column, impute it
passively (cluster means via `2l.groupmean`), and make sure the visit sequence updates
dependents after their inputs change. This gets verbose fast — for models with several
interactions, build the predictor matrix and derived-variable formulas systematically rather
than by hand, and double check that no interaction term involving the variable currently being
imputed appears on the predictor side of its own equation (FIMD deletes those entries
explicitly).

## Recipes (FIMD §7.10.8, Tables 7.5 and 7.6)

**For an incomplete level-1 target (Table 7.5):**
1. Define the most general analysis model to be applied to the imputed data.
2. Select a `2l` method that imputes close to the observed data (`2l.pmm` is the safe default).
3. Include all level-1 variables as predictors.
4. Include the disaggregated cluster means of all level-1 variables.
5. Include all level-1 interactions implied by the analysis model.
6. Include all level-2 predictors.
7. Include all level-2 interactions implied by the analysis model.
8. Include all cross-level interactions implied by the analysis model.
9. Include predictors related to the missingness and to the target.
10. Exclude any term that involves the target itself.

**For an incomplete level-2 target (Table 7.6):**
1. Same first step — define the most general analysis model.
2. Select a `2lonly` method that imputes close to the observed data.
3. Include the cluster means of all level-1 variables.
4. Include the cluster means of all level-1 interactions.
5. Include all other level-2 predictors.
6. Include interactions among level-2 variables.
7. Include predictors related to the missingness and to the target.
8. Exclude any term involving the target itself.

The recipes follow the inclusive strategy of Collins, Schafer & Kam (2001) and extend the
predictor-selection strategy of FIMD §6.3.2 to multilevel data. Including every interaction
implied by a rich analysis model can blow up the number of parameters fast, especially with
categorical variables — FIMD itself advises care in selecting the interactions that matter most
for the application. Two further points from §7.10.8: auxiliary variables outside the
substantive model (e.g. a highly correlated pre-test) belong in the imputation model even
though they're not in the analysis model, and convergence monitoring is especially important
with many random slopes — over-parameterization almost always shows up in the variance part of
the model, so simplify random slopes / the level-2 structure if the multilevel routines warn.
