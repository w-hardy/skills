# ADR Format

ADRs live in `docs/adr/` (or the repo's existing documentation location) and use sequential numbering: `0001-slug.md`, `0002-slug.md`, etc.

Create the `docs/adr/` directory lazily: only when the first ADR is needed.

## Template

```md
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

That's it. An ADR can be a single paragraph. The value is in recording *that* a decision was made and *why*, not in filling out sections.

## Optional sections

Only include these when they add genuine value. Most ADRs won't need them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`): useful when decisions are revisited
- **Considered Options**: only when the rejected alternatives are worth remembering
- **Consequences**: only when non-obvious downstream effects need to be called out

## Required for analysis-plan deviations

When the ADR records a departure from a signed-off SAP or HEAP, always include:

- **Plan reference**: the plan, its version, and the section departed from
- **Timing**: whether the decision was made before or after outcome data (or unblinded results) were seen
- **Reporting**: where the deviation will be reported (for example the paper's methods or a supplement)

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one.

## When to offer an ADR

All three of these must be true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful
2. **Surprising without context**: a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If a decision is easy to reverse, skip it: you'll just reverse it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond "we did the obvious thing." Deviations from an analysis plan are the exception: always record them.

### What qualifies

- **Analytic strategy.** "Two imputation models: pooled arms for the primary analysis, arm-specific for the model-based extension." "Survival models fitted separately by cohort rather than with a cohort covariate."
- **Choices that are expensive to rerun.** Anything that would invalidate long-running cached fits, bootstrap or MCMC runs, or linked extracts.
- **Data scope and boundary decisions.** Which linked datasets are in, the costing window, the unit of analysis. The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path or the reference case.** "Costs and QALYs are analysed jointly rather than separately because X." Anything where a reasonable reader would assume the opposite. These stop the next analyst from "fixing" something that was deliberate.
- **Constraints not visible in the code.** Data-sharing agreements, disclosure-control rules, a funder's or decision maker's required perspective.
- **Rejected alternatives when the rejection is non-obvious.** If you considered a multistate model and chose a Markov cohort model for specific reasons, record it; otherwise someone will suggest it again at review.
- **Software architecture**, for packages, Shiny apps and tooling: module boundaries, technology choices with lock-in, integration patterns.

---
Adapted from `skills/engineering/domain-modeling/ADR-FORMAT.md` in mattpocock/skills (MIT), commit 59db609. Analysis examples and the deviation section added, 28 October 2026.
