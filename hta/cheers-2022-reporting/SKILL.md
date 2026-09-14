---
name: cheers-2022-reporting
description: Apply the CHEERS 2022 statement (Consolidated Health Economic Evaluation Reporting Standards, 28-item checklist) so health economic evaluations are completely and transparently reported. Reporting quality only — for methods quality use ispor-smdm-good-practices; for NICE compliance use nice-economic-evaluation. Use when auditing a draft manuscript against CHEERS, completing a checklist for journal submission, drafting or redrafting sections of an economic evaluation paper, or assessing reporting completeness of published evaluations in a systematic review. Trigger on "CHEERS", "reporting checklist", "reporting standards", "reporting quality", or any request to review, complete, or improve the write-up of a cost-effectiveness, cost-utility, cost-benefit, cost-minimisation, cost analysis, or distributional cost-effectiveness study, even when CHEERS is not named.
---

# CHEERS 2022 Reporting

Ensure health economic evaluations are reported completely, transparently, and in line with the CHEERS 2022 statement (Husereau et al. 2022; 28-item checklist plus Explanation and Elaboration report). CHEERS 2022 replaces CHEERS 2013, which should no longer be used.

Read `references/cheers-2022-checklist.md` before doing any of the work below — it contains all 28 items with interpretive notes and common failure modes, and it is the single source of truth for item wording. Do not work from memory of the checklist.

## What CHEERS is and is not

CHEERS assesses **quality of reporting, not quality of conduct**. A methodologically weak study can be perfectly reported; a strong study can be badly reported. Keep the two apart in every output:

- A reporting audit never comments on whether the time horizon was *right*, only whether it was *stated and justified*. If methodological problems are noticed in passing, flag them in a clearly separated note (and point to `ispor-smdm-good-practices` for model conduct/validation or `nice-economic-evaluation` for reference-case compliance) rather than folding them into the checklist assessment.
- **Never produce a CHEERS score.** No counts of items met, no percentages, no ratings derived from the checklist. There is no validated scoring system and the Task Force strongly discourages scoring because it misleads. This holds even if the user asks for a score: explain why, and offer the qualitative item-level assessment instead.

Scope: any economic evaluation — cost analysis, cost-effectiveness/cost-utility, cost-minimisation, cost-benefit (reserve "CBA" for studies monetising health outcomes), extended and distributional CEA — whether trial-based, model-based, or using routine data, in any sector. Out of scope: budget impact analysis and constrained optimisation (other ISPOR guidance covers those; say so and stop rather than force-fitting CHEERS).

## Core recording conventions (all modes)

- Locate items by **section heading + paragraph number**, never page or line numbers — except for a manuscript still held as source (`.qmd`, `.Rmd`) with no typeset pages, where the actionable location is file path plus line number. See the location rules in the reference file.
- **NA** = the item cannot apply to this study type (see the applicability table in the reference file — e.g. items 11–13 for cost analyses; item 16 for non-modelling studies). **NR** = the item applies but the information is absent. Never write "Not conducted".
- **Inconsistent** = the item is reported, but what it reports contradicts the analysis actually run (e.g. Methods describing five reviewed price overrides where seven are applied). This is a reporting defect, not a methods criticism — the report misdescribes the study — so it belongs in the table, with both values and where each was found. Never let it pass as "Reported": a bare tick is what carries this class of error through successive audits.
- An explicit statement of absence *is* adequate reporting: "no HEAP was developed" satisfies item 4; "distributional effects were not considered" satisfies item 19; "no patient or public involvement" satisfies item 21. Silence on these does not — record NR.
- Supplementary material counts. Check appendices, protocols, and cited HEAPs before recording NR, and say what was checked.

## Mode 1 — Audit a draft or published manuscript

Use when given a manuscript (or link/PDF) and asked to check, review, or complete a CHEERS checklist for it.

