# Review output format

When reviewing brms code, always produce **both** of the following — not one or the other.

## 1. Inline comments

Add `# REVIEW:` comments directly above the line/argument they refer to, in the code itself. Keep each one short — a flag plus the one-line reason, not a re-explanation of the whole workflow stage. Example:

```r
# REVIEW: no explicit prior set for fixed effects — brms defaults are flat here.
# Either justify the default or set a weakly-informative prior (see core-workflow.md).
fit <- brm(y ~ x1 + x2, data = df, family = gaussian())
```

Reserve inline comments for issues tied to a specific line. General workflow gaps (e.g. "no posterior predictive check anywhere in the script") belong in the structured report below, not bolted onto an arbitrary line.

## 2. Structured report

Organise by the workflow stages from `core-workflow.md`, using this template:

```markdown
# brms review: <script/model name>

## Summary
[1-3 sentences: overall verdict — solid, fixable, or has a blocking issue]

## Specify
[Family/link/formula appropriateness for this outcome]

## Priors
[Explicit & justified? Prior predictive check run?]

## Recover
[For non-trivial models: was the model checked against simulated data with known parameters? N/A for routine GLMs where this is overkill.]

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
no PPC), then polish (style, comments)]
```

Use `N/A` for stages that genuinely don't apply (e.g. "Compare" if there's only one model and no comparison is being made) rather than omitting the heading — an omitted heading reads as "not checked," not "not applicable," and the two are different findings.

## What counts as a blocking issue vs. a flag

Treat as **blocking** (should be fixed before the results are used for anything):
- Unresolved divergent transitions
- Rhat ≥ 1.01 or very low ESS without follow-up
- Model comparison run on non-comparable data (different rows/likelihoods)
- A censoring indicator that's plausibly miscoded (check against the data source's convention)

Treat as a **flag** (worth raising, not necessarily blocking):
- No explicit prior set, with no comment indicating that's deliberate
- No prior predictive check
- No fake-data/recovery check on a non-trivial model (hurdle, censored survival, few-group multilevel, small-study meta-analysis)
- No posterior predictive check, or only the default density overlay where something more targeted (zero-counts, group-level fit, survival curves) would be more informative
- A high `adapt_delta` with no confirmation that divergences actually reached zero afterwards (it's the unverified resolution that's the flag — see below)
- Missing `seed` for reproducibility
- Style/structure issues (see `coding-conventions.md`)

**Explicitly *not* a flag:** a high `adapt_delta` (0.95–0.99) by itself. In funnel-prone models — few-group hierarchical models, small-study meta-analysis — raising it is the normal, correct thing to do, not evidence of a patched-over problem. Flagging a high value as inherently suspect produces false positives on perfectly sound models; the legitimate concern is only whether divergences were checked and resolved after the change.

This distinction matters for how the summary verdict is framed — don't bury a blocking issue in a long list of minor flags, and don't inflate a style nitpick (or a legitimately high `adapt_delta`) to the same register as a biased posterior.
