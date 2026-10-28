---
name: to-spec
description: Turn the current conversation into a working spec for an analysis (statistical, economic or prediction) or for software (an R package, Shiny app or tool) - no interview, just synthesis of what has been discussed. Use only when the user types /to-spec or asks to turn the conversation into a spec. Not a formal SAP or HEAP; interviewing first is grill-me.
license: MIT (adapted from mattpocock/skills; see LICENSE)
---

# To Spec

Take the current conversation context and repo understanding (if any) and produce a spec. Do NOT interview the user; just synthesise what you already know. Where something the spec needs was never settled, write it under **Open questions** rather than deciding it yourself.

## Choose the template

- **Analysis spec** ([references/analysis-spec-template.md](references/analysis-spec-template.md)): the work produces estimates, models, tables or figures to inform a decision or a paper. This is the default for this user.
- **Software spec** ([references/software-spec-template.md](references/software-spec-template.md)): the work produces reusable code with users, such as an R package, a Shiny app or a pipeline tool.

If the work is both (for example a Shiny wrapper around a cost-effectiveness model), write the analysis spec and add the software spec's Implementation and Testing Decisions sections. Say which template you used.

This is a working spec for building the thing. It is not a formal statistical analysis plan or health economics analysis plan. If a SAP or HEAP exists, the spec must agree with it and list any departure under Decisions; if the user needs the formal plan itself, say so and point to the content guidance (SAP: Gamble et al., JAMA 2017; HEAP: Thorn et al., Value in Health 2021).

## Process

1. If there is a repo, explore it to understand its current state, if you haven't already. Read `CLAUDE.md`, `GLOSSARY.md` and the ADRs, and any SAP or HEAP. Use the glossary's vocabulary throughout and respect the ADRs in the area you're touching.

2. Agree the checks. For software, sketch the seams at which you will test: prefer existing seams, use the highest one possible, and the fewer seams the better (ideally one). For an analysis, sketch the checks that would show the analysis is right: reconciliation against known totals or counts, row counts across each linkage and derivation step, recovery of known parameters from simulated data, agreement with a published or independent result. Check with the user that these match their expectations; this is the one question this skill asks.

3. Write the spec using the chosen template, then deliver it.

## Where the spec goes

- If an issue tracker has been configured for this repo (for example by `setup-matt-pocock-skills`), publish it there with the `ready-for-agent` label, after the user confirms.
- Otherwise, in a repo, write it to `docs/specs/<short-kebab-name>.md` (create the folder if needed) and say where it is.
- Otherwise, in a chat with no repo, deliver it as a document the user can keep and edit.
- Never publish anywhere outside the conversation or repo without the user's confirmation. Don't create tasks or reminders from it unless asked.

## Rules for both templates

- Do not include file paths or code snippets: they go stale. Exception: a snippet that encodes a decision more precisely than prose can (a model formula, a schema, a transition matrix structure) may be inlined within that decision, trimmed to the decision-rich part, with a note saying where it came from.
- Use UK English.
- Separate what was decided from what was assumed. Anything the conversation assumed without the user stating it goes under Assumptions, not Decisions.

## Provenance

Adapted from `skills/engineering/to-spec/SKILL.md` in mattpocock/skills (MIT), commit 59db609, 27 October 2026. The software template and the seams step are Matt Pocock's. Added on 28 October 2026: the analysis template, analysis checks, open-questions and assumptions rules, delivery without a configured tracker, and the SAP/HEAP boundary. Citations checked 28 October 2026: Gamble C et al. Guidelines for the content of statistical analysis plans in clinical trials. JAMA 2017; Thorn JC et al. Content of health economics analysis plans (HEAPs) for trial-based economic evaluations: expert Delphi consensus survey. Value Health 2021;24(4).
