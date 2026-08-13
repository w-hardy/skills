---
name: brms-modelling
description: Write, debug, and review Bayesian regression models fitted in R with brms (Bayesian Regression Models using Stan). Use any time brms code is being written or touched — model specification and formulas, prior choice and prior/fake-data predictive checks, brm() fitting arguments (backend, chains, iter, control/adapt_delta), convergence diagnostics (Rhat, ESS, divergences), posterior predictive checks (pp_check), model comparison (loo/PSIS, k-fold, loo_compare, Pareto-k), or reporting for a paper. Covers all model families — multilevel/hierarchical, GLMs, distributional (zero-inflated, hurdle, ordinal), survival/time-to-event, and meta-analysis — plus cross-cutting predictor terms like repeated-measures autocorrelation, monotonic effects (mo), smooths (s), and measurement error (me/mi). Trigger proactively whenever the user mentions brms, Stan-via-brms, or cmdstanr/rstan in an R modelling context, or pastes code with brm(), even without explicitly asking for a "review" or "help me write a model."
---

# brms modelling

This skill covers two equally-weighted jobs: **writing** new brms models and **reviewing** existing brms code. Both should be approached as a single end-to-end Bayesian workflow, not just a syntax check — a brms script can run without errors and still be statistically broken (e.g. silently divergent chains, an unjustified default prior, a model comparison run on non-comparable likelihoods).

## Why this matters

brms makes it dangerously easy to fit a model that *looks* fine — it returns a `brmsfit` object, `summary()` prints numbers, nothing throws an error — while hiding problems that matter: convergence failures, priors that are doing more work than intended, or model comparisons that aren't actually valid (e.g. comparing models fit to different numbers of observations after `drop_na()`). The point of this skill is to keep the full workflow — prior → recover → fit → diagnose → check → compare → report — in view, in both directions: when writing, walk through it; when reviewing, audit against it. Note that the workflow is iterative, not a one-pass checklist: as *Regression and Other Stories* (Gelman, Hill & Vehtari) puts it, you don't just fit models, you build them — expect to loop back and expand the model when a check fails, rather than running each stage once and stopping. This is the *Bayesian Workflow* frame (Gelman, Vehtari et al. 2020); `references/bayesian-workflow-sources.md` grounds each stage in its sources.

## Sources

- *Bayesian Workflow* — Gelman, Vehtari et al. (2020), arXiv:2011.01808; book-in-progress at <https://avehtari.github.io/Bayesian-Workflow/>.
- *Regression and Other Stories* — Gelman, Hill & Vehtari (CUP 2020); examples at <https://avehtari.github.io/ROS-Examples/>.
- *Bayesian Data Analysis*, 3rd ed. — Gelman, Carlin, Stern, Dunson, Vehtari & Rubin; free PDF at <https://sites.stat.columbia.edu/gelman/book/>.
- LOO/PSIS: Vehtari, Gelman & Gabry (2017), *Statistics and Computing* 27:1413–32.

## Step 0: Establish context

Before writing or reviewing, work out:

1. **Task type** — new model, or reviewing/debugging existing code? (Often both: "review this" frequently surfaces a fix that needs rewriting.)
2. **Backend** — look for `backend = "cmdstanr"` or `backend = "rstan"` in the code, or `options(brms.backend = ...)`. If absent and you're writing new code, default to `cmdstanr` (faster compilation, within-chain parallelisation via `threads = threading()`, the direction Stan development has moved) but ask if the user's environment doesn't have `cmdstanr` installed — don't silently assume. If reviewing code that already commits to a backend, respect that choice unless it's actively causing the problem under discussion.
3. **Model family** — see `references/model-families/` for family-specific considerations (multilevel/hierarchical, survival, distributional, meta-analysis, or plain GLM). A single model often combines more than one of these (e.g. a multilevel survival model) — read the relevant files for each that applies.

## The workflow

Use this as the backbone for both writing and reviewing. Full detail for each stage is in `references/core-workflow.md` — read it before doing substantive work, not just when something goes wrong.

