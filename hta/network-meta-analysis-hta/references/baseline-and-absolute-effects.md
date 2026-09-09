# From relative effects to the absolute numbers an economic model needs

> Sources: *Bayesian Modelling in Health Technology Assessment* — Baio (Chapman & Hall/CRC, 2026),
> Ch. 6 (aggregate-level data and evidence synthesis) and Ch. 7 (network meta-analysis), whose
> influenza-prophylaxis example combines two independent evidence streams into one economic model.
> Anchored to <https://github.com/giabaio/bmhta-examples> (MIT) commit `d2a6298`, files `06-ald/`
> and `07-nma/`; accessed 2026-09-09. Methods framing follows NICE DSU TSD 5 (evidence synthesis in
> the baseline model), TSD 6 (embedding synthesis in probabilistic CEA) and TSD 3 (baseline risk).
> CRAN was unreachable from the authoring environment — check package signatures against the
> installed version.

`SKILL.md` says the relative effects are applied "to a baseline to get each treatment's absolute
effect". This file is that sentence, worked out — because where the baseline comes from, and how it
is combined, decides the answer at least as much as the network synthesis does.

## Why a relative effect is not enough

An NMA gives contrasts: `d_t`, the effect of treatment `t` against the network reference, on the
linear-predictor scale. An economic model needs **absolute** quantities — the probability of the
event under each treatment, the survival curve, the number of people in each state. A log odds ratio
of −0.7 implies a completely different absolute benefit at a baseline risk of 5% than at 40%, and
the ICER moves accordingly.

So an HTA needs two things synthesised, not one:

1. the **relative effects**, from the randomised evidence — this is what the NMA is for, and
   randomisation is what makes it credible;
2. the **baseline** (natural history, control-arm risk, background event rate) for the population the
   decision is about.

These come from different evidence and deserve different models. Conflating them — reading the
absolute risk off the trials' control arms because they are in the same dataset — is the standard
mistake.

## Where the baseline comes from

**The baseline must describe the decision population, not the trials.** Trial control arms are
selected, protocolised and often healthier or more closely monitored than the population the
decision covers. Using them as the baseline transports trial-specific absolute risk into a national
decision. Candidate sources, roughly in order of preference for a decision population: a registry or
routine dataset for that population; an observational cohort; the control arms of the synthesised
trials, adjusted or acknowledged as a limitation; a single "most representative" trial's control arm
(weakest, and needs justifying).

Whatever the source, synthesise it properly rather than taking a point estimate. Several control
arms or several cohorts pool naturally as a random-effects binomial-logistic model — the same
partial-pooling machinery as the relative-effects synthesis, applied to the absolute scale:

```r
baseline_fit <- brm(
  events | trials(n) ~ 1 + (1 | study),
  family = binomial(),
  data   = baseline_studies,
  prior  = c(prior(normal(0, 1.5), class = "Intercept"),
             prior(exponential(2.31), class = "sd"))   # Pr(tau > 1) = 0.1; see brms core-workflow
)
```

Here the **pooled-vs-predictive choice matters and is easy to get wrong.** The posterior of the mean
baseline log-odds narrows as studies accumulate; the *predictive* distribution for a new exchangeable
population cannot narrow below the between-study SD. If the decision population is not one of the
synthesised studies — which is the usual case — the predictive distribution is the honest input.
Using the pooled mean instead understates decision uncertainty, and therefore understates EVPI: it
makes further research look less valuable than it is. State which you used.

## Combining on the link scale

The combination happens on the **linear predictor**, then back-transforms — never by multiplying
probabilities or averaging on the natural scale:

```
logit(p_t) = logit(p_baseline) + d_t          # d_reference = 0
p_t        = plogis(logit(p_baseline) + d_t)
```

Do this **per posterior draw**, so the whole thing is a transformation of draws rather than of
summaries:

```r
base_draws <- as_draws_df(baseline_fit)$b_Intercept        # S draws, logit scale
d_draws    <- as.matrix(nma_relative_effects)              # S x T, same S
p          <- plogis(base_draws + cbind(0, d_draws))       # S x (T+1) absolute probabilities
```

