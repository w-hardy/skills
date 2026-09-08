---
name: scientific-writing
description: "Structure, draft, and critique scientific manuscripts as arguments: thesis-first framing, IMRaD discipline, paragraph craft (claim → evidence → link), converting bullet skeletons to prose, structured abstracts, section budgets, and manuscript-wide cohesion checks (every promise delivered, every float referenced, every number traceable). Use when drafting or restructuring a paper section, turning outline bullets into prose, writing or tightening an abstract or discussion, reviewing a manuscript's argument rather than its code, or when someone says the paper 'reads as a list', 'lacks a thesis', 'overpromises', or asks 'is this ready for co-authors/submission'. Complements reporting-checklists (guideline items) — this skill covers whether the paper argues, not whether it discloses."
---

# Scientific writing: the manuscript as an argument

A paper is a single argument with evidence, not a tour of work performed.
Most manuscript failures are structural, not stylistic: no falsifiable thesis,
sections that don't know their job, promises the Results never redeem, and
bullet skeletons that fossilise into the submitted draft.

## The thesis test (do this before any drafting)

Write **one falsifiable sentence** the whole paper defends, and one sentence
for each Results subsection stating what it contributes to the defence. If a
Results block defends nothing, it belongs in a supplement or another paper.
The thesis must appear: (1) at the end of the Introduction, in plain words;
(2) operationalised in the Methods (as the estimand); (3) answered in the
first paragraph of the Discussion. If the three statements don't match, the
paper argues with itself.

Corollary — **the promise audit**: every "we show/propose/demonstrate X" in
the Abstract/Introduction must map to a specific table, figure, or section.
Grep for "we show", "we demonstrate", "in addition", "furthermore"; anything
without a Results anchor gets delivered or deleted. An unredeemed promise is
the single fastest reviewer trust-killer.

## Section jobs and budgets

For a methods-oriented paper of ~4,000–5,000 words:

| Section | Job | Budget | Failure mode |
| --- | --- | --- | --- |
| Abstract | The paper in miniature, WITH results | 250–300 w | framework described, no numbers |
| Introduction | Gap → why it matters → thesis → map of the paper | ~20% | literature tour that never narrows |
| Methods | Reproducibility + estimand (see reporting-checklists / simulation-study-design) | ~25% | describing code, not design |
| Results | Evidence in thesis order, prose that interprets each float | ~25% | table dump with connective tissue |
| Discussion | Answer, mechanisms, limitations, so-what | ~25% | restating results; boilerplate limitations |

Order of drafting that works: Results skeleton (floats + one claim sentence
each) → Methods → Introduction → Discussion → Abstract **last**.

## Paragraph craft

- **Claim → evidence → link.** First sentence states the point; middle
  sentences carry data/citations; last sentence hands off to the next
  paragraph. A reader skimming only first sentences should get the whole
  argument (the "topic-sentence outline" test — run it explicitly).
- **One paragraph, one point.** If a paragraph needs "additionally" twice,
  split it.
- **Put numbers in prose, not just floats.** Every table/figure gets at least
  one sentence saying what it shows and *why it matters for the thesis* —
  "Table 2 shows the results" is not that sentence.
- Prefer verbs over nominalisations ("we estimated" not "estimation was
  performed"); active voice by default; hedge conclusions once, not per
  sentence.

## Converting a bullet skeleton to prose

Bullets are for planning; they fossilise. Convert deliberately:

1. Group bullets by the claim they support (not by the order written).
2. Promote each group's strongest bullet to a topic sentence.
3. Demote each remaining bullet to evidence or delete it — a bullet that is
   neither claim nor evidence is a note-to-self and does not survive.
4. Write the link sentences between the resulting paragraphs; this is where
   the actual thinking happens, and it cannot be done in bullet form.
5. Kill orphaned placeholders while converting: `[@REF]`, `TODO`, empty
   headings. A placeholder that survives two drafting passes needs a tracker
   entry, not another pass.

## Abstract discipline

Structured (Background / Methods / Results / Conclusions) unless the journal
forbids it. The Results sentences must contain **numbers with uncertainty**
from the paper's own tables. The Conclusions sentence must be entailed by
those numbers — nothing broader than the evidence (a one-DGM simulation
supports "in these simulated conditions...", not "models should now...").

## The cohesion audit (run on the assembled render)

- [ ] Thesis stated in Intro, operationalised in Methods, answered in
      Discussion — three consistent statements.
- [ ] Every promise ("we show…") has a Results anchor; every Results float is
      referenced from prose by cross-reference, with an interpretation
      sentence.
- [ ] Study/section taxonomy consistent everywhere (Intro map = Methods
      subsections = Results order = registered notebooks).
- [ ] Every number in prose is generated (inline code from artifacts), not
      hand-typed — hand-typed numbers go stale silently when pipelines re-run.
- [ ] Claims in Methods match the code that ran (formulas, CIs vs SDs, model
      descriptions); anything the code no longer does is removed.
- [ ] Discussion has: principal findings (with numbers), mechanisms,
      comparison with prior work, ≥3 concrete limitations (not "more research
      is needed"), and implications scoped to the evidence.
- [ ] No section is a stub in a draft circulated beyond the authors; stubs are
      marked with a visible callout, not left looking finished.