| Stage | What it's for | Key question when reviewing |
|---|---|---|
| Specify | Formula, family, link function | Does the family match the outcome's data-generating process (counts → poisson/negbinomial, not gaussian; proportions bounded [0,1] → beta, not gaussian)? |
| Priors | `get_prior()`, set weakly-informative priors, prior predictive check | Are priors stated explicitly and justified, or left at brms defaults without comment? Has a prior predictive check been run? |
| Recover | Simulate data from known parameters, refit, confirm recovery | For non-trivial models, was the model ever checked against simulated data where the truth is known — or only against real data where it isn't? |
| Fit | `brm()` call: backend, chains, iter/warmup, `control` | Enough chains (≥4) and post-warmup draws to assess convergence? Has `seed` been set for reproducibility? |
| Diagnose | Rhat, ESS (bulk & tail), divergent transitions, treedepth | Were diagnostics actually checked, or just assumed because the function returned? |
| Check | `pp_check()`, residual diagnostics | Does the model reproduce key features of the observed data? |
| Compare | `loo()`, `loo_compare()`, k-fold, Pareto-k | Are models being compared on identical data/likelihoods? Are high Pareto-k values handled (refit, moment-matching) rather than ignored? |
| Report | `conditional_effects()`, `tidybayes`, `marginaleffects`, write-up | Could someone else reproduce this from what's reported (priors, sampler settings, software versions)? |

**When writing new code:** walk through every stage explicitly — don't jump straight to `brm()` with default priors and skip diagnostics. Produce code that runs the full chain, not just the fit.

**When reviewing existing code:** use the table as an audit checklist. Read `references/review-checklist.md` for the structured output format — this skill's reviews always produce both **inline comments** in the code (flagging the specific line/argument) and a **short structured report** summarising what's solid, what's risky, and what's missing, organised by workflow stage. Don't just say "looks fine" — every review should explicitly confirm or flag each stage in the table, even if briefly.

## Coding conventions

When writing or rewriting brms code, follow `references/coding-conventions.md` — tidyverse-style R, base-pipe (`|>`), explicit missing-data handling, modular/reusable functions, and comments that explain *why* a modelling choice was made (not just what the code does). This matters more for brms than typical data-wrangling code, because the *why* behind a prior or a `control` setting is exactly what a future reader (including you, six months on) needs to trust the model.

## Reference files

- `references/core-workflow.md` — priors, fake-data simulation/recovery, fitting, diagnostics (with concrete thresholds and what to do when they're violated), posterior predictive checks, model comparison
- `references/bayesian-workflow-sources.md` — how the stages hang together as the Gelman–Vehtari *Bayesian Workflow*, with the ROS and BDA3 ideas each stage leans on and citation shorthands for methods text
- `references/special-terms.md` — predictor-side features that cut across families: repeated measures and residual autocorrelation (`ar()`/`unstr()` etc.), monotonic effects (`mo()`), smooth terms (`s()`), measurement error and in-model imputation (`me()`/`mi()`)
- `references/model-families/multilevel.md` — group-level effects, partial pooling, non-centred parameterisation
- `references/model-families/survival.md` — time-to-event models in brms (`brmsfamily("cox")`, Weibull/lognormal AFT, censoring syntax)
- `references/model-families/distributional.md` — zero-inflated, hurdle, ordinal, and modelling auxiliary parameters (e.g. `sigma ~ ...`)
- `references/model-families/meta-analysis.md` — random-effects meta-analysis and meta-regression via brms
- `references/review-checklist.md` — the structured review report template and inline-comment conventions
- `references/coding-conventions.md` — R style conventions specific to brms scripts

Read the model-family file(s) relevant to the task in addition to `core-workflow.md` — the workflow table above is family-agnostic; the family files cover what changes within each stage for that family. Also read `special-terms.md` whenever the formula's right-hand side involves repeated measures/time, an ordinal predictor, a clearly non-linear continuous effect, or a covariate measured with error — these cut across families and are easy to miss because they're about the predictors, not the outcome's family.
