# Comparing candidate models, and handing the draws downstream

> Source: BMHTA §5.3 (model selection) and §5.4 (cost-effectiveness modelling), Examples 5.6-5.8 —
> verified against the online edition, 2026-09-09. The book compares the three candidate models by
> DIC (both `pV` and `pD` penalties, Table 5.3), adds WAIC and LOO-CV from a monitored
> log-likelihood node (§5.3.4, Ex 5.7), and model-averages with `BCEA::struct.psa()` (§5.4).
> Companion code: `05-ild/ild.R` (bmhta-examples @ `d2a6298`).

## Which criterion

The source's workflow is DIC-centred, because DIC is what BUGS/JAGS report by default and what
`R2jags` returns without extra work. This repository's default is **LOO/PSIS via the `loo`
package**, as set out in `brms-modelling`'s `references/core-workflow.md`. Both are in play, and the
honest position is:

- **Use LOO (`loo_compare()`) as the default**, attaching it to each fit with
  `add_criterion(fit, "loo")` first. It estimates out-of-sample predictive accuracy, it
  ships a diagnostic (Pareto-k) that tells you when the estimate is unreliable, and brms computes it
  from a fit with no extra instrumentation. Prefer it whenever you have the pointwise log-likelihood
  — which, in brms, you always do.
- **Report DIC when the workflow is JAGS-based**, when reproducing or reviewing an analysis that
  used it, or when a submission's comparator analyses are stated in DIC. It is not wrong, it is
  older: it uses a plug-in estimate of the deviance and a heuristic penalty, has no reliability
  diagnostic, and is not invariant to parameterisation.
- **Do not silently switch criteria between models.** Compare a set on one scale.

