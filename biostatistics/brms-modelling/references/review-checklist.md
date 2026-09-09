# Reviewing an existing brms model

How to review brms code someone else wrote: what to read first, how to tell a documented choice from a defect, what to produce, and the audit the workflow table in `SKILL.md` doesn't cover (custom Stan code).

## Before you report

**Read the code before you read the output.** Read the whole script, not the `brm()` call. The prior, the `control` settings, the data preparation and the comments justifying them usually sit in three different places — a prior that looks unset in the call is often built into a `prior_spec` object forty lines up, and the `filter()` that breaks a `loo_compare()` is rarely next to it. Where the model uses `stanvars`, a `custom_family()`, or `mi()`/`me()`/`mo()` terms, read the generated Stan code as well (`stancode(fit)`, or `make_stancode(formula, data, family, prior, stanvars)` when you don't have the fit): in those cases the R call is not the model.

**Check the record before reporting.** Where the work has one — a decision log, a plan, an issue tracker, a statistical analysis plan, prior review artefacts — search it for the finding before you write it up, and say what you searched. A deviation that is documented, ruled on and justified is a conforming outcome, not a defect, and reporting it as one costs the reader more than it saves. Where there is no such record, say so: "not addressed anywhere I could find" is itself part of the finding. This applies to substantive findings, not to every observation — do not spend a search on a typo. This retires a deviation from a plan, a convention or a prior recommendation; a wrong number, an invalid inference, or a defect in something reported stays a finding however well documented — cite the ruling and report it anyway, because a record that acknowledges a defect documents it, it does not fix it.

**Size the finding before you grade it.** Say what the finding moves, and by how much, before assigning severity: the estimate, the decision, the reported number, the failure rate, the runtime. A defect in a path nothing consumes — dead code, an unreported exploratory branch, a value computed and discarded — is not the same as one in a result somebody acts on, and grading them alike makes the whole list harder to act on. Note the trap in the other direction: anything pre-specified and reported *is* a result somebody acts on, sensitivity and scenario analyses included, so "it's only a sensitivity analysis" is not a reason to downgrade.

**A documented choice is not a defect.** For a brms script the documentation is usually a comment — `coding-conventions.md` requires the *why* of a prior or a non-default `control` value to be in one — or a line in the commit or PR message. A deviation from this skill's guidance that the script names, explains and accepts (flat priors to reproduce a frequentist benchmark; `adapt_delta = 0.99` because the model is a five-group hierarchy) is a choice. Report it only if the stated reason is wrong on its own terms, and then argue with the reason, not with the line. An undocumented deviation is a finding — and the finding is often the missing justification rather than the choice itself.

## Choose the output mode before you start

A review produces a structured report, and — only when you have a working copy you have been asked to modify — inline `# REVIEW:` comments as well.

- **Working copy, edits invited** (the branch is checked out and the user asked for a review of the code in it): produce both. Inline comments carry the line-specific findings; the report carries everything else.
- **Read-only** — an unchecked-out branch, a pasted snippet, a file you were told not to touch, a fitted object handed over without its script: produce the report only, and anchor each finding to `path/to/file.R:LINE` with a short quoted line where the number alone won't identify it. Don't write comments into files you weren't asked to modify, and don't reconstruct the script elsewhere in order to have somewhere to put them.
- **PR review**: inline comments become review comments on the diff, so they can only land on lines the diff touches. A finding about unchanged code — the priors in a file the PR didn't open, a PPC missing from the whole script — goes in the report body, not on the nearest available line.

If it isn't clear which mode applies, assume read-only and say so in one line at the top of the report. Producing a report is never wrong; writing into files you weren't asked to touch is.

## 1. Inline comments

Skip this section entirely in read-only mode. Where it does apply, add `# REVIEW:` comments directly above the line/argument they refer to, in the code itself. Keep each one short — a flag plus the one-line reason, not a re-explanation of the whole workflow stage. Example:

```r
# REVIEW: no explicit prior set for fixed effects — brms defaults are flat here.
# Either justify the default or set a weakly-informative prior (see core-workflow.md).
fit <- brm(y ~ x1 + x2, data = df, family = gaussian())
```

Reserve inline comments for issues tied to a specific line. General workflow gaps (e.g. "no posterior predictive check anywhere in the script") belong in the structured report below, not bolted onto an arbitrary line.

## 2. Structured report

The report is the deliverable in every mode. Organise it by the workflow stages from `core-workflow.md`, using this template:

```markdown
# brms review: <script/model name>

## Summary
[1-3 sentences: overall verdict — solid, fixable, or has a blocking issue]

## Specify
[Family/link/formula appropriateness for this outcome]

## Priors
[Explicit & justified? Prior predictive check run? Any `stanvars`-injected prior reported alongside the `prior` argument?]

## Recover
[For non-trivial models: was the model checked against simulated data with known parameters? Drop this heading for routine GLMs, where the check is overkill.]

## Fit
[Backend, chains, iter, seed, control settings — anything missing or unexplained]

## Diagnose
[Rhat / ESS / divergences — were they checked? Were thresholds met?]

## Check
[Posterior predictive checks — run? appropriate to the outcome type?]

## Compare
[If model comparison is present: comparability of data, Pareto-k, appropriate CV scheme]

## Report
[If this feeds a write-up: is it reproducible from what's reported?]

## Priority fixes
[Ranked list — blocking issues first (e.g. unresolved divergences, mismatched
model-comparison data), then defensibility gaps (missing prior justification,
no PPC), then polish (style, comments). Give each one what it moves and by how
much, per "size the finding" above; where you genuinely can't size it, say so
rather than assigning a severity by feel]
```

Give every heading the change has a surface for one line at minimum, and drop the ones it doesn't: a file of helper functions with no `brm()` call in it has no Fit or Diagnose surface, and nine headings reading `N/A` on a change that touched three of them buries the three that matter. The distinction to preserve is between "checked, nothing to report" and "not checked" — those are different findings, so where a stage exists but you couldn't check it (no fitted object, data not available, the fit predates the branch) say that in the line rather than leaving the heading blank or deleting it. On a large change, keep the headings you have findings under and fold the clean ones into a single line under Summary.

## Custom Stan code: `stanvars` and hand-written `target +=`

`stanvars = stanvar(...)` injects raw Stan into the generated model — a bespoke prior, a hand-rolled likelihood contribution, a constant, a helper function. It is how a real brms model carries a prior brms can't express through `prior()`, and it sits outside everything else in this checklist, because with a stanvar present the R call no longer describes the model. Whenever `stanvars` (or `custom_family()`) appears, print `stancode(fit)` — or `make_stancode()` with the same arguments — and work through these six checks before filling in the report headings.

**Does the injected density match its comment?** Read the Stan line against the sentence above it, both directions. Two failures recur. (a) A hand-expanded kernel that drops a normalising term which is not actually constant: `target += -0.5 * square((y - mu) / sigma);` omits `-log(sigma)`, so it is proportional to a normal density only when `sigma` is data — with `sigma` a parameter it biases the posterior for `sigma`. Write `normal_lpdf(...)`, or `normal_lupdf(...)`, which drops only terms free of parameters, rather than hand algebra. (b) A density placed on a transformed parameter — `target += lognormal_lpdf(square(sigma) | 0, 1);` — with no Jacobian adjustment for the transform, so the implied prior on `sigma` is not the one the comment claims. Stan's Jacobian warning fires on `~` statements, not on `target +=`, so nothing flags this at compile time.

**Is it in the right block?** brms wraps the likelihood in `if (!prior_only)` inside the model block, and `stanvar(block = "likelihood")` is the way to put code inside that guard; `block = "model"` lands outside it. So a likelihood contribution declared in `block = "model"` is still evaluated when the model is refit with `sample_prior = "only"` — the prior predictive check quietly includes the data, and the check that was meant to expose an absurd prior can't. Priors go in `"model"`; anything that reads the outcome goes in `"likelihood"` — and check `position` in the same `stanvar()` call while you are there. Its default is `"start"`, which emits the code after `vector[N] mu = rep_vector(0.0, N);` but *before* `mu += Intercept;` and the group-level loop, so a likelihood term referencing `mu` compiles cleanly and silently scores against a vector of zeros; a likelihood contribution wants `position = "end"`. Read where the code actually landed in `stancode(fit)` rather than inferring it from the `block` argument.

**Is it invisible to `loo()`?** brms never reads a `log_lik` variable out of the generated-quantities block: `loo()` calls `log_lik.brmsfit`, which rebuilds the pointwise log-likelihood in R from `prepare_predictions()` and the family's own `log_lik` function, and hands that matrix to `loo::loo()` (checked against brms 2.23.0). A likelihood term added by hand through `target +=` is in neither, so `loo()`, `loo_compare()` and the Pareto-k diagnostics are computed on a likelihood that is not the model's. There are two routes out and only one of them goes through `brms::loo()`. For a `custom_family()`, supply the `log_lik` R method brms asks for — either the `log_lik` argument to `custom_family()` or a `log_lik_<familyname>()` function in the calling environment; `log_lik_custom()` resolves and calls it, so `brms::loo()` then scores the right likelihood. For a hand-written `target +=` on a standard family there is no such hook: writing `log_lik` in a `genquant` stanvar does *not* reach `brms::loo()`, which will keep silently returning the wrong number, so you have to pull those draws yourself and call `loo::loo()` on them outside brms. Failing either, treat model comparison as unavailable — a `loo_compare()` across models carrying hand-written likelihood terms is a blocking issue, not a caveat.

**Does it enter whatever key decides a cached fit is still current?** `brm(file = "models/fit.rds")` re-reads a stored fit and, with the default `file_refit = "never"`, never asks whether anything changed; pipeline caches (targets, memoise, a hand-rolled hash) are usually keyed on formula, data and `prior`. A `stanvars` argument is in none of those by default, so editing the injected prior and rerunning can silently hand back the old fit. Confirm that the cache key — or `file_refit = "on_change"` — actually sees the stanvar, and that the fit on disk was produced by the code now in the file.

**Does `get_prior()` / `default_prior()` still describe the model?** No, and this is the one that matters most. `default_prior()` (`get_prior()` is the older name for the same thing) enumerates only the priors brms itself manages, by class — `b`, `Intercept`, `sd`, `sigma`, `cor`, `simo` and so on — and `prior_summary(fit)` hands the same object back from the fit. A prior injected as a stanvar appears in neither. So a prior table generated from `prior_summary()` — including the one the write-up reports under `core-workflow.md` §7 — silently omits it; a prior-sensitivity analysis that varies the `prior` argument holds the stanvar prior fixed while claiming to have varied the priors; and a reviewer who reads only `default_prior()` output will report the model as using brms defaults for a parameter that has a hand-written prior. Reconcile every `target +=` in `stancode(fit)` against the reported prior specification, and require the stanvar prior to be written out in prose alongside it.

**Is it pinned to a version?** Stanvar code that references brms's internal symbols (`mu`, `b`, `Intercept`, `sd_1`, `r_1_1`, `N_1`) is coupled to how brms generated the code for that formula in that version; these names are not a stable API, and nothing warns when a new group-level term makes `r_1_1` refer to a different grouping factor. Record the brms version in the script, and re-read `stancode()` after any formula change or package upgrade.

## What counts as a blocking issue vs. a flag

Treat as **blocking** (should be fixed before the results are used for anything):
- Unresolved divergent transitions
- Rhat ≥ 1.01 or very low ESS without follow-up
- Model comparison run on non-comparable data (different rows/likelihoods)
- A censoring indicator that's plausibly miscoded (check against the data source's convention)
- A hand-written `target +=` whose density is wrong as written — a missing parameter-dependent normalising term, a missing Jacobian, a likelihood contribution outside the `prior_only` guard — or a `loo_compare()` over models with such a term

