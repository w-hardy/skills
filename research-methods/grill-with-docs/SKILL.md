---
name: grill-with-docs
description: A relentless interview to sharpen a plan or analysis approach that also builds the project's glossary and decision records as decisions crystallise. Use only when the user types /grill-with-docs or asks by name to run it. A grilling session without files is grill-me.
license: MIT (adapted from mattpocock/skills; see LICENSE)
---

Load the `grilling` and `domain-modeling` skills and follow both.

Before the first round, read what already constrains the plan, where it exists: `GLOSSARY.md` or `GLOSSARY-MAP.md`, the decision records, `CLAUDE.md`, and any analysis plan (SAP or HEAP). Challenge the plan against them from the first round.

Outside a repo, keep the glossary and decision records in the conversation and offer them as a document when the session ends.

## Provenance

Adapted from `skills/engineering/grill-with-docs/SKILL.md` in mattpocock/skills (MIT), commit 59db609, 27 October 2026. Added: the pre-read of existing constraints and the no-repo fallback; the description restricts it to explicit use because claude.ai does not keep `disable-model-invocation`.
