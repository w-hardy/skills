# GLOSSARY.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Hospital provider spell**:
A continuous stay in one hospital provider, from admission to discharge; may contain several consultant episodes.
_Source_: NHS Data Dictionary (checked YYYY-MM-DD)
_Avoid_: Admission, stay, hospitalisation

**Consultant episode**:
The time a patient spends under the care of one consultant within a spell.
_Source_: NHS Data Dictionary (checked YYYY-MM-DD)
_Avoid_: Episode (unqualified), admission

**Costing window**:
The period over which resource use is counted for each participant: three months before to eighteen months after randomisation.
_Source_: project definition
_Avoid_: Follow-up, observation period
```

`_Source_` is optional for terms the project defines itself, but always present for terms taken from an external standard.

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others under `_Avoid_`.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Only include terms specific to this project's context.** General programming or statistical concepts (timeouts, error types, standard errors, utility patterns) don't belong even if the project uses them extensively. Before adding a term, ask: is this a concept unique to this context, or a general concept? Only the former belongs. A general term earns a place only when this project uses it in a specific, restricted sense.
- **No implementation.** Variable names, derivation rules, code lists and file paths belong in the codebook or data dictionary.
- **Group terms under subheadings** when natural clusters emerge (for example Population, Resource use, Outcomes, Linkage). If all terms belong to a single cohesive area, a flat list is fine.

## Single vs multi-context repos

**Single context (most repos):** One `GLOSSARY.md` at the repo root.

**Multiple contexts:** A `GLOSSARY-MAP.md` at the repo root lists the contexts, where they live, and how they relate to each other:

```md
# Glossary Map

## Contexts

- [Clinical analysis](./analysis/clinical/GLOSSARY.md): primary and secondary effectiveness outcomes
- [Economic evaluation](./analysis/economic/GLOSSARY.md): resource use, costs, utilities and QALYs
- [Linked data](./data/linked/GLOSSARY.md): routine records linked to trial participants

## Relationships

- **Linked data → Economic evaluation**: hospital provider spells are costed as resource use
- **Clinical analysis ↔ Economic evaluation**: share the definitions of the randomised population and of follow-up time
```

The skill infers which structure applies:

- If `GLOSSARY-MAP.md` exists, read it to find contexts
- If only a root `GLOSSARY.md` exists, single context
- If neither exists, create a root `GLOSSARY.md` lazily when the first term is resolved

When multiple contexts exist, infer which one the current topic relates to. If unclear, ask.

---
Adapted from `skills/engineering/domain-modeling/GLOSSARY-FORMAT.md` in mattpocock/skills (MIT), commit 59db609. Examples replaced with analysis-project ones and the `_Source_` line and no-implementation rule added, 28 October 2026. The spell and episode wording paraphrases the NHS Data Dictionary concepts and is illustrative; check the current definition before relying on it.
