---
name: clustering-clinical
description: Find and validate subgroups in clinical data in R - k-means, hierarchical/agglomerative clustering, DBSCAN, and latent class analysis - choosing the number of clusters, and above all establishing whether the clusters are real. Use whenever patients are being grouped without a supervising outcome, for phenotyping, subtyping, endotyping, or segmentation, or when appraising a paper claiming to have discovered novel subphenotypes. Trigger on "clustering", "k-means", "kmeans", "hierarchical clustering", "dendrogram", "Ward linkage", "DBSCAN", "silhouette", "elbow method", "gap statistic", "latent class analysis", "phenotype", "subtype", "endotype", "patient subgroups", or "how many clusters" - even when unnamed. Prefer this over memory, because clustering algorithms always return clusters and the stability assessment that distinguishes real structure from artefact is routinely skipped. For embeddings use dimensionality-reduction-clinical; never cluster on t-SNE or UMAP coordinates.
---

# Clustering Clinical Data

**Every clustering algorithm returns clusters.** Run k-means with k = 4 on pure
noise and you get four tidy groups with a plausible-looking silhouette. The
question is never "what are the clusters?" but "is there any structure here at
all, and would it appear again in different patients?"

Most of this skill is about answering that second question, because it is the one
the literature keeps skipping.

## Provenance

Verified 13 August 2026.

- Hennig C. *Comput Stat Data Anal* 2007;52:258-71 — cluster-wise assessment of cluster stability; `fpc::clusterboot()`
- Hennig C. *J Multivar Anal* 2008;99:1154-76 — dissolution point and isolation robustness
- Tibshirani R, Walther G, Hastie T. *JRSS-B* 2001;63:411-23 — the gap statistic
- Rousseeuw PJ. *J Comput Appl Math* 1987;20:53-65 — silhouettes
- Calfee CS et al. *Lancet Respir Med* 2014 — ARDS latent class phenotypes
- Seymour CW et al. *JAMA* 2019;321:2003-17 — sepsis phenotypes
- Gower JC. *Biometrics* 1971 — general coefficient of similarity for mixed data

## The workflow

1. **State what a cluster would mean clinically** before running anything. If you
   cannot say what you would do differently for a patient in cluster 2, the
   analysis has no destination.
2. **Decide the variables deliberately.** Clustering has no outcome to discipline
   variable choice, so the variables *are* the analysis. Including ten
   inflammatory markers and two haemodynamic ones will find inflammatory
   phenotypes by construction.
3. **Scale.** Distance-based methods are dominated by whichever variable has the
   largest units. Standardise, or use a distance that does not care.
4. **Choose an algorithm** that matches the cluster shape you can defend.
5. **Choose k** using several criteria, not one.
6. **Assess stability.** This is the step that decides whether you have a finding.
7. **Characterise clusters on the original variables**, and validate externally.

## Algorithms

| Method | Assumes | Watch for |
|---|---|---|
| **k-means** | Spherical, roughly equal-variance, equal-size clusters | Sensitive to scaling, outliers, and initialisation. Use k-means++ (`nstart` ≥ 25 in R) |
| **Hierarchical** | Depends entirely on linkage | Ward minimises within-cluster variance and tends to produce equal-sized spherical clusters; single linkage chains; complete linkage forces compactness |
| **DBSCAN** | Clusters are dense regions separated by sparse ones | Degrades badly in high dimensions, where distances concentrate and density stops being informative. Needs `eps` and `minPts` |
| **Latent class analysis** | A mixture model with a stated likelihood | Model-based, so gives fit statistics (BIC), handles categorical data naturally, and is what the influential ARDS and sepsis phenotype papers actually used |

**Latent class analysis is underused in this literature relative to how well it
fits the problem.** It is a statistical model rather than a geometric heuristic,
so "how many classes" becomes a model-selection question with BIC and
bootstrapped likelihood ratio tests rather than an eyeballed elbow. If the goal
is clinical phenotypes for publication, consider it before k-means.

**Mixed data types.** Euclidean distance is meaningless with a mix of continuous
and categorical variables. Use Gower distance (`cluster::daisy(x, metric =
"gower")`) with PAM or hierarchical clustering, or use latent class analysis.

## Choosing k

Use all of these and expect them to disagree; the disagreement is information.

- **Elbow** on within-cluster sum of squares. Often has no elbow. When it does
  not, that is evidence against strong cluster structure — report it rather than
  picking a bend that is not there.
- **Silhouette** (Rousseeuw): for each point, how much closer it is to its own
  cluster than to the next nearest, on −1 to +1. Above ~0.5 is reasonable
  structure; **0.25–0.5 is weak; below 0.25 means essentially no structure**.
  Read the per-cluster silhouette plot, not just the average — one good cluster
  can carry a mean that hides three bad ones.