`multinma` does this for you: `predict()` on a fitted `stan_nma` accepts a baseline specification and
returns absolute predictions per treatment, propagating both sources of uncertainty. Prefer it when
the baseline can be expressed the way that function wants; do it by hand on the draws when the
baseline comes from a separate model, as above. Check the argument names against the installed
version.

**Preserve the joint posterior across treatments.** The `p_t` are correlated — through the shared
baseline, and through the shared network structure that makes every `d_t` depend on overlapping
trials. Two consequences:

- Never re-sample each treatment's absolute effect independently from its own marginal summary
  (a mean and an interval, or a fitted Beta). That discards the correlation and will mis-state every
  incremental quantity downstream, usually by *over*stating the uncertainty in the difference.
- Carry the full `S × T` matrix through to the economic model, and keep row `i` meaning the same
  posterior draw everywhere. This is the same pairing rule `bayesian-cea-r-hta` states for cost and
  effect draws, applied one step upstream.

## Multiparameter evidence synthesis

The general case: an economic model needs several parameters, they are informed by different and
partly overlapping evidence streams, and some of them share parameters. Synthesising them in one
coherent model rather than estimating each in isolation means the correlations induced by shared
evidence survive into the PSA — which is the whole argument for doing it.

Two structural questions decide the implementation:

- **Do the modules share a parameter?** If the streams are linked only *functionally* — one supplies
  the baseline, another the relative effect, and they are combined arithmetically after estimation —
  then fitting them separately and combining draws is exactly equivalent to one joint model, and
  much easier in a modern stack. This is the common case and the sensible base case.
- **Or are they genuinely exchangeable with each other?** If, say, the baseline studies and the trial
  control arms are assumed to come from a common distribution — sharing a mean and a heterogeneity
  parameter — then the modules share parameters, and only a single model gets it right. Two separate
  fits plus arithmetic is *not* equivalent here. In practice that means putting both evidence sets in
  one `multinma` network, or writing the model in Stan.

Being explicit about which case you are in is the substance. The book's low-level BUGS formulation
makes parameter-sharing visible in a way a two-call workflow hides; the model structure is the part
worth extracting, not the JAGS.

Parameters with **no in-model data** — a unit cost, a utility, a duration taken from the literature —
can be given informative priors inside the same synthesis and monitored. The synthesis then doubles
as the PSA generator: everything the economic model needs comes out of one posterior, already
correlated where it should be. This is what TSD 6 means by embedding synthesis in the probabilistic
analysis, and it is cleaner than generating relative effects Bayesianly and then attaching
independent parametric PSA distributions to everything else.

## Baseline risk as an effect modifier

Baseline risk is the awkward case for `SKILL.md`'s rule that only effect modifiers belong in a
meta-regression. It is a study-level summary of prognostic factors — so by that rule it should not
enter — yet it frequently acts as a proxy effect modifier, and it is exactly the covariate a reviewer
raises when an effect is transported to a higher- or lower-risk decision population.

Adding a baseline-risk interaction re-centres the pooled effect as the effect **at average baseline
risk** and lets it vary with risk. The catch is **regression to the mean**: the observed baseline
appears on both sides of the regression, so its measurement error is shared with the outcome and a
naive regression of observed effect on observed baseline risk is biased toward finding a
relationship. The correct treatment models the true baseline as a latent variable (a hierarchical or
errors-in-variables specification) rather than regressing on the observed control-arm rate. NICE DSU
TSD 3 covers this; do not fit the naive version.

## Present it as a scenario set

Because the baseline is a judgement about relevance rather than a purely statistical question,
report a small scenario set rather than a single number:

1. **Base case** — the baseline source judged most relevant to the decision population, with the
   pooled-vs-predictive choice stated.
2. **Pooled baselines** — all available baseline evidence synthesised together, as a check on how
   much the source choice drives the result.
3. **Baseline-risk adjusted** — where the relative effect plausibly varies with risk.

If the decision is the same across all three, say so; that is a robustness finding. If it is not,
the baseline is a key driver and belongs in the sensitivity analysis and the limitations, not buried
in an appendix.

## Hand-off

The output of this step is absolute, per-treatment quantities as posterior draws — the input to
`decision-modelling-hta` (transition probabilities), `survival-analysis-hta` (per-arm curves), or
directly to `bayesian-cea-r-hta` where the model is simple enough to compute costs and effects on the
draws. Keep the draws paired and in the same order throughout.