1. Read the whole manuscript including supplements. Identify the study type first (analysis form; trial-based/model-based/hybrid) — this determines NA items before anything else.
2. Work through all 28 items in order. For each, record: **status** (Reported / Partially reported / Inconsistent / NR / NA), **location** (section + paragraph), **evidence** (a short paraphrase of what the manuscript says — do not quote at length), and for anything short of fully reported, **what specifically is missing and how to fix it**.
3. "Partially reported" is the most useful category in practice — e.g. discount rate stated but not justified (item 10); EQ-5D named but version and tariff country absent (item 13); ICER given without underlying mean costs and outcomes (item 23). Say precisely which element is missing.
4. Finish with a short prioritised gap list: the items whose absence would most obstruct a reader, reviewer, or replicator (typically 4, 15, 16's availability statement, 21/25, and the item 23 conventions), each with a one-line suggested fix or a drafted sentence the authors could adapt.

Two rules decide how firmly each finding is stated and how the step 4 gap list is ordered. Read them against this skill's inputs: the *record* here is the manuscript's own supplement, the protocol, the HEAP (item 4), the trial or study registration, and — for a manuscript still held as source — the repository's decision log and issue tracker; the *quantity moved* is what the omission costs a reader trying to interpret, appraise, or replicate the result. Where the article and its supplement are the whole record, say so once at the head of the audit rather than repeating it item by item. Neither rule yields a score or licenses dropping a row: every one of the 28 items keeps its status, the ordering applies to the gap list only, and no severity grade enters the table.

**Check the record before reporting.** Where the work has one — a decision log, a plan, an issue tracker, a statistical analysis plan, prior review artefacts — search it for the finding before you write it up, and say what you searched. A deviation that is documented, ruled on and justified is a conforming outcome, not a defect, and reporting it as one costs the reader more than it saves. Where there is no such record, say so: "not addressed anywhere I could find" is itself part of the finding. This applies to substantive findings, not to every observation — do not spend a search on a typo. This retires a deviation from a plan, a convention or a prior recommendation; a wrong number, an invalid inference, or a defect in something reported stays a finding however well documented — cite the ruling and report it anyway, because a record that acknowledges a defect documents it, it does not fix it. One CHEERS-specific limit on this: the record informs the finding, it never changes the item's status. CHEERS asks what a reader of the published article and its supplementary material can reach, so a decision minuted only in an issue thread or a repository log leaves the item NR — note that the choice was deliberate and where it is recorded, and keep the status.

**Size the finding before you grade it.** Say what the finding moves, and by how much, before assigning severity: the estimate, the decision, the reported number, the failure rate, the runtime. A defect in a path nothing consumes — dead code, an unreported exploratory branch, a value computed and discarded — is not the same as one in a result somebody acts on, and grading them alike makes the whole list harder to act on. Note the trap in the other direction: anything pre-specified and reported *is* a result somebody acts on, sensitivity and scenario analyses included, so "it's only a sensitivity analysis" is not a reason to downgrade.

Present the full 28-row table plus the gap list. Do not editorialise on study quality within the table.

## Mode 2 — Draft or redraft for compliance

Use when writing or restructuring sections of an economic evaluation manuscript, protocol, or HEAP with publication in mind.

- Map items to manuscript sections before drafting: Title (1); Abstract (2); Introduction (3); Methods (4–21); Results (22–25); Discussion (26); statements section (27–28). Note that item 22 (parameter table) belongs in Results even though it feels methodological.
- For an abstract, follow the E&E prescription: structured, ~300 words unless the journal says otherwise, covering objective, population, setting and country, comparators, perspective, time horizon, currency and price year, discount rate, mean costs and outcomes with the summary measure for base case and key sensitivity analyses, and conclusions with practical implications. Everything in the abstract must appear in the body.
- When drafting Methods, write the compliance-critical sentences explicitly rather than leaving them implied: the HEAP statement (item 4), perspective defined by cost components included (item 8), rate + justification for discounting (item 10), instrument/version/tariff for utilities (item 13), price year + currency + adjustment index (item 15), model availability statement (item 16), the homogeneity or heterogeneity approach (item 18), a distributional-effects statement even if negative (item 19), and a PPIE statement even if negative (item 21).
- In Results, enforce the item 23 conventions: means per comparator (discounted and undiscounted) before summary measures; no negative ICERs — describe dominance; thresholds stated wherever net benefit is reported.
- After drafting, run a quick self-audit (Mode 1 in miniature) on what was produced and state which items remain for the authors — 27 and 28 always do, since they need author-specific facts. Do not invent funding, COI, PPIE activity, or a HEAP that the user has not described; ask or leave clearly marked placeholders.

## Mode 3 — Reporting assessment in a systematic review

Use when assessing reporting completeness of included economic evaluations in a review (typically alongside a PRISMA workflow and a separate methods-quality tool).

- Output a study × item matrix: 28 columns (or rows), one line per study, cells recording Reported / Partially / Inconsistent / NR / NA — optionally with a terse location or note. Pair the matrix with a narrative synthesis of *patterns*: which items are systematically under-reported across the evidence base, and any notable differences by study type or era (pre/post-2022 studies were written against different guidance; note this rather than penalising, and consider stating which checklist version applies).
- No summary scores, no "study X reported 24/28 items", no ranking of studies by reporting. If the review protocol demands a score, flag the Task Force's position and propose the qualitative per-item alternative.
- Keep the reporting assessment table separate from any methods-quality assessment (e.g. the Philips or ISPOR-SMDM-based checklists) — different constructs, different tables, and say so in the methods text.
- Offer a drafted methods paragraph for the review manuscript describing how CHEERS 2022 was applied (qualitative completeness by item, two reviewers if applicable, no scoring).

## Output formats

Choose by destination, and ask if unclear:

- **In-conversation discussion or quick check** → markdown table in the reply.
- **Journal submission** (most journals require an uploaded completed checklist) → a document matching the official checklist layout: item, guidance, "Reported in section". Use the docx skill for Word output or produce Quarto-ready markdown on request.
- **Systematic review matrix across multiple studies** → xlsx (via the xlsx skill) or CSV, one row per study; long/tidy format if the user will analyse it in R.
- Default to UK English in drafted prose unless the target journal is US-based.

## Related guidance to signpost (do not silently substitute)

- **CHEERS-AI (2024)**: if the intervention has an AI/ML component, the 38-item CHEERS-AI extension applies (28 core + 10 AI items, with AI elaborations on 8 core items). Flag it and recommend the user obtain it; do not improvise its items.
- Primary-effectiveness reporting inside item 12 → CONSORT / STROBE / PRISMA as appropriate. Intervention description in item 7 → TIDieR / CReDECI 2. PPIE detail in items 21/25 → GRIPP2. Mapping in item 13 → MAPS.
- Methods quality and model validation → `ispor-smdm-good-practices`. Jurisdictional requirements (NICE reference case, severity modifier, etc.) → `nice-economic-evaluation`. These are complements: a full manuscript review often uses CHEERS for reporting plus one of these for substance — keep the outputs distinct.
