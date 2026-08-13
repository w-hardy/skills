# Decision making: value for money and modifiers (Chapter 6)

*Source: PMG36 — NICE technology appraisal and highly specialised technologies guidance:
the manual, as amended 31 March 2026, chapter 6 (committee recommendations).
<https://www.nice.org.uk/process/pmg36>. All clause numbers in this file verified against
the live chapter, 3 July 2026.*

How the committee turns an ICER into a recommendation. Aligning your analysis here means
presenting results in the form the committee reasons with — most plausible ICER, net health
benefit, and the severity modifier — not just a point estimate.

> **Threshold values in this manual.** This (31 March 2026) version of PMG36 states the
> standard cost-effectiveness range as **£25,000 to £35,000 per QALY gained**, and
> **£100,000 per QALY** for highly specialised technologies (HST). These are the values the
> manual uses throughout (4.10.8, 6.3.4–6.3.9). Note this differs from the long-standing
> £20,000–£30,000 range; encode whatever the user's target version of the manual specifies,
> but for this document the values are £25,000 / £35,000 / £100,000.

## The most plausible ICER and the threshold (6.3.4–6.3.9)
- **Below £25,000/QALY** (£100,000 for HST): the recommendation normally rests on the
  cost-effectiveness estimate and acceptability as an effective use of NHS resources. If
  the committee declines despite an ICER under £25,000, it must say why (plausibility of
  inputs, certainty around the ICER) (6.3.4).
- **£25,000–£35,000/QALY**: as the ICER rises through this range, the committee makes
  explicit reference to (6.3.5, 6.3.7): the degree of certainty/uncertainty around the
  ICER; uncaptured benefits and non-health factors; and health-inequality aspects.
- **Above £35,000/QALY** (above £100,000 for HST): an increasingly strong case is needed,
  considering the factors in 6.3.5 (and, for HST, service-delivery factors in 6.3.6) (6.3.8).
- **South-west quadrant** (less benefit at lower cost): apply the same £25,000–£35,000
  levels plus any relevant modifiers (6.3.9).
- The committee wants **more certainty as the budget impact rises** (6.2.31), but is mindful
  that evidence is harder to generate for rare diseases, mainly-children populations, and
  innovative/complex technologies (6.2.33).

## Decision modifiers (6.2.10–6.2.24; health inequalities 6.2.35–6.2.38)
Modifiers capture value that the QALY cannot, applied qualitatively in discussion or
quantitatively as a QALY weight. Deviating from equal QALY weighting must be "morally and
ethically supported by reason, coherence, and available evidence" (6.2.10–6.2.11).

### Severity modifier (6.2.12–6.2.21) — the main quantitative modifier
Severity = the future health lost by people with the condition under current NHS care; it
also captures unmet need (6.2.12). Assessed via two measures (6.2.13–6.2.15):

- **Absolute QALY shortfall** = (QALYs the age/sex-matched general population would expect
  over their remaining lifetime) − (QALYs people with the condition expect under current
  treatment). The "with condition" QALYs equal total QALYs under established NHS practice.
- **Proportional QALY shortfall** = absolute shortfall ÷ general-population remaining QALYs.

Both use general-population EQ-5D and survival from a recent, robust source, and **both are
discounted at the reference-case rate** (6.2.17). Calculate the shortfall using the method in
**DSU TSD 23** (*A guide to calculating severity shortfall*, updated March 2026) — the
current authoritative reference for the general-population values, age/sex matching and
discounting; see `tsd-index.md`.

**Table 6.1 — QALY weightings for severity**

| QALY weight | Proportional QALY shortfall | Absolute QALY shortfall |
|---|---|---|
| 1 | Less than 0.85 | Less than 12 |
| ×1.2 | 0.85 to 0.95 | 12 to 18 |
| ×1.7 | At least 0.95 | At least 18 |

Use **whichever of absolute/proportional implies the greater severity** (the higher weight).
If a value falls exactly on a cut-off between levels, the **higher** level applies (6.2.18).

Applying the weight: multiply incremental QALYs by the weight (equivalently, raise the
effective threshold). A weight of ×1.7 against a £25,000 base means an effective comparison
point of £42,500/QALY for the weighted ICER, or weight the QALYs in the net-health-benefit
calculation. Technologies recommended with a severity weight become comparators for future
evaluations (6.2.21).

**Scope of the severity modifier:**
- **Does not apply to HST** — severity is already implicit in HST selection; no extra
  weighting (6.2.20).
- **Diagnostics**: a shortfall-based weight is unlikely to reflect societal value
  appropriately (6.2.19).
- **HealthTech technology appraisals**: severity is captured within the QALYs and considered
  deliberatively; NICE is still developing how the modifier applies here (6.2.12).

### Health inequalities modifier (6.2.35–6.2.38) — added May 2025
Where a technology addresses issues that have a **substantial impact on health
inequalities**, the committee may apply **flexibility to the acceptable ICER range**
(6.2.38). This modifier is distinct from NICE's legal duties under the Equality Act
(6.2.36) — it is a value judgement about reducing health inequality, not a compliance
step. It links to the health-inequality impact analysis the manual asks for in the
economic evaluation (section 4.12), and to 6.3.5/6.3.7, where health-inequality aspects
are among the factors the committee weighs as the ICER rises through £25,000–£35,000.
If the user's technology plausibly reduces a recognised inequality, flag that presenting
the impact explicitly (who benefits, how the inequality is reduced, quantified where
possible) gives the committee a basis to apply this modifier.

### HST size-of-benefit modifier (6.2.22–6.2.24)
For HST only, where there is compelling evidence of significant QALY gains, a weight between
1 and 3 (equal increments) is applied by **incremental QALYs gained per patient over a
lifetime horizon**:

**Table 6.2 — QALY weightings for size of benefit (HST)**

| Incremental QALYs gained (lifetime, per patient) | Weight |
|---|---|
| ≤ 10 | 1 |
| 11 to 29 | between 1 and 3, equal increments |
| ≥ 30 | 3 |

This is considered against whether the weight needed brings cost effectiveness within the
HST £100,000/QALY level (6.2.22).

## Structured decision making (6.2.25–6.3.3)
- **Opportunity cost.** NICE considers overall NHS resources; recommending a technology
  displaces care elsewhere, including programmes NICE has not evaluated (6.2.25).
- Decisions weigh: strength of clinical evidence; robustness/appropriateness of the model
  structure; plausibility of inputs; the most plausible ICER and its uncertainty (6.2.27).
- **Net health benefit** framing: a technology with negative *unweighted* NHB may still be
  recommended once modifiers are applied, on the ethical rationale for weighting those
  health gains more (6.3.2). Rankograms / expected NHB help where several technologies
  compete (6.3.3).
- Where uncertainty is high and material, the committee may recommend **managed access**
  (medicines only), data collection, or research instead of routine use (6.2.30, 6.4).

## Common review findings
- Severity assessed on proportional shortfall only (or absolute only), not the higher of the
  two; or general-population QALYs not discounted.
- Severity weight claimed but the shortfall calculation not shown / not age-sex matched to
  the treated population.
- A severity weight applied to an HST (should be size-of-benefit instead) or to a
  diagnostic.
- Results presented as a bare ICER with no net health benefit and no positioning against the
  £25,000–£35,000 range with the relevant uncertainty/inequality factors.
