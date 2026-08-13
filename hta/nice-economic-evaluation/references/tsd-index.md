# DSU Technical Support Documents (TSDs) — index and clause map

The NICE Decision Support Unit (DSU) TSDs explain *how to implement* the methods PMG36
describes. They are advisory, not mandatory, but committees and EAGs treat them as the
reference standard for method choice. When an alignment review flags a methods gap, point
the user to the relevant TSD as the route to fixing it — cite the TSD by number and topic,
and give the URL; don't reproduce the documents' text (they're copyrighted).

Full list and downloads: https://sheffield.ac.uk/nice-dsu/tsds/full-list
One-page summaries: https://sheffield.ac.uk/nice-dsu/tsds/summaries

*TSD titles, numbers, update status and all download URLs in this file verified against the
DSU full list (page dated 1 April 2026), 3 July 2026. PMG36 sub-clause numbers within
sections 4.6–4.7 are cited at section level (see `modelling-and-uncertainty.md`).*

How to use this file: find the theme matching the user's issue, name the TSD(s), and tie the
recommendation back to the PMG36 clause from the other reference files. Several TSDs are
**updated for the March 2026 manual** — prefer the newer of any pair (TSD 24 over 16; flag
TSD 22, 23 as the current versions).

## Severity (supports Table 6.1; 6.2.12–6.2.18)
- **TSD 23 — A guide to calculating severity shortfall** *(updated March 2026)*. The
  authoritative method behind the `severity_weight` calculation: how to derive absolute and
  proportional QALY shortfall, the general-population reference values, age/sex matching to
  the treated population, and discounting. When the skill computes or checks a severity
  weight, this is the method to align to. https://sheffield.ac.uk/media/118621/download

## Health-state utilities / HRQoL (supports 4.3.1–4.3.10; 4.10.3)
- **TSD 22 — Mapping to estimate health state utilities** *(updated March 2026)*. Current
  guidance on mapping (e.g. EQ-5D-5L→3L, non-preference instrument→utility). Cite when a
  crosswalk/mapping is used. https://sheffield.ac.uk/media/118671/download
- **TSD 10 — Use of mapping methods** (earlier mapping TSD; superseded in practice by 22).
- **TSD 8 — Introduction to measurement and valuation of health.**
- **TSD 9 — Identification, review and synthesis of HSUVs from the literature.**
- **TSD 11 — Alternatives to EQ-5D** (when EQ-5D is unsuitable/not collected — relevant to a
  justified deviation under 4.3.10).
- **TSD 12 — Use of HSUVs in decision models** (selecting/combining utilities, comorbidity,
  age adjustment).

## Survival analysis, extrapolation and treatment switching (supports 4.2.24; section 4.6 survival and switching clauses)
- **TSD 14 — Survival analysis alongside trials: extrapolation with patient-level data.**
  The standard parametric-model selection process (fit + plausibility + external data).
- **TSD 21 — Flexible methods for survival analysis** (spline/flexible parametric, mixture
  cure, non-PH settings). Cite when a single standard parametric fit is inadequate.
- **TSD 24 — Adjusting survival in the presence of treatment switching** *(update of TSD 16)*.
  The method reference for RPSFT/IPCW/two-stage — cite for any crossover/switching issue.
- **TSD 16 — Treatment switching** (original; use 24 instead).
- **TSD 26 — Expert elicitation for long-term survival outcomes** (formal elicitation where
  long-term data are absent; supports the section 4.7 elicitation point and 4.2.24 extrapolation).
- **TSD 20 — Multivariate meta-analysis / surrogate endpoints** (supports the section 4.6 surrogate clauses;
  validating surrogate-to-final relationships).

## Model structure and conceptualisation (supports 4.6.1 and the section 4.6 conceptualisation clauses)
- **TSD 13 — Identifying and reviewing evidence to conceptualise and populate CE models.**
  Cite for the conceptual-model justification PMG36 expects (section 4.6).
- **TSD 19 — Partitioned survival analysis as a decision modelling tool.** Cite when a PSM is
  used — covers its assumptions and the state-transition cross-check NICE often asks for.
- **TSD 15 — Cost-effectiveness modelling using patient-level simulation** (DES/microsim).

## Evidence synthesis and indirect comparison (supports 3.4; section 4.6 evidence-synthesis clauses; comparators)
- **TSD 1 — Introduction to evidence synthesis for decision making.**
- **TSD 2 — General linear modelling framework for pairwise and network meta-analysis.**
- **TSD 3 — Heterogeneity: subgroups, meta-regression, bias and bias-adjustment.**
- **TSD 4 — Inconsistency in networks of RCTs** (NMA validity checks).
- **TSD 5 — Evidence synthesis in the baseline natural history model.**
- **TSD 6 — Embedding evidence synthesis in probabilistic CEA: software choices** (supports
  PSA implementation, section 4.7).
- **TSD 7 — Evidence synthesis of treatment efficacy: a reviewer's checklist.**
- **TSD 17 — Observational data to inform treatment-effectiveness estimates** (comparative
  IPD; relevant to real-world evidence and non-RCT comparators).
- **TSD 18 — Population-adjusted indirect comparisons** (MAIC, STC). Cite when the user uses
  a MAIC/anchored or unanchored adjusted comparison instead of, or alongside, a Bucher ITC.
- **TSD 25 — Evidence synthesis of diagnostic test accuracy for decision making** (diagnostics
  evaluations).

## HealthTech (supports the HealthTech-specific process)
- **TSD 27 — Prioritising studies and outcomes for NICE HealthTech literature reviews.**

## Mapping issues to TSDs — quick lookup
| If the user's issue is… | Reference-case clause | TSD(s) to cite |
|---|---|---|
| Severity shortfall calculation | Table 6.1, 6.2.13–18 | 23 |
| Mapping / crosswalk of utilities | 4.3.9 | 22 (10) |
| Choosing/combining utility values | 4.3, 4.10.3 | 8, 9, 11, 12 |
| Survival extrapolation, single fit on AIC | section 4.6, 4.2.24 | 14, 21, 26 |
| Treatment switching / crossover | section 4.6 | 24 (16) |
| Surrogate endpoints | section 4.6 | 20 |
| PSM structure / cross-check | 4.6.1, section 4.6 | 19 |
| Patient-level simulation | 4.6 | 15 |
| Conceptual model justification | section 4.6 | 13 |
| NMA / indirect comparison | 3.4, section 4.6 | 1, 2, 3, 4, 7 |
| Population-adjusted comparison (MAIC) | 3.4, section 4.6 | 18 |
| Observational / RWE for effectiveness | section 4.6 | 17 |
| Diagnostic test accuracy synthesis | (diagnostics) | 25 |
| PSA software / implementation | section 4.7 | 6 |