Two DIC penalties appear in the source and they are not the same number (§5.3.1). `pV = Var[D]/2`
(Gelman et al.) is JAGS' default: invariant to reparameterisation and non-negative. `pD = Dbar −
D(theta_hat)` (Eq 5.14) is the original BUGS definition, and it can go negative for badly non-normal
posteriors — a signal the criterion is straining, not a small number. `R2jags` computes a penalty it
also calls `pD` when you pass `pD = TRUE`, but that one is **Plummer's (2008) variant**, obtained via
`rjags::dic.samples()`; the book notes it is "a slightly different version than the original one
defined by Spiegelhalter et al. (2002), although it usually provides near-identical results". They
can differ materially from `pV`, so **say which penalty a reported DIC uses**.

One trap when reading older output: **`R2jags` before v0.8-9 (October 2024) printed `pV` under the
label `pD`**. A legacy table saying "pD" may be neither definition above.

Only `pD` estimates the effective number of parameters under shrinkage in a hierarchical model;
`pV` generally does not (§6.2.7).

The rough reading of a DIC difference used in the source: `< 2` is effectively equivalent support,
`3–7` is meaningfully less support, `> 10` is negligible support for the worse model. Treat these as
orientation, not a test.

For LOO, read `elpd_diff` against its standard error rather than applying a fixed threshold, and
check Pareto-k before believing either number.

## Comparing like with like

The trap specific to this setting: **the models must be fitted to the same observations, the same
outcome, and against the same dominating measure.** Four ways that fails here, all easy to miss:

- One model drops incomplete cases and another imputes them (`missing-economic-outcomes.md`). The
  likelihoods then cover different data and the comparison is meaningless. Check `nobs()`. More
  generally, with missing data the source warns that likelihood-based information criteria "do not
  fully apply", because the likelihood is conditional on the observed data and says nothing about
  the unobserved (§10.1) — so a DIC or LOO gap between two models with different missingness
  handling is not evidence about either.
- One model is fitted to a *rescaled* outcome and another to the raw one. Which transformations are
  safe is not obvious, and the source works it out (Note 5.2). A **reflection** like `e* = 3 − e` is
  affine with |Jacobian| = 1, and under a symmetric sampling distribution it leaves the deviance
  **unchanged** — `D(mu*, sigma) = D(mu, sigma)` exactly — so a Normal model on the flipped scale is
  directly comparable with one on the raw scale. A **multiplicative** rescaling is not: dividing
  costs by `kappa` shifts a Gamma model's deviance by `2n·log(kappa)`, which for the source's data is
  `2 × 167 × log(1000) = 2307.19` — larger than any difference you would be interpreting. So the rule
  is not "never transform", it is: **every candidate must use the same cost scale**, and check the
  Jacobian before comparing across a transformation rather than assuming either way.
- One model is Beta on a rescaled 0–1 QALY and another Gamma on the natural scale. Different
  outcome variables; not comparable. Compare them on the decision quantities instead (below).
- One model puts a probability **mass** where the other puts a **density**. A hurdle,
  zero-one-inflated or censored candidate assigns a point mass at the boundary — `hu`, `zoi`, or the
  probability of the censoring event — while a continuous candidate assigns a density there. Their
  pointwise log-likelihoods are taken with respect to different dominating measures (counting
  measure at the spike plus Lebesgue elsewhere, versus Lebesgue throughout), so they are not on one
  scale and `elpd_diff` between them is not a difference in predictive accuracy. The give-away is
  that the gap moves when you change the *units* of the continuous outcome, which a genuine
  predictive comparison would not. This is the direct consequence of following
  `structural-values.md`: the moment a `hurdle_gamma()` cost model sits in the ladder beside a
  `gaussian()` one, or a censored candidate beside an uncensored one, `loo_compare()` has stopped
  answering the question. Two hurdle models differing only in their `hu` formula are fine — same
  measure, same scale. For the mass-versus-density pair, compare on the decision quantities (below)
  and on a targeted posterior predictive check of the spike itself,
  `pp_check(fit, resp = "costk", type = "stat", stat = function(y) mean(y == 0))`, which is the
  check the spike was introduced for.

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
averaged result flows into every downstream plot. In the source it is called positionally as
`struct.psa(models, effects, costs, ref = , interventions = )`, where `models` is a list of the
fitted JAGS objects and `effects`/`costs` are lists of the per-model draw matrices; the result
carries the extra class `struct.psa` and exposes the weights as `m_avg$w`. In the worked example
those weights are `1.6e-42`, `4.9e-40`, `1.00` — an "average" that is one model. It belongs to
`bayesian-cea-r-hta`, which owns BCEA; this skill produces the per-model draws it consumes. Do not
model-average as a way of avoiding a modelling decision — if one model is right and the others are
misspecified, averaging in the misspecified ones makes the answer worse, not more honest.

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

`ref` names the **intervention of interest** — the column whose incremental quantities and INB are
reported — not the comparator. BCEA's sign convention is that a positive EIB favours `ref`; see
`bayesian-cea-r-hta`'s `references/bcea-package.md`, which owns the package. It defaults to column
1, so the call above sets `ref = 2` deliberately. Getting it backwards flips the sign of every
incremental quantity while producing a perfectly plausible-looking plot. State it explicitly rather
than relying on the default, and check the sign of the reported increment against the crude
difference in arm means before believing any plot.

**The contrast form, and how it reconciles.** Most two-arm within-trial CEAs never build two `S × T`
matrices: they carry the contrast directly, as a tidy frame of `(.draw, inc_cost, inc_qaly)`, one
row per posterior draw. That is not a breach of the contract — it is the same object with the
baseline arm differenced out — provided the contrast was formed **per draw** from arm means
computed in the same fit (`inc_cost = mu_cost[, 2] - mu_cost[, 1]`, row by row). A contrast built
from separately summarised arm means, or from two fits, has already lost the pairing; the `.draw`
column is what lets you prove it did not, and it must index the same posterior draw in both columns.

To hand a contrast frame to `bcea()`, expand it to `S × 2` with a **zero column** for the arm the
contrast was taken against: `cbind(0, inc_qaly)` and `cbind(0, inc_cost)`. That puts the baseline in
column 1 and the increment in column 2, so `ref = 2` here, matching the call above — and name both
arms in `interventions` rather than accepting the default.

`bayesian-cea-r-hta`'s rule that `bcea()` takes **absolute** per-arm values, never increments, still
holds in general; this is the two-arm exception, and it is worth knowing why it is one. For two arms
everything BCEA computes — CE plane, CEAC, INB, EVPI, EVPPI — is a functional of the per-draw
increments, and subtracting the same per-draw constant from every arm's net benefit shifts
`E[max_t NB_t]` and `max_t E[NB_t]` by the same amount, so those results are unchanged. What the
zero column does not give you is **absolute** arm-level cost, effect and net benefit — `summary()`
will report zero for the baseline column. Most HTA write-ups quote those, so carry the baseline
arm's absolute means as an `S × 1` vector as well and rebuild the real `S × T` matrices from it.
With **more than two arms** the exception lapses and the sibling's rule applies unqualified: keep
the matrices, because the efficiency frontier and the fully incremental analysis are stated over
arms, and reconstructing them from contrasts against a single baseline is exactly the arithmetic
that silently swaps a comparator.

Once the draws are handed over, the work belongs to `bayesian-cea-r-hta`: CE plane, CEAC/CEAF,
incremental net benefit, and value of information.
