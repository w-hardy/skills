---
name: domain-modeling
description: Build and sharpen a project's domain model - its glossary of terms and its record of hard-to-reverse decisions - for software or analysis projects. Use when resolving what a project's terms mean (for example episode vs spell, ITT vs complete-case, perspective), writing or editing GLOSSARY.md, or recording or editing an ADR or a deviation from an analysis plan. Merely reading a glossary for vocabulary is not this skill.
license: MIT (adapted from mattpocock/skills; see LICENSE)
---

# Domain Modeling

Actively build and sharpen the project's domain model as you design. This is the *active* discipline: challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise. (Merely *reading* `GLOSSARY.md` for vocabulary is not this skill: that's a one-line habit any skill can do. This skill is for when you're changing the model, not just consuming it.)

## File structure

Most repos have a single context:

```
/
├── GLOSSARY.md
├── docs/
│   └── adr/
│       ├── 0001-pooled-imputation-for-primary-analysis.md
│       └── 0002-separate-survival-models-by-cohort.md
└── R/
```

If a `GLOSSARY-MAP.md` exists at the root, the repo has multiple contexts (for example a trial repo holding both the clinical analysis and the economic evaluation, which use some words differently). The map points to where each one lives; see [references/GLOSSARY-FORMAT.md](references/GLOSSARY-FORMAT.md).

If the repo already keeps documentation elsewhere (a `docs/` or `analysis/` convention, or a location set in `CLAUDE.md`), follow that convention instead and say where you put things.

Create files lazily: only when you have something to write. If no `GLOSSARY.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

These are documentation edits only. Never change analysis code, cached results, or anything that would force a recompute while doing this, and follow any constraints `CLAUDE.md` sets.

Outside a repo, keep the glossary and ADRs in the conversation and offer them as a document at the end.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `GLOSSARY.md`, call it out immediately. "Your glossary defines 'admission' as a hospital provider spell, but you seem to mean a single consultant episode. Which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'patients': do you mean everyone randomised, or those with complete cost and outcome data? Those give different answers."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts: the participant who dies before the first follow-up, the admission that spans the end of the costing window, the linkage record matched to the wrong arm.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "You said costs are discounted at 3.5% from year two, but the discounting function starts at year one. Which is right?"

### Cite terms that come from a standard

When a term has an external definition (NHS Data Dictionary, ICH E9(R1) estimand language, a reporting guideline, a dataset's own documentation), use that definition, cite the source and the date you checked it, and record any deliberate local departure from it. Mark definitions that are the project's own as such.

### Update GLOSSARY.md inline

When a term is resolved, update `GLOSSARY.md` right there. Don't batch these up: capture them as they happen. Use the format in [references/GLOSSARY-FORMAT.md](references/GLOSSARY-FORMAT.md).

`GLOSSARY.md` should be totally devoid of implementation details. Do not treat it as a spec, a scratch pad, a codebook or a repository for implementation decisions. Variable names, derivation rules and code lists belong in the data dictionary or codebook; the glossary says what the concept *is*.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful
2. **Surprising without context**: a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR.

**Exception: deviations from a prespecified analysis plan.** Any decision that departs from a signed-off SAP or HEAP is always recorded, whether or not it passes the three tests, together with when it was made relative to seeing outcome data. Reviewers and reporting guidelines expect deviations to be accounted for.

Use the format in [references/ADR-FORMAT.md](references/ADR-FORMAT.md).

## Provenance

Adapted from `skills/engineering/domain-modeling/` in mattpocock/skills (MIT), commit 59db609, 27 October 2026. Structure, rules and the three-test ADR criterion are Matt Pocock's. Added on 28 October 2026: analysis-project examples, existing-convention and no-recompute rules, the no-repo fallback, citing externally defined terms, the codebook boundary, and the always-record rule for analysis-plan deviations.
