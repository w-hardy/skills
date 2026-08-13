# The NICE reference case (Chapter 4)

*Source: PMG36 — NICE technology appraisal and highly specialised technologies guidance:
the manual, as amended 31 March 2026, chapter 4 (economic evaluation).
<https://www.nice.org.uk/process/pmg36>. Verified 3 July 2026.*

The reference case is the set of methods NICE has defined as appropriate for its
committees' decisions. Every economic evaluation submitted to NICE **must include a
reference-case analysis** (4.2.1). Analyses that depart from the reference case are
permitted, but each departure must be (a) clearly specified, (b) justified on its merits,
and (c) its likely implications quantified (4.2.1, 4.2.3). The committee then decides how
much weight to give a non-reference-case analysis.

So when you align work to the reference case, the question for each element is rarely a
flat "compliant / non-compliant". It is one of four states:

- **Aligned** — matches the reference case.
- **Justified deviation** — departs, but with a stated, evidence-backed reason and the
  impact quantified. This is legitimate and often expected (e.g. mapping to EQ-5D,
  non-lifetime horizon when there is no mortality difference).
- **Unjustified deviation** — departs with no reason given or no quantification of impact.
  This is the main thing to flag: it isn't fatal, but the user needs to add justification
  + a reference-case version, or the committee will likely discount it.
- **Missing / unclear** — the element can't be located in the work, so it can't be assessed.

Always cite the clause (e.g. "4.5.1", "Table 4.1") so the user can verify it and quote it
in their submission.

## Table 4.1 — Summary of the reference case

| Element | Reference case | Clause |
|---|---|---|
| Defining the decision problem | The scope developed by NICE | 4.2.4–4.2.6 |
| Comparator(s) | As listed in the NICE scope | 2.2.12–2.2.16, 4.2.6, 4.2.13 |
| Perspective on outcomes | All health effects, whether for patients or, when relevant, carers | 4.2.7–4.2.8 |
| Perspective on costs | NHS and Personal Social Services (PSS) | 4.2.9–4.2.10 |
| Type of economic evaluation | Cost-utility analysis with fully incremental analysis (or cost-comparison where appropriate) | CUA 4.2.14–4.2.17; cost-comparison 4.2.18–4.2.21 |
| Time horizon | Long enough to reflect all important differences in costs or outcomes between the technologies | 4.2.22–4.2.25 |
| Synthesis of evidence on health effects | Based on systematic review | 3.4 |
| Measuring and valuing health effects | QALYs; EQ-5D is the preferred measure of HRQoL in adults | 4.3.1, 4.3.6 |
| Source of HRQoL data | Reported directly by patients or carers | 4.3.3 |
| Source of preference (valuation) data | Representative sample of the UK population, choice-based method | 4.3.4 |
| Equity | An additional QALY has the same weight regardless of the characteristics of the people receiving the benefit, except in specific circumstances | 6.2.10 |
| Evidence on resource use and costs | NHS and PSS resources, valued at prices relevant to the NHS and PSS | 4.4.1 |
| Discounting | Same annual rate for costs and health effects (currently 3.5%) | 4.5.1 |

The last six rows (measuring/valuing health, HRQoL source, preference source, equity)
are relevant to **cost-utility analysis**, not cost-comparison.

## Element detail and the most common review findings

### Decision problem and comparators (4.2.4–4.2.6, 4.2.13)
Must match the final NICE scope: the technology, its place in the pathway, the patient
population, and **all** comparators in the scope. Dropping a scope comparator, or
comparing against something not in established NHS practice, is a frequent and serious
deviation. Any difference from the scope must be justified.

### Perspective on outcomes (4.2.7–4.2.8)
All relevant health effects for patients and, where relevant, carers. "Process
characteristics" (e.g. convenience, speed of diagnosis, information for patients) that
indirectly affect health should be quantified where possible.

### Perspective on costs (4.2.9–4.2.10)
NHS and PSS only. **Productivity costs are excluded from the reference case** (4.2.9;
see also section 4.4) — they can be presented separately. Benefits to other government
bodies (e.g. reduced crime) are non-reference-case and must be agreed with DHSC, presented
disaggregated and separately (4.2.10). Carer time that would otherwise fall to the NHS/PSS
may be costed even under an NHS/PSS perspective, but shown separately (section 4.4).

