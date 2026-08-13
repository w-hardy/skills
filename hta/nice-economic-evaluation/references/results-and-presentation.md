# Presenting data and results (4.10)

*Source: PMG36 — NICE technology appraisal and highly specialised technologies guidance:
the manual, as amended 31 March 2026, chapter 4, section 4.10.
<https://www.nice.org.uk/process/pmg36>. Clause numbers and the £25,000/£35,000 net-health-
benefit values verified against the live manual (4.10.8 is cross-referenced by 4.2.16),
3 July 2026.*

How results are presented is itself a reference-case expectation. The committee needs to
see the workings, not just a headline ICER.

## Inputs and disaggregation (4.10.1–4.10.5)
- All parameters used to estimate clinical and cost effectiveness in tables, with central
  value, **measure of precision**, and **source**; describe how bias was assessed per source.
- HRQoL: a table of each utility value, its **source**, and the **method** used to derive it
  (e.g. EQ-5D-5L, EQ-5D-3L, standard gamble) (4.10.3).
- A disaggregated table including (4.10.4):
  - costs by health state and resource category,
  - benefits, QALYs and life years by health state,
  - decrements from further interventions and adverse events.
  Present these **with and without discounting**.
- Survival: Kaplan–Meier and parametric curves, and hazard plots (observed vs model
  predictions), in graphs **and** tables, showing numbers at risk at each time point (4.10.5).

## Cost-effectiveness results (4.10.6–4.10.8)
- Expected value of each cost component and expected total costs; expected total QALYs;
  ICERs calculated as appropriate (4.10.6).
- Present the **life-year component** of QALYs separately, and costs/QALYs by stage (4.10.7).
- Results in a **fully incremental analysis**: remove technologies that are **dominated**
  (more costly and less effective) and **extendedly dominated** (a combination of two others
  is more cost effective), then compute sequential ICERs along the efficiency frontier
  (4.10.8). Pairwise comparisons may be added where justified (e.g. the technology
  specifically displaces one comparator).
- **Net health benefit** should be presented where appropriate, using QALY values of
  **£25,000 and £35,000**, both with and without any decision modifiers (4.10.8). NHB is
  especially informative when there are several comparators, small cost/QALY differences,
  subgroup considerations, or south-west-quadrant results (less benefit at lower cost).

> Note on the fully incremental frontier: the script `scripts/nice_calcs.py` does this
> deterministically. Use it rather than eyeballing dominance — extended dominance in
> particular is easy to miss by eye.

## Common review findings
- A single pairwise ICER reported where a fully incremental analysis across all scope
  comparators was required.
- Dominated / extendedly dominated options left on the frontier, inflating or deflating the
  reported ICER.
- Costs and QALYs presented only discounted, or only aggregated (no disaggregation by health
  state / resource category).
- No life-year breakdown, so the survival vs HRQoL contribution to QALYs is opaque.
- Net health benefit omitted where modifiers, multiple comparators or SW-quadrant results
  make it the clearer summary.
