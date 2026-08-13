# Meta-analysis models

What changes relative to `core-workflow.md` when using brms to fit a random-effects meta-analysis or meta-regression (rather than `metafor`/`meta`-package alternatives) — relevant for systematic-review work where a Bayesian random-effects model, or a more flexible meta-regression than off-the-shelf packages allow, is wanted.

## Specification

- The standard brms random-effects meta-analysis pattern treats each study's known standard error as fixed and known, via `y | se(known_se) ~ 1 + (1 | study)`:
  - `y` is the study-level effect estimate (e.g. log hazard ratio, log odds ratio, mean difference)
  - `se(known_se)` tells brms the known sampling SE for each study is fixed (not estimated) — confirm this column genuinely holds standard errors, not variances or confidence-interval widths (a common transcription error when pulling from a systematic-review extraction table)
  - `(1 | study)` gives the between-study random effect — its SD is the between-study heterogeneity (analogous to τ in a frequentist random-effects model)
  - Add `sigma = TRUE` to `se()` (i.e. `se(known_se, sigma = TRUE)`) if you want to additionally estimate residual variance beyond the known sampling error, rather than treating sampling error as the only source of within-study variance — confirm which of these two is intended, since they imply different models.
- For meta-regression, add study-level moderators to the fixed-effects part of the formula (`y | se(known_se) ~ 1 + moderator + (1 | study)`) — same considerations on small-sample moderator effects as in `multilevel.md` apply, since the number of "groups" here is the number of studies, often small.

## Priors

- The between-study SD (`sd(study)`) is frequently the parameter the whole analysis is *about* — flag any meta-analysis where this prior hasn't been set deliberately. With a typical systematic review (often well under 20 studies), this parameter is weakly identified by the data, and the prior will visibly shape the heterogeneity estimate. There is a dedicated literature on this exact choice (e.g. Williams, Rast & Bürkner on weakly-informative priors for τ, which motivates a half-Cauchy or half-normal rather than a flat prior) — point to it rather than picking a scale arbitrarily, and sense-check the chosen scale against how much spread the raw study estimates actually show.
- A prior predictive check here is particularly informative: simulate study-level effects from the prior and check they span a plausible range for the outcome's effect-size scale (e.g. log hazard ratios that exponentiate to absurdly large or small hazard ratios indicate a prior that's too diffuse).

## Diagnostics & PPC

- Same Rhat/ESS/divergence thresholds as `core-workflow.md` — note that with few studies, divergences related to the funnel geometry of `(1 | study)` are common; the non-centred-parameterisation guidance in `multilevel.md` applies directly.
- PPC for meta-analysis is less about reproducing a marginal distribution and more about checking study-level shrinkage looks sensible: extreme/imprecise studies should be pulled toward the pooled estimate; very precise studies should barely move. Plot study-level posterior estimates against raw study estimates to sense-check this.

## Reporting

- Report the between-study heterogeneity (posterior summary of `sd(study)`, ideally translated to an I²-like quantity for a frequentist-familiar audience) alongside the pooled effect — for a Bayesian random-effects model this is usually as important a result as the pooled estimate itself.
- If this analysis feeds into a PRISMA-style review write-up, report it alongside (not as a replacement for) the standard forest plot conventions reviewers/readers expect, even though `tidybayes`/`ggplot2` output from brms won't look identical to `metafor`'s default forest plot.
