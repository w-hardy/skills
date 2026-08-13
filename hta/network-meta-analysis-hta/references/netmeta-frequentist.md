# Frequentist NMA with netmeta

Full workflow for a frequentist, graph-theoretical NMA in `netmeta`. Same binary surgical-site-infection example, reference "nonantibacterial". netmeta works on **contrast-based** data (treatment effects + SEs per comparison), so the first job is converting arm-level counts to contrasts.

> Sources: R-HTA Ch. 10 (frequentist NMA via netmeta on the same example); `netmeta` CRAN reference manual (`pairwise()`, `netmeta()`, `netgraph()`, `netrank()` with P-scores/`method = "SUCRA"`, `netsplit()`, `decomp.design()`, `netheat()` all confirmed as current). Accessed 2026-07-03.

## Data prep: arm-based -> contrast-based

`pairwise()` converts arm-level event/n data into the contrast format netmeta needs, computing the effect measure (here OR) per comparison and adding a **0.5 continuity correction** to any zero-event arm automatically.

```r
library(netmeta)

# netmeta CANNOT take two independent arms on the same treatment within a trial --
# merge them first (sum r and n) or pairwise() will error.
# Multi-arm trials are fine; pairwise() expands them and repeats the study label.

icl_contrasts <- pairwise(
  treat = list(t[,1], t[,2], t[,3]),     # up to max-arms columns; NA-pad shorter trials
  event = list(r[,1], r[,2], r[,3]),
  n     = list(n[,1], n[,2], n[,3]),
  data  = icl_data,
  sm    = "OR",                          # summary measure: "OR","RR","MD","HR" (log-)...
  studlab = names(na)
)
# Result has TE (log effect), seTE, studlab, treat1, treat2 per comparison.
```

## Fit fixed (common) and random effects

`netmeta()` fits both; the `common`/`random` flags control which is reported. netmeta calls fixed effects "common".

```r
fit_fe <- netmeta(TE, seTE, treat1, treat2, studlab, data = icl_contrasts,
                  common = TRUE,  random = FALSE,
                  reference.group = "nonantibacterial")

fit_re <- netmeta(TE, seTE, treat1, treat2, studlab, data = icl_contrasts,
                  common = FALSE, random = TRUE,
                  reference.group = "nonantibacterial")

fit_re    # prints OR vs reference with 95% CI, z, p; plus heterogeneity/inconsistency
```

The printout gives treatment estimates vs the reference (back-transformed to OR for `sm="OR"`), and a heterogeneity/inconsistency block: `tau^2`, `tau`, `I^2`, and a Q decomposition into Total / Within-designs / Between-designs. High I² and a low within-designs Q p-value favour random effects.

## Network graph

```r
netgraph(fit_re, points = TRUE, cex.points = 3,
         multiarm = TRUE, number.of.studies = TRUE)
```

## Ranking: P-scores and SUCRA

```r
# small.values = "good" if a SMALLER effect (e.g. fewer infections) is better
netrank(fit_re, small.values = "good")                    # P-scores (frequentist analogue of SUCRA)
netrank(fit_re, small.values = "good", method = "SUCRA")  # SUCRA via simulation

plot(rankogram(fit_re, small.values = "good"))            # rankograms
```

P-scores and SUCRA both run 0–1, higher = better-ranked. Same health warning as the Bayesian side: "probability best" is unstable when uncertainty is high — report with the effect estimates.

## Inconsistency diagnostics (netmeta's strength)

netmeta's design-level inconsistency tooling is its standout feature — see `inconsistency-testing.md` for full interpretation. The three tools:

```r
netsplit(fit_re)        # SIDE: split direct vs indirect per comparison (local test)
decomp.design(fit_re)   # decompose Q into within/between-design; detach designs
netheat(fit_re, nchar.trts = 7)   # net heat plot: visualises between-design inconsistency
```

`decomp.design()` reports `Q_total = Q_within + Q_between`, a per-design decomposition of the within-design Q, the between-design Q after detaching each design (a design whose detachment markedly changes the p-value is influential), and a design-by-treatment-interaction Q. `netheat()` is the visual companion: diagonal cells show each design's inconsistency contribution (warmer = more), off-diagonals show whether one design's evidence supports (blue) or conflicts with (orange) another's.

## When netmeta vs multinma estimates differ

They usually broadly agree but can diverge because of: the continuity correction netmeta applies to zero-event arms, the influence of priors in the Bayesian fit, and different estimation procedures (graph-theoretical/DerSimonian-Laird vs MCMC). If they disagree materially, investigate rather than picking the convenient one — check zero-event arms, try an informative heterogeneity prior in multinma, and try alternative τ² estimators in netmeta. A genuine, well-understood difference is itself worth reporting.

## Meta-regression in netmeta

`netmetareg()` supports network meta-regression with a single continuous or binary covariate — more limited than multinma's, but available for a quick frequentist check. The same effect-modifier-only and underpowering caveats from the main skill apply.