- **Gap statistic** (Tibshirani et al.): compares within-cluster dispersion to
  that expected under a null of no clustering. Uniquely, it can return **k = 1**,
  meaning no clusters. Most other criteria cannot express that, which is why they
  always "find" clusters.

## Stability is the finding

Internal metrics can be high for meaningless clusters. The stronger test is
whether the same groups appear in a slightly different sample of patients.

**Bootstrap stability:** resample with replacement, re-cluster, and measure how
much the new grouping resembles the original using the **Jaccard index** —
intersection over union of cluster membership, best-matched cluster to cluster,
averaged over resamples.

Hennig's bands, which `fpc::clusterboot()` implements:

Hennig's guidance, quoted from the `fpc::clusterboot` documentation (verified
against the package manual, 13 August 2026) — note there are **five** levels, not
three:

| Mean Jaccard | Reading |
|---|---|
| **≤ 0.5** | "Dissolved cluster" — there is theoretical justification for this cut (Hennig 2008) |
| **< 0.6** | Should not be trusted |
| **0.6–0.75** | May indicate a pattern in the data, but *which* points belong is highly doubtful |
| **≥ 0.75** | A valid, stable cluster. **This is the operative threshold** |
| **≥ 0.85** | Highly stable |

Two things commonly get lost. First, **0.75 is the threshold for calling a cluster
valid** — summaries that jump from "below 0.6 is bad" to "above 0.85 is good"
omit it, and 0.75 is the number most reporting decisions actually turn on.
Second, these bands **refer to the bootstrap**; for the other resampling schemes
(subsetting, jittering, noise) interpretation depends on the tuning constants.

The docs also recommend **B = 100** as a working minimum, and note that
`$bootbrd` counts how often each cluster dissolved — worth reporting alongside
the mean.

**Stability is not validity.** Hennig is explicit that a cluster can be stable
without being valid: very inflexible clustering methods produce stable clusters
whether or not there is structure to find. Stability rules solutions *out*; it
does not rule them in.

```r
library(fpc)
cb <- clusterboot(scale(X), B = 200, bootmethod = "boot",
                  clustermethod = kmeansCBI, krange = 4, seed = 2026)
cb$bootmean   # per-cluster mean Jaccard
cb$bootbrd    # per-cluster count of dissolutions
```

Other interfaces: `hclustCBI` (needs `method=` and `k=`), `disthclustCBI` for a
distance matrix, `pamkCBI`, `dbscanCBI`, `claraCBI`.

**Report per-cluster stability, never just the mean.** A mean of 0.81 can conceal
two rock-solid clusters and two that dissolve. The weak cluster is the one a
reviewer will find.

## Things that invalidate the analysis

- **Clustering on t-SNE or UMAP coordinates.** The embedding has already
  distorted the geometry that distance-based clustering depends on, and it
  manufactures visual separation. Cluster on the original (scaled) variables, and
  use the embedding only to display the result.
- **Choosing k by looking at a t-SNE plot.** Same problem, one step earlier.
- **Reporting significance tests comparing clusters on the variables used to
  build them.** The clusters were constructed to differ on those variables, so
  the p-values are guaranteed small and mean nothing. Characterise clusters on
  *external* variables — outcomes, treatment response, variables held out of the
  clustering.
- **Skipping stability and reporting a silhouette instead.**

## Reporting a phenotyping study

Clusters are hypotheses, not facts. A defensible report states: the variables
entered and why; scaling and distance metric; the algorithm and its settings; how
k was chosen, with the criteria that disagreed; per-cluster stability with the
method and number of resamples; cluster characterisation on external variables;
and — the strongest evidence available — whether the clusters replicate in an
independent cohort.

The phenotype papers that have lasted (Calfee's ARDS classes, Seymour's sepsis
phenotypes) did the last of these. Most published subtyping does not, which is
why so little of it replicates.

## Verification status

Claims in this skill carry one of two provenance levels. Treat them differently.

**Verified 13 August 2026** — checked against the named primary source, package
documentation, or package source at that date:
Hennig's five stability bands and the stability-is-not-validity caveat, from the `fpc::clusterboot` manual; `clusterboot()` arguments and return components; Hennig 2007 and 2008 volume/pages.

**Not independently verified** — asserted from general knowledge and plausible
but unchecked. Confirm before relying on any of it in a submission, and treat
function signatures as a starting point rather than a guarantee:
Silhouette interpretation bands (0.5 / 0.25 — informal conventions, not from a primary source); the gap statistic citation details; `cluster::daisy(metric = "gower")` usage; latent class analysis package guidance.

Package APIs move. Re-check any code block that fails, and prefer the package's
own current documentation over this file where they disagree.
