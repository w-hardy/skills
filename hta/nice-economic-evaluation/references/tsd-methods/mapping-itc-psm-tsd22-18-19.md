# TSD 22 (mapping), TSD 18 (population-adjusted ITC), TSD 19 (PSM) — methods

Three method areas that recur in NICE submissions, kept together for brevity. Each links to
the relevant PMG36 clause and the full TSD.

---

## TSD 22 — Mapping to estimate health state utilities
*Supports 4.3.9 (mapping to EQ-5D), 4.10.3. Updated March 2026.* https://sheffield.ac.uk/media/118671/download

**When mapping is used:** the trial collected a non-preference-based measure (or EQ-5D-5L
where 3L values are wanted), so a mapping/crosswalk converts it to reference-case utilities.
This is a **justified deviation** from direct EQ-5D when the method is stated and tested.

**What a committee / EAG checks:**
- The **estimation sample and model** are appropriate and reported (direct mapping to utility
  vs response mapping to the descriptive system, then valued).
- Model form suits utility data's **ceiling at 1, gaps, and skew** (e.g. adjusted limited
  dependent variable mixture models, beta-based, or two-part models) rather than a naive OLS
  that predicts >1 and mis-fits the tails.
- **Predictive performance** assessed (mean error across the range, fit at poor-health
  states, not just overall R²).
- For **5L→3L**, the recognised crosswalk is used and stated; both 5L and crosswalk shown in
  sensitivity analysis given NICE's evolving position on 5L valuation.
- The mapping's added uncertainty is carried into the PSA.
**Common errors:** OLS mapping predicting utilities >1; good average fit hiding poor fit in
severe states (which drive QALY differences); mapping function applied outside the range of
the estimation data.

---

## TSD 18 — Population-adjusted indirect comparisons (MAIC / STC)
*Supports 3.4 and the section 4.6 evidence-synthesis clauses; comparator evidence.* https://sheffield.ac.uk/media/34216/download

**When used:** no head-to-head trial, and a standard (Bucher) indirect comparison is
undermined by **cross-trial differences in effect modifiers**. MAIC reweights individual
patient data to match the comparator trial's covariates; STC uses an outcome regression.

**What a committee / EAG checks:**
- **Anchored vs unanchored.** Anchored (a common comparator arm exists) only needs adjustment
  for effect *modifiers* and is far more reliable. **Unanchored** comparisons must adjust for
  *all* prognostic factors and effect modifiers — a very strong, usually implausible
  assumption — so are treated with great caution.
- All plausible **effect modifiers identified and justified** (clinically, a priori), not
  data-dredged.
- **Effective sample size** after weighting reported; severe shrinkage signals fragile,
  high-variance estimates.
- Results presented against the **Bucher ITC** as comparison, with uncertainty explored.
**Common errors:** unanchored MAIC presented as if reliable; effect modifiers chosen post
hoc; tiny effective sample size unreported; over-claiming precision.

---

## TSD 19 — Partitioned survival analysis as a decision modelling tool
*Supports 4.6.1 and the section 4.6 model-structure clauses.* https://sheffield.ac.uk/media/34205/download

**What it is:** the common oncology structure — PFS and OS curves modelled directly, with
state membership read off the area between them (PFS, post-progression = OS−PFS, dead).

**What a committee / EAG checks:**
- **Internal consistency**: PFS must not exceed OS at any time; post-progression survival
  implied by OS−PFS should be **clinically plausible** across the whole horizon, including the
  extrapolated tail (the classic PSM weakness — implausible long-term PPS).
- A **state-transition (Markov) cross-check** is increasingly expected, to test whether the
  PSM's implied transitions are sensible.
- Both curves extrapolated per TSD 14/21, with general-population mortality handled **once,
  on all-cause OS only** (TSD 21: internal excess hazard, or a post-hoc floor — never applied
  to PFS; see `survival-extrapolation-tsd14-21.md` step 5); the **structural link between PFS
  and OS** acknowledged (PSM treats them as independent, which they are not).
**Common errors:** independent extrapolation giving OS<PFS or implausible PPS in the tail; no
Markov comparison; no sensitivity around the structural assumption.
