# Reconstructing IPD from a published Kaplan-Meier curve

> Sources: R-HTA Ch. 7 (KM reconstruction); Guyot et al. (2012, BMC Med Res Methodol);
> `survHE` pkgdown docs (`digitise()`, `make.ipd()`). Accessed 2026-07-03.

When the only evidence for a comparator is a published KM curve (no patient-level data), the Guyot et al. (2012) algorithm reconstructs pseudo-individual-patient-data from the digitised curve plus the numbers-at-risk table. This pseudo-IPD can then be fitted with `flexsurvreg` exactly as if it were real data.

## The two inputs the algorithm needs

1. **Digitised survival coordinates** — (time, survival probability) points read off the KM curve, capturing every step. Digitise by hand (clicking points) or automatically with `SurvdigitizeR`, which needs minimal user input. Saved as a text file.
2. **Numbers-at-risk table** — the "n at risk" row usually printed beneath a KM plot, giving the number still at risk at each reported time. Saved as a second text file. This is what lets the algorithm recover censoring; without it the reconstruction is far less reliable.

## The survHE workflow

```r
library(survHE)

# Step 1: digitise() reads the two input files and writes out a KM-format file
#         and an IPD-format file. The algorithm assumes censoring is constant
#         within each at-risk interval (but can differ between intervals).
digitise(surv_inp   = "data/OS.txt",         # digitised (time, surv) coordinates
         nrisk_inp  = "data/OS_risk.txt",     # numbers-at-risk table
         km_output  = "data/KMdata_OS.txt",
         ipd_output = "data/IPDdata_OS.txt")

# Step 2: make.ipd() assembles the reconstructed individual-level dataset
#         (time, event, arm) from the digitise output. ctr indexes the
#         control/reference arm; var.labs names the output columns.
IPD_OS <- make.ipd(ipd_files = c("data/IPDdata_OS.txt"), ctr = 1,
                   var.labs  = c("time", "event", "arm"))

# Step 3: fit as if it were real IPD
fit <- flexsurvreg(Surv(time, event) ~ 1, data = IPD_OS, dist = "gengamma")
```

For more than one arm, run `digitise()` per arm and pass all the IPD files to `make.ipd()` together (it stacks them, labelling arms).

## Caveats to state every time

- **No patient-level covariates.** The reconstruction recovers only time, event, and arm — there are no individual covariates, so no subgroup or adjusted analysis is possible unless the source happens to report KM curves separately by subgroup.
- **Reconstruction quality depends on the numbers-at-risk table.** With only the curve and no at-risk numbers, censoring is poorly identified and the pseudo-IPD can misrepresent the tail — which is exactly the region that drives extrapolation. Push to find the at-risk numbers; flag the limitation if they're unavailable.
- **Digitisation error propagates.** Sloppy point-capture on the curve feeds straight through to the fitted model. Capture every step change, and sanity-check the reconstructed KM (`km_output`) against the published one before fitting.
- **It's pseudo-data, and downstream uncertainty should acknowledge that** — the reconstruction treats the digitised curve as exact, so confidence intervals from a model fitted to pseudo-IPD understate true uncertainty somewhat. This matters less for the point estimate than for any claim about precision.

This reconstruction is also the first step of the two-step network-meta-analysis-of-survival approach (fit per-arm distributions to reconstructed data, then synthesise the parameters) — see the `network-meta-analysis-hta` skill for the synthesis stage.
