# Testing the consistency assumption (inconsistency)

The consistency assumption — that `d_xy = d_1y − d_1x` holds across the network — is what makes NMA valid. Inconsistency is direct evidence on a comparison disagreeing with the indirect evidence, caused by treatment-effect-modifier imbalance between the trials informing the direct vs indirect paths. It's testable only where there's a **loop** of evidence, but it can be present even where untestable. Testing it is a required step in an HTA NMA, not an optional extra.

> Sources: R-HTA Ch. 10 (consistency/inconsistency: unrelated-mean-effects model, node-splitting, design-based decomposition, meta-regression on effect modifiers); `netmeta` CRAN docs (`netsplit` per Dias et al. 2010, `decomp.design`/`netheat` per Krahn et al. 2013); `multinma` pkgdown. Accessed 2026-07-03.

Heterogeneity vs inconsistency: both come from effect differences between studies. Heterogeneity is variation *within* the same comparison; inconsistency is variation *between* different comparisons/designs. They're linked — random effects absorb some heterogeneity, and a drop in τ under an inconsistency model is itself a signal.

## Bayesian (multinma): UME and node-splitting

### UME — global test
Unrelated mean effects drops consistency and estimates every contrast independently (`d_ck ≠ d_1k − d_1c`). Fit it, then compare fit to the consistency model:

```r
fit_ume <- nma(net, consistency = "ume", trt_effects = "random",
               prior_intercept = normal(scale = 100), prior_trt = normal(scale = 100),
               prior_het = half_normal(scale = 2.5),
               control = list(max_treedepth = 15))   # only if sparse-data warnings appear

dic(fit_ume)        # compare DIC + residual deviance to dic(fit_re)
# Also plot the two dic objects against each other:
plot(dic_re, dic_ume, show_uncertainty = FALSE)
```

Interpretation: substantially **lower** DIC/residual deviance under UME ⇒ inconsistency present. A reduction in heterogeneity τ under UME is corroborating evidence. On the per-point deviance scatter, watch for points poor-fitting under consistency but good under UME (lower-right) — their absence is reassuring. UME is a global flag; it doesn't say *which* loop.

### Node-splitting — local test
Splits direct vs indirect evidence on each loop edge, automatically detecting independent loops:

```r
fit_ns <- nma(net, consistency = "nodesplit", trt_effects = "random",
              prior_intercept = normal(scale = 100), prior_trt = normal(scale = 100),
              prior_het = half_normal(scale = 2.5),
              control = list(max_treedepth = 15))

summary(fit_ns)     # per-comparison: d_dir, d_ind, d_net, omega, and a Bayesian p-value
plot(fit_ns)        # visual direct vs indirect vs network estimates
```

Interpretation: per comparison, compare the direct (`d_dir`) and indirect (`d_ind`) estimates; a small **Bayesian p-value** (and visibly separated CrIs) flags that comparison as inconsistent. Where the indirect evidence is very uncertain (huge `d_ind` CrI), the network estimate is effectively the direct evidence and that "inconsistency" is just sparsity, not genuine conflict — read those cautiously.

## Frequentist (netmeta): Q decomposition, net heat, SIDE

### decomp.design — design-level Q decomposition
```r
decomp.design(fit_re)
```
Reports, in order: `Q_total = Q_within(designs) + Q_between(designs)`; a per-design decomposition of within-design Q (which designs are internally heterogeneous); the between-design Q recomputed after **detaching** each design (a design whose detachment markedly shifts the p-value away from the overall value is an influential source of inconsistency); and a design-by-treatment-interaction-model Q.

### netheat — the visual companion
```r
netheat(fit_re, nchar.trts = 7)
```
Diagonal cells: each design's own inconsistency contribution (warmer/redder = larger). Off-diagonal cells: after relaxing consistency for the column's design, how the row's direct-vs-indirect inconsistency changes — **blue** = column evidence supports the row, **orange/yellow** = column evidence conflicts with the row. "Hot spots" of orange locate where designs disagree.

### netsplit — SIDE local test
```r
netsplit(fit_re)        # per comparison: direct, indirect, network estimates + p-value
```
The frequentist analogue of node-splitting (Separating Indirect from Direct Evidence). Same reading: direct vs indirect disagreement on a comparison flags local inconsistency.

## The point that matters most: what to do when you find inconsistency

A full **design-by-treatment-interaction random-effects model** will often make the Q-test non-significant — but that model is **meaningless for treatment-effect estimation**. It has enough parameters to absorb the inconsistency but cannot be used for inference; you can't read relative effects off it. So inconsistency is *not* something to model away.

When the tests flag inconsistency, the correct response is to **go back to the evidence**: examine which trials inform the conflicting direct and indirect paths, look for imbalance in effect modifiers (different populations, eras, co-treatments, outcome definitions) between them, and get clinical input on a plausible mechanism. The statistical tests locate the problem; understanding and justifying it (or excluding/adjusting the offending evidence with a documented rationale) is a substantive, not a modelling, task. Document the investigation — an HTA reviewer will expect the consistency assumption to have been tested *and* the findings to have been interpreted, not just reported.

## Cross-package agreement

The Bayesian node-splitting and frequentist `decomp.design`/`netheat` usually point to the same problematic comparisons (in the book's example, all three methods implicate the same antiseptic / no-irrigation designs). Agreement across paradigms strengthens the diagnosis; disagreement is itself worth understanding before drawing conclusions.
