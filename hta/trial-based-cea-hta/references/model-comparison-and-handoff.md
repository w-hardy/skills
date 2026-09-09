# Comparing candidate models, and handing the draws downstream

> Source: BMHTA Ch. 5 (bmhta-examples @ `d2a6298`, `05-ild/ild.R`), which compares the three
> candidate models by DIC (both `pV` and `pD` penalties), adds WAIC and LOO-CV from monitored
> log-likelihood contributions, and model-averages with `BCEA::struct.psa()`.

## Which criterion

The source's workflow is DIC-centred, because DIC is what BUGS/JAGS report by default and what
`R2jags` returns without extra work. This repository's default is **LOO/PSIS via the `loo`
package**, as set out in `brms-modelling`'s `references/core-workflow.md`. Both are in play, and the
honest position is:

- **Use LOO (`loo_compare()`) as the default.** It estimates out-of-sample predictive accuracy, it
  ships a diagnostic (Pareto-k) that tells you when the estimate is unreliable, and brms computes it
  from a fit with no extra instrumentation. Prefer it whenever you have the pointwise log-likelihood
  — which, in brms, you always do.
- **Report DIC when the workflow is JAGS-based**, when reproducing or reviewing an analysis that
  used it, or when a submission's comparator analyses are stated in DIC. It is not wrong, it is
  older: it uses a plug-in estimate of the deviance and a heuristic penalty, has no reliability
  diagnostic, and is not invariant to parameterisation.
- **Do not silently switch criteria between models.** Compare a set on one scale.

Two DIC penalties appear in the source and they are not the same number. `pV` is half the posterior
variance of the deviance; `pD` is `Dbar − D(theta_hat)`, the BUGS definition, which `R2jags` obtains
by passing `pD = TRUE` (calling `rjags::dic.samples()`). They can differ materially, so **say which
one a reported DIC uses**. `pD` can even go negative for badly non-normal posteriors, which is a
signal the criterion is straining, not a small number.

The rough reading of a DIC difference used in the source: `< 2` is effectively equivalent support,
`3–7` is meaningfully less support, `> 10` is negligible support for the worse model. Treat these as
orientation, not a test.

For LOO, read `elpd_diff` against its standard error rather than applying a fixed threshold, and
check Pareto-k before believing either number.

## Comparing like with like

The trap specific to this setting: **the models must be fitted to the same observations and the same
outcome.** Three ways that fails here, all easy to miss:

- One model drops incomplete cases and another imputes them (`missing-economic-outcomes.md`). The
  likelihoods then cover different data and the comparison is meaningless. Check `nobs()`.
- One model is fitted to a transformed outcome (`e* = 3 − e`) and another to the raw one. A *linear*
  transformation changes the log-likelihood by a constant Jacobian term that is the same for every
  model on that scale — so models on the flipped scale are comparable with each other, but not with
  models on the raw scale unless you account for it. Simplest fix: keep the whole candidate set on
  one scale.
- One model is Beta on a rescaled 0–1 QALY and another Gamma on the natural scale. Different
  outcome variables; not comparable. Compare them on the decision quantities instead (below).

## What actually matters: does the choice change the decision?

A fit statistic is a means, not the end. Two models can differ by 100 DIC and produce
indistinguishable CEACs, or be nearly tied and disagree about which treatment to adopt. **Carry
every serious candidate through to the decision quantities and look at the CEACs overlaid**, then
report the fit comparison alongside. That is the comparison a decision-maker can act on, and it is
what the source does — three `bcea()` objects and one overlaid CEAC plot.

Practically: build a `bcea` object per candidate model from its draws, extract each CEAC and stack
them.

```r
ceacs <- purrr::imap_dfr(bcea_objects, \(m, nm) {
  BCEA::ceac.plot(m, graph = "gg")$data |> dplyr::mutate(model = nm)
})
ggplot(ceacs, aes(k, ceac, colour = model)) + geom_line() + ylim(0, 1)
```

The mechanics of `bcea()` and its plots belong to `bayesian-cea-r-hta`; this skill's job is to
produce one set of draws per candidate.

## Structural uncertainty and model averaging

If several models are credible and they disagree, choosing one and reporting it alone hides a real
uncertainty. Two defensible responses:

- **Scenarios.** Report the base case and the alternatives, and say how the decision changes. Always
  acceptable, and usually what an HTA committee wants to see.
- **Model averaging.** Weight the candidates and produce a single averaged set of draws. With DIC
  weights, `w_h = exp(−ΔDIC_h / 2) / Σ_j exp(−ΔDIC_j / 2)` — the same form as Akaike weights. The
  weights decay fast: a model 10 DIC behind gets essentially zero, so averaging only does real work
  when candidates are close. With LOO, stacking weights (`loo::loo_model_weights()`) are the modern
  equivalent and generally better behaved than raw information-criterion weights.

**`BCEA::struct.psa()` implements the DIC-weighted average and returns a `bcea` object**, so the
averaged result flows into every downstream plot. It belongs to `bayesian-cea-r-hta`, which owns
BCEA; this skill produces the per-model draws it consumes. Do not model-average as a way of avoiding
a modelling decision — if one model is right and the others are misspecified, averaging in the
misspecified ones makes the answer worse, not more honest.

## The hand-off contract

What `bayesian-cea-r-hta` (and `BCEA::bcea()`) expects:

```r
m <- BCEA::bcea(
  eff           = mu_effect,          # S x T matrix of posterior draws
  cost          = mu_cost,            # S x T, same S, same T, same arm order
  interventions = c("Control", "Intervention"),
  ref           = 2
)
```

Check every one of these before handing over:

| Check | Why |
|---|---|
| Both matrices are `S × T` with identical dimensions | `bcea()` will not detect a mismatch in meaning, only in shape |
| Column `t` is the same arm in both | Silently swaps the sign of the increment |
| Row `i` is the same posterior draw in both | The joint distribution *is* the pairing |
| Costs are on the natural currency scale | The threshold is denominated in it |
| Effects are in the units the threshold assumes (QALYs) | A life-years-based effect needs a different threshold |
| These are **arm-level means**, not individual predictions | The estimand is a population average |
| `S` is adequate (≥1,000; more for VOI) | Downstream VOI is noisier than a CEAC |
| No `NA`s | Propagate silently into every summary |

```r
stopifnot(
  identical(dim(mu_effect), dim(mu_cost)),
  !anyNA(mu_effect), !anyNA(mu_cost),
  nrow(mu_effect) >= 1000
)
```

`ref` selects which column is treated as the comparator, and getting it wrong flips the sign of
every incremental quantity while producing a perfectly plausible-looking plot. State it explicitly
rather than relying on the default.

Once the draws are handed over, the work belongs to `bayesian-cea-r-hta`: CE plane, CEAC/CEAF,
incremental net benefit, and value of information.