Treat as a **flag** (worth raising, not necessarily blocking):
- No explicit prior set, with no comment indicating that's deliberate
- No prior predictive check
- No fake-data/recovery check on a non-trivial model (hurdle, censored survival, few-group multilevel, small-study meta-analysis)
- No posterior predictive check, or only the default density overlay where something more targeted (zero-counts, group-level fit, survival curves) would be more informative
- A high `adapt_delta` with no confirmation that divergences actually reached zero afterwards (it's the unverified resolution that's the flag — see below)
- A `stanvars`-injected prior absent from the reported prior specification (see above) — it makes the reported specification incomplete rather than wrong
- A threshold, ranking or equivalence claim read off a posterior summary with no check that the margin exceeds that summary's Monte Carlo error (`core-workflow.md` §4)
- Missing `seed` for reproducibility
- Style/structure issues (see `coding-conventions.md`)

**Explicitly *not* a flag:** a high `adapt_delta` (0.95–0.99) by itself. In funnel-prone models — few-group hierarchical models, small-study meta-analysis — raising it is the normal, correct thing to do, not evidence of a patched-over problem. Flagging a high value as inherently suspect produces false positives on perfectly sound models; the legitimate concern is only whether divergences were checked and resolved after the change.

This distinction matters for how the summary verdict is framed — don't bury a blocking issue in a long list of minor flags, and don't inflate a style nitpick (or a legitimately high `adapt_delta`) to the same register as a biased posterior.
