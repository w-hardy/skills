---
name: "grilling"
description: Grill the user relentlessly about a plan, decision, analysis approach or idea, a round of questions at a time, until every branch is settled. Use when the user wants to stress-test their thinking or uses any 'grill' trigger phrase. Entry points are grill-me and grill-with-docs; writing the result up is to-spec.
license: MIT (adapted from mattpocock/skills; see LICENSE)
---

# Grilling

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

## Rounds

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so, in plain text (not a multiple-choice question tool: the bodies and recommendations don't fit one):

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Word each question so "yes" accepts your recommended answer.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

## Facts versus decisions

Finding _facts_ is your job, never the user's. When a frontier question needs a fact (a file in the repo, a package's behaviour, current guidance), look it up yourself, through a sub-agent where one is available; don't ask the user for anything you could find. Don't block on it: a pending lookup is an unsettled prerequisite, so only the questions downstream of it wait; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

## Recommendations must be defensible

Each recommended answer is either a **judgement** (say so in a few words) or rests on a **checkable claim** (guidance, a method's known behaviour, a package's documented default). For a checkable claim, check it before recommending and name the source in a few words; if you cannot check it, mark it _unverified_. Never present remembered guidance as settled. Where an installed methods skill covers the question (for example missing data, survival extrapolation, NICE reference case, prediction model validation), use it as the authority rather than memory.

## Plans for an analysis

When the plan is a statistical, economic or prediction analysis, the tree usually roots at the **question**, and these branches are worth probing before methods. Use them to find branches, not as a script:

- The decision or estimand: population, treatment conditions, outcome variable, handling of intercurrent events, population-level summary. For an economic evaluation add perspective, comparators, time horizon, discounting and price year.
- Data: sources, linkage and its success by arm, unit of analysis, repeated measures and clustering, sample size against the number of parameters.
- Missing data and its plausible mechanism.
- Uncertainty: what is characterised (sampling, structural, methodological) and how.
- Prespecification: what the analysis plan (SAP or HEAP) already commits to, and whether any answer here would be a deviation from it.
- Audience and output: who reads the result and what it must let them decide.

## Ending

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Then give a short **decision log**: decisions settled (and that the user made them), assumptions accepted, facts checked with their sources, and anything deliberately left open. Do not act on it until the user confirms you have reached a shared understanding. On confirmation, offer one next step where it fits: `to-spec` to write it up, or recording terms and decisions with `domain-modeling` in a repo.

## Provenance

Adapted from `skills/productivity/grilling/SKILL.md` in mattpocock/skills (MIT), commit 59db609, 27 October 2026. Rounds, frontier, format and facts/decisions rule are Matt Pocock's; the defensible-recommendation rule, analysis branches and decision log were added on 28 October 2026. The estimand attributes follow ICH E9(R1) (checked 28 October 2026).
