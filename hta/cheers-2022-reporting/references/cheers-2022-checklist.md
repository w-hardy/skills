# CHEERS 2022 Checklist — Full Reference

**Attribution.** Checklist item wording reproduced from: Husereau D, Drummond M, Augustovski F, et al.; CHEERS 2022 ISPOR Good Research Practices Task Force. Consolidated Health Economic Evaluation Reporting Standards 2022 (CHEERS 2022) Statement. *Value in Health*. 2022;25(1):3–9 (co-published in BMJ 2022;376:e067975 and other journals). Licensed under CC BY 4.0. Interpretive notes are paraphrased from the Explanation and Elaboration (E&E) report: Husereau D, et al. *Value in Health*. 2022;25(1):10–31 (also CC BY 4.0). Consult the E&E report for illustrative examples per item.

## Contents

- [How to complete the checklist](#how-to-complete-the-checklist)
- [Applicability quick reference](#applicability-quick-reference)
- Items 1–2: [Title and Abstract](#title-and-abstract)
- Item 3: [Introduction](#introduction)
- Items 4–21: [Methods](#methods)
- Items 22–25: [Results](#results)
- Item 26: [Discussion](#discussion)
- Items 27–28: [Other relevant information](#other-relevant-information)

## How to complete the checklist

- Record the location of each item as **section heading plus paragraph number** (e.g. "Methods, para 3"). Avoid page or line numbers: they shift with repagination and typesetting.
- **"Not applicable" (NA)**: the item genuinely cannot apply to this study type (see applicability table below).
- **"Not reported" (NR)**: the item applies but the information is absent from the manuscript and its supplementary material.
- **Never use "Not conducted"**: CHEERS captures reporting, not conduct. If PPIE was not undertaken, a statement to that effect satisfies item 21; silence is NR.
- **No scoring.** There is no validated scoring system. Do not produce counts, percentages, or summary scores of items met — the Task Force strongly discourages this because it misleads. Qualitative, item-level assessment only.
- Supplementary appendices count as part of the report. Adequate reporting is expected to exceed journal space limits; check supplements before recording NR.

## Applicability quick reference

| Study type | Items typically NA |
|---|---|
| Cost analysis (costs only, no consequences) | 11, 12, 13 |
| Non-modelling study (e.g. within-trial analysis with no decision model) | 16, and 22 where there are no model inputs to tabulate (trial-based parameter tables may still satisfy 22) |
| Single-country study with no currency conversion | Conversion element of 15 (currency and price year still required) |
| Time horizon ≤ 1 year | Discounting may not be applied, but item 10 still requires the rate to be reported explicitly as 0% |

Everything else applies to every economic evaluation. Items 4, 19, 21, and 25 apply universally — absence of a HEAP, of distributional analysis, or of PPIE is recorded as reported-absent (if stated) or NR (if silent), not NA.

---

## Title and Abstract

### Item 1 — Title
**Guidance:** Identify the study as an economic evaluation and specify the interventions being compared.
**Notes:** The purpose is discoverability — search filters for economic evaluations have poor sensitivity. The title should contain "economic evaluation" or the specific analysis form ("cost-effectiveness analysis", "cost-utility analysis", "cost-benefit analysis", "distributional cost-effectiveness analysis") and name the interventions/comparators, ideally with the setting.
**Common failures:** analysis type implied but not named; comparator omitted; branded intervention name without describing what it is.

### Item 2 — Abstract
**Guidance:** Provide a structured summary that highlights context, key methods, results, and alternative analyses.
**Notes:** The E&E recommends ~300 words (respecting journal limits) covering: objective; study population and setting (including country); comparators; time horizon; perspective; currency and price year; discount rate; key inputs; mean costs and outcomes for base case and key alternative/uncertainty analyses; conclusions including implications for patients/policy. The abstract must be consistent with the full text and contain nothing that isn't in the body. A plain-language summary is encouraged.
**Common failures:** unstructured abstract; results given only as an ICER with no mean costs/outcomes; no currency year or perspective; conclusions stronger than the body supports.

## Introduction

### Item 3 — Background and objectives
**Guidance:** Give the context for the study, the study question, and its practical relevance for decision making in policy or practice.
**Notes:** "The purpose was to assess the cost-effectiveness of X" is insufficient. State the decision problem: who the decision maker is (if any), why the question matters now, and specify population/subgroups, setting/location, perspective, and comparators consistently with items 5–8. Inconsistency between the stated objective and the methods items is a frequent audit finding.

## Methods

### Item 4 — Health economic analysis plan (NEW in 2022)
**Guidance:** Indicate whether a health economic analysis plan was developed and where available.
**Notes:** Analogous to a statistical analysis plan; guards against selective reporting. A simple statement that a HEAP was (or was not) developed satisfies the item; where one exists, say where it can be accessed (supplement, repository, trial registry). Thorn et al.'s Delphi consensus (58 core HEAP items) is the nearest thing to a template. Silence = NR, not NA — this item applies to every study type.

### Item 5 — Study population
**Guidance:** Describe characteristics of the study population (such as age range, demographics, socioeconomic, or clinical characteristics).
**Notes:** Needed for relevance and transferability judgements. Include baseline characteristics and any identifiable subgroups (univariate or multivariate risk-defined). Where effectiveness comes from a source study, that study often defines the population — cite and summarise it rather than assuming the reader will look it up.

### Item 6 — Setting and location
**Guidance:** Provide relevant contextual information that may influence findings.
**Notes:** Country/countries, care setting (primary/secondary/tertiary/community/public health), and system features (payment scheme, insurance model) that bear on external validity and transferability.

### Item 7 — Comparators
**Guidance:** Describe the interventions or strategies being compared and why chosen.
**Notes:** Describe content, not just labels: dose/schedule/route/duration for drugs; intensity, frequency, components, and delivery flexibility for complex interventions (TIDieR and CReDECI 2 can structure this). "Usual care" and "do nothing" still need their underlying components described. Justify comparator choice, and explain omission of a cheaper, more common, or more effective alternative where one exists.

### Item 8 — Perspective
**Guidance:** State the perspective(s) adopted by the study and why chosen.
**Notes:** Perspectives lack standard definitions and are often misspecified, so define the perspective by the cost components included (direct medical, direct non-medical, informal care, productivity, other sectors), not just by name. The Second Panel's impact inventory table is a recommended device. State why the perspective fits the decision problem and, if applicable, which decision maker the study serves.

### Item 9 — Time horizon
**Guidance:** State the time horizon for the study and why appropriate.
**Notes:** Justify sufficiency: long enough to capture the important differences in costs and consequences. Where the horizon extends beyond observed follow-up, consider reporting within-follow-up results alongside extrapolated results so readers can see the weight extrapolation carries.

### Item 10 — Discount rate
**Guidance:** Report the discount rate(s) and reason chosen.
**Notes:** Rates are jurisdiction-specific, so cite the local guideline or treasury source. Report both cost and outcome rates (they may differ). For horizons of a year or less, report 0% explicitly rather than staying silent.

### Item 11 — Selection of outcomes
**Guidance:** Describe what outcomes were used as the measure(s) of benefit(s) and harm(s).
**Notes:** Define outcomes precisely (terms like "severe exacerbation" lack standard definitions). For composites (QALYs, DALYs, MACE), explain the components and how they combine. Give the rationale for the choice, including relevance to patients and stakeholders; if a primary outcome was prespecified, cite the protocol and justify excluding other prespecified outcomes. NA for cost analyses.

### Item 12 — Measurement of outcomes
**Guidance:** Describe how outcomes used to capture benefit(s) and harm(s) were measured.
**Notes:** If effectiveness estimates are reported here for the first time, follow the relevant primary reporting guideline (CONSORT, STROBE, PRISMA, etc.). For preference-based measures, describe construction (e.g. area-under-the-curve QALYs), linking to items 13 and 17. NA for cost analyses.

### Item 13 — Valuation of outcomes
**Guidance:** Describe the population and methods used to measure and value outcomes.
**Notes:** For multi-attribute utility instruments, report: instrument name and version (e.g. EQ-5D-3L vs 5L), administration format and frequency, valuation method, value-set population (size, demographics, country tariff), and any proxy measurement with justification. Mapping requires the MAPS statement; de novo elicitation (TTO, SG, DCE, contingent valuation) has its own guidance; literature-derived values should state whether a systematic review was done. NA for cost analyses.

### Item 14 — Measurement and valuation of resources and costs
**Guidance:** Describe how costs were valued.
**Notes:** Two separable choices to make transparent: granularity of identification/measurement (micro- vs gross-costing) and valuation method (bottom-up vs top-down), plus data sources for both resource quantities (trial CRFs, routine data, literature) and unit costs (national schedules, institutional lists). Where different components use different approaches, describe each. Note adjustments approximating opportunity cost (e.g. capital assets).

### Item 15 — Currency, price date, and conversion
**Guidance:** Report the dates of the estimated resource quantities and unit costs, plus the currency and year of conversion.
**Notes:** Report the price year, the currency (ISO 4217 codes help where names collide — USD, AUD, CAD), any inflation adjustment method (named index), and any currency conversion method (e.g. purchasing power parities), including the order of operations when both are applied. Frequently under-reported; check tables as well as text.

### Item 16 — Rationale and description of model
**Guidance:** If modelling is used, describe in detail and why used. Report if the model is publicly available and where it can be accessed.
**Notes:** Justify the model type for the decision problem (published taxonomies help), relate the structure to disease natural history and prior models in the area, and describe it in enough detail to replicate — a structure diagram is recommended in most cases. The public-availability statement is NEW in 2022: report whether the model can be accessed and where; absence of a statement is NR. NA for non-modelling studies.

### Item 17 — Analytics and assumptions
**Guidance:** Describe any methods for analysing or statistically transforming data, any extrapolation methods, and approaches for validating any model used.
**Notes:** A broad item covering: statistical/analytic methods; all assumptions with their rationale and basis (data source, expert opinion, convention); transformations and extrapolation (e.g. survival extrapolation, durability of treatment effect); QALY construction if not covered under 12; and model validation/calibration approach (what type of validation was undertaken). Sharing unlocked models with reviewers is encouraged. Appendices usually carry the load here.

### Item 18 — Characterizing heterogeneity
**Guidance:** Describe any methods used for estimating how the results of the study vary for subgroups.
**Notes:** Distinguish heterogeneity from uncertainty. Cover both baseline-risk heterogeneity (constant relative effects, varying absolute effects) and effect modification. If homogeneity is assumed, justify it — an explicit justified assumption satisfies the item; silence is NR.

### Item 19 — Characterizing distributional effects (NEW in 2022)
**Guidance:** Describe how impacts are distributed across different individuals or adjustments made to reflect priority populations.
**Notes:** Covers equity-relevant methods: population-specific parameters, equity weights, threshold adjustments (rare disease, end of life), DCEA methods and equity-efficiency trade-off devices. State the premise (jurisdictional requirement or normative position). **If distributional concerns were not considered, an explicit statement to that effect is required** — that statement satisfies the item; silence is NR.

### Item 20 — Characterizing uncertainty
**Guidance:** Describe methods to characterize any sources of uncertainty in the analysis.
**Notes:** Cover the methods for each relevant source: sampling/statistical uncertainty for IPD-based analyses (CEACs and CE planes are preferred over bare intervals); parameter uncertainty (deterministic and probabilistic analysis); and methodological/structural uncertainty (discount rate, perspective, model structure, extrapolation choices). This is the methods-side counterpart of item 24.

### Item 21 — Approach to engagement with patients and others affected by the study (NEW in 2022)
**Guidance:** Describe any approaches to engage patients or service recipients, the general public, communities, or stakeholders (such as clinicians or payers) in the design of the study.
**Notes:** Deliberately broad given PPIE in economic evaluation is young. Report the approach used, however modest; GRIPP2 provides detailed structure if wanted. Stakeholder involvement (clinicians, payers, industry) counts. Applies to every study; "no engagement was undertaken" is a valid, complete report. Silence is NR, not NA.

## Results

### Item 22 — Study parameters
**Guidance:** Report all analytic inputs (such as values, ranges, references) including uncertainty or distributional assumptions.
**Notes:** A parameter table with values, ranges, distributions (type and moments for PSA), and sources is the expected form — key parameters in the main text, the full set in a supplement. Note CHEERS places this in Results, since inputs are often themselves analytic outputs (transformed per items 9–17). NA only where there are genuinely no analytic inputs to tabulate.

### Item 23 — Summary of main results
**Guidance:** Report the mean values for the main categories of costs and outcomes of interest and summarise them in the most appropriate overall measure.
**Notes:** Mean costs (by category and total) and mean outcomes **per comparator**, both discounted and undiscounted, before any summary measure. Then ICERs/net benefit as appropriate. Specific rules: do not report negative ICERs (meaningless for decisions — describe dominance instead); NMB/NHB must state the threshold and its source; report disaggregated results by perspective where multiple perspectives are used; report weighted and unweighted results where distributional weights are applied; consider subgroup means where heterogeneity was examined.
**Common failures:** ICER-only reporting without underlying means; discounted results only; negative ICER reported as a number.

### Item 24 — Effect of uncertainty
**Guidance:** Describe how uncertainty about analytic judgments, inputs, or projections affect findings. Report the effect of choice of discount rate and time horizon, if applicable.
**Notes:** The results-side counterpart of item 20. Report uncertainty intervals for quantities; tornado diagrams for deterministic analyses; CE-plane scatter plots and CEACs for probabilistic analysis; and — explicitly required — the effect of varying the discount rate and time horizon where applicable. Structural/methodological scenario results belong here too.

### Item 25 — Effect of engagement with patients and others affected by the study (NEW in 2022)
**Guidance:** Report on any difference patient/service recipient, general public, community, or stakeholder involvement made to the approach or findings of the study.
**Notes:** The results counterpart of item 21: what difference did the involvement make (scope, methods, interpretation, process)? If item 21 reports no engagement, this item is satisfied by that statement (record as NA with cross-reference, or reported-absent); if engagement occurred but its effect is unstated, NR.

## Discussion

### Item 26 — Study findings, limitations, generalizability, and current knowledge
**Guidance:** Report key findings, limitations, ethical or equity considerations not captured, and how these could affect patients, policy, or practice.
**Notes:** Expect: key results tied back to the decision problem; main areas of uncertainty; limitations addressing the impact of assumptions and methodological choices (including validation gaps or absence of validation); notable subgroup/distributional findings and ethical/equity considerations; relation to decision-making frameworks or thresholds in the relevant jurisdiction; comparison with prior literature; generalizability/transferability; and future research directions.

## Other relevant information

### Item 27 — Source of funding
**Guidance:** Describe how the study was funded and any role of the funder in the identification, design, conduct, and reporting of the analysis.
**Notes:** Funding correlates with direction of findings in economic evaluation, hence the emphasis on the funder's *role*, not just identity. Include non-monetary support. "No funding was received" is a complete report.

### Item 28 — Conflicts of interest
**Guidance:** Report authors' conflicts of interest according to journal or International Committee of Medical Journal Editors requirements.
**Notes:** Declare anything readers might perceive as competing, irrespective of the authors' own view of their impartiality. In the absence of a journal policy, the ICMJE form is the default; minimum: financial interests within 36 months of publication plus anything else that could appear to have influenced the work.
