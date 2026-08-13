---
name: dimensionality-reduction-clinical
description: Reduce and visualise high-dimensional clinical or omics data in R - PCA, t-SNE, and UMAP - choosing components, setting perplexity and n_neighbors, and reading the output without over-reading it. Use whenever many correlated measurements are being summarised or projected to two dimensions for visualisation, or when reviewing a figure that shows patients as points in an abstract embedding. Trigger on "PCA", "principal components", "prcomp", "scree plot", "biplot", "loadings", "t-SNE", "Rtsne", "UMAP", "n_neighbors", "perplexity", "embedding", "dimension reduction", "curse of dimensionality", or "p greater than n visualisation" - even when unnamed. Prefer this over memory, because initialisation determines whether global structure survives, and the common claims that UMAP is faster and more stable than t-SNE are outdated. For grouping patients use clustering-clinical; never cluster on an embedding.
---

# Dimensionality Reduction for Clinical Data

Two different jobs get confused here. **PCA** produces new variables you can
carry into a downstream model. **t-SNE and UMAP** produce pictures. The pictures
are not variables, not distances, and not evidence.

## Provenance

Verified 13 August 2026.

- van der Maaten L, Hinton G. *JMLR* 2008;9:2579-605 — t-SNE
- McInnes L, Healy J, Melville J. arXiv:1802.03426, 2018 — UMAP
- **Kobak D, Linderman GC. *Nat Biotechnol* 2021;39:156-7 — initialisation is critical for preserving global structure in both t-SNE and UMAP**
- Kobak D, Berens P. *Nat Commun* 2019;10:5416 — the art of using t-SNE
- Wattenberg M, Viégas F, Johnson I. *Distill* 2016 — how to use t-SNE effectively
- Chari T, Pachter L. *PLoS Comput Biol* 2023 — the specious art of single-cell genomics
- Becht E et al. *Nat Biotechnol* 2019;37:38-40 — the UMAP claim that Kobak & Linderman rebut

## The correction most teaching material has not caught up with

The received wisdom is that UMAP preserves global structure better than t-SNE,
runs several times faster, and is more stable across runs. Kobak and Linderman
showed the first claim to be an artefact of **implementation defaults, not
algorithms**: the t-SNE implementations compared used **random initialisation**,
while the UMAP implementation used **Laplacian eigenmaps**. Once informative
initialisation is used, the two preserve global structure similarly well. They
add that modern implementations run at similar speed, and that the widespread
belief that UMAP is much faster is outdated.

Practical consequences:

- **Initialise with PCA.** This is the single highest-value setting in either
  algorithm, and it is not the default in `Rtsne`. With PCA initialisation, the
  global layout becomes reproducible and meaningful; with random initialisation
  it is neither.
- **Run-to-run "instability" is largely an initialisation artefact.** Fix the
  initialisation and set a seed, and both methods become reproducible.
- **Do not choose UMAP over t-SNE on speed or stability grounds** without
  checking against current implementations (`openTSNE`, `FIt-SNE`).

```r
library(Rtsne)
pca_init <- prcomp(X_scaled)$x[, 1:2]
pca_init <- pca_init / sd(pca_init[, 1]) * 0.0001   # scale as Kobak & Berens advise

set.seed(2026)
emb <- Rtsne(X_scaled, perplexity = 30, Y_init = pca_init, pca = FALSE)$Y
```

## PCA

Linear, deterministic, and the only one of the three whose output can legitimately
feed a downstream model.

**Standardise first**, unless every variable is already on the same scale and
that scale is meaningful. PCA maximises variance, so an unstandardised variable
measured in larger units dominates purely through magnitude. `prcomp(X, scale. =
TRUE)` — the trailing dot is easy to miss and silently skipping it changes
everything.

**Choosing components.** No single rule. Combine: cumulative variance explained
(70–90% is a common target), the scree-plot elbow, and — better than either —
whether the retained components are interpretable and whether downstream
performance is stable across nearby choices. Kaiser's eigenvalue-greater-than-1
rule is widely taught and widely criticised for retaining too many; do not rely
on it alone.

**Two cautions on loadings.** Signs are arbitrary — a component and its negation
are the same component, so "PC1 is high glucose" and "PC1 is low glucose" may
both appear across runs or software. And loadings apply to the *standardised*
values, which is what makes them comparable at all.

**PCA does not maximise class separation.** It maximises variance, which may lie
entirely along a nuisance axis such as batch or measurement error. If separation
is the goal, that is a supervised question.

**Leakage.** If PCA feeds a prediction model, fit it on the training data only
and apply the same rotation to the test data. Fitting PCA on the full dataset
before splitting leaks test information into the training representation. Same
applies to standardisation.

## t-SNE and UMAP

Non-linear, stochastic, and **for visualisation only**.

| Parameter | t-SNE | UMAP | Effect |
|---|---|---|---|
| Neighbourhood size | `perplexity` (5–50, default 30) | `n_neighbors` (5–200, default 15) | Small: tight local clumps. Large: broader, smoother layout |
| Compactness | — | `min_dist` (0.0–0.99) | Lower packs clusters tighter |
| Initialisation | `Y_init` | `init` | **Set to PCA. See above.** |

**Always run at several settings.** A structure that appears at perplexity 30 and
vanishes at 10 and 50 is not a finding. A structure that survives the range is
worth following up — with a method that can actually test it.

### What these plots cannot tell you

State these whenever presenting an embedding; the figures look far more
authoritative than they are.

- **Distances between clusters are meaningless.** Two blobs far apart are not
  more different than two blobs close together. The algorithms deliberately
  distort global distance to preserve local neighbourhoods.
- **Cluster sizes are meaningless.** A tight blob is not a more homogeneous group
  than a diffuse one; the density is set by the algorithm, not the data.
- **The axes have no units and no meaning.** Do not read values off them, do not
  regress on them, do not report them.
- **Apparent clusters may not exist.** Both methods will produce visually
  separated blobs from unstructured data at some parameter settings. Chari and
  Pachter make the strong version of this argument.
- **These are not features.** Do not feed t-SNE or UMAP coordinates into a
  prediction model or a clustering algorithm. The embedding has already
  distorted the geometry that those methods rely on. If dimension reduction is
  needed before modelling, use PCA.

The honest framing for a paper: an embedding is a **hypothesis-generating
picture**. Whatever it suggests must be tested on the original variables.

## Reporting

State the method and implementation with version; whether and how data were
standardised; the initialisation; the parameter values and the range explored;
the random seed; and, for PCA, the number of components retained and the variance
explained. An embedding figure without its parameters cannot be reproduced or
appraised.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
Kobak & Linderman (2021) on initialisation, speed and global structure — read directly, and it contradicts the still-common claim that UMAP is faster and more stable.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
The `Rtsne(Y_init = ...)` scaling constant; PCA component-retention conventions and the Kaiser-rule criticism; Chari & Pachter and Apley & Zhu citation details; `PyALE`.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