### Type of evaluation (4.2.14–4.2.21)
- **Cost-utility analysis (CUA)** is the default: justifies cost differences in terms of
  QALY differences. Combine costs and QALYs with standard decision rules, reflecting
  dominance and extended dominance through a **fully incremental** analysis. ICER = ratio
  of incremental total cost to incremental QALYs vs the appropriate comparator. Net health
  benefit should also be presented (4.2.16).
- **Cost-comparison analysis** is used where the technology is likely to give similar (or
  greater) health benefit at similar or lower cost than comparator(s) already recommended
  in NICE guidance for the same population. Health effects are captured in the clinical
  evidence and excluded from the cost model; substantial cost differences tied to outcomes
  (e.g. adverse events) signal the benefits may not be similar and must be justified
  (4.2.18–4.2.21).

### Time horizon (4.2.22–4.2.25)
Long enough to capture all important differences. A **lifetime horizon is usually
appropriate** where technologies differ in survival or have lifelong effects (4.2.23).
Lifetime horizons typically require extrapolation beyond trial data, with alternative
scenarios for the long-term effect — including a scenario where the technology gives no
further benefit after treatment stops, alongside more optimistic ones (4.2.24). A horizon
shorter than lifetime needs justification: no differential mortality and short-lived cost/
outcome differences (4.2.25).

### Measuring and valuing health (4.3.1–4.3.10)
- Health effects in **QALYs** for CUA.
- HRQoL measured **directly from patients** (carers only where patients cannot, never
  healthcare professionals) (4.3.3).
- Valued using **UK general public preferences**, choice-based method (4.3.4).
- **EQ-5D is preferred for adults** (4.3.6). Where EQ-5D was not collected, mapping to
  EQ-5D (4.3.9) or an alternative instrument (4.3.10) is a justified deviation — state the
  method (e.g. EQ-5D-5L vs 3L, mapping algorithm) and test it in sensitivity analysis.
  Different instruments give different utilities and are not directly comparable (4.3.5).

### Resource use and costs (4.4.1; section 4.4)
NHS/PSS resources, valued at NHS/PSS prices, identified **systematically** (4.4.1). Use
prices that reflect what the NHS actually pays, including known national price reductions
(PAS, commercial access agreements, eMIT, Medicines Procurement and Supply Chain (MPSC)
prices, drug tariff, NHS Supply Chain) (section 4.4 — the 2026 amendments revised the
pricing clauses, so cite the section rather than a sub-clause number). Include
infrastructure, maintenance and, where appropriate, staff training (section 4.4).

### Discounting (4.5.1–4.5.4)
Reference case: **3.5%** for both costs and health effects; a 1.5% analysis may be
presented alongside (4.5.1). A **1.5%** rate (both costs and effects) is considered by the
committee only if **all** of these hold (4.5.2–4.5.4):
- the technology is for people who would otherwise die or have a very severely impaired life;
- it is likely to restore them to full or near-full health;
- the benefits are likely to be sustained over a very long period;
- there is a highly plausible case for maintenance of benefit over time;
- irrecoverable costs are appropriately captured or mitigated.
A 1.5% rate applied without meeting these conditions, or applied to effects only, is an
unjustified deviation.

### Equity (6.2.10)
Default: every QALY weighted equally. Exceptions are handled through **decision modifiers**
(severity in particular) — see `decision-making.md`. Bespoke QALY weighting outside the
recognised modifiers is exceptional and needs strong moral/evidential justification.

## Quick checklist for a reference-case review

For each, record status (Aligned / Justified deviation / Unjustified deviation / Missing):
1. Population, positioning and **all** comparators match the final scope.
2. Outcome perspective = all health effects (patients + carers where relevant).
3. Cost perspective = NHS & PSS; productivity costs excluded from the base case.
4. CUA with QALYs (or a properly justified cost-comparison).
5. Results presented as a **fully incremental** analysis (dominance/extended dominance
   handled) with ICERs and net health benefit.
6. Time horizon long enough — lifetime unless a short horizon is justified.
7. Health effects synthesised from a systematic review.
8. QALYs from EQ-5D (adults), patient-reported, UK public preference values.
9. Costs from NHS/PSS prices reflecting actual prices paid, identified systematically.
10. Discounting 3.5% for both (1.5% only if all five conditions met).
11. Severity modifier considered (absolute & proportional QALY shortfall) — see decision-making.md.
12. Uncertainty fully explored (PSA, scenario and sensitivity analyses) — see modelling-and-uncertainty.md.
