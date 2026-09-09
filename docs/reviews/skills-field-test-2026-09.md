# Skills field test and remediation (September 2026)

A twelve-lens field test of the HTA and biostatistics skills against real analysis code, the
edits it produced, and the backlog it left. Performed 2026-09-09.

## What was tested, and how

The `hta/` and `biostatistics/` skills are written for exactly one kind of work and had never met
it. This test pointed twelve of them at a large private health-economics analysis repository — a
within-trial cost-utility analysis with a Bayesian joint cost/QALY model over multiple imputation,
a costing rewrite, and a convergence fix — on a branch of roughly 27,500 changed lines.

Each lens loaded one skill from disk (the collection is not installed as a plugin in that
environment), reviewed the branch through it, and reported two things: findings about the code, and
an assessment of the skill it had just used. Every material finding was then checked by two
adversarial verifiers, one reading the code and one searching the project's own decision record.
The target repository is unusually well governed — a long append-only decision register, three
prior independent audits and an adversarial review — which made it a hard test for precision.

Results: 31 findings raised, 20 verified, **10 survived** (8 confirmed, 2 plausible), 10 refuted.
Half the refutations were on one ground the collection had no rule for: *the project had already
identified and ruled on it*.

## What the test said about the skills

**The new skill performed best.** `hta/trial-based-cea-hta` went 2 for 2 on first contact with real
code. One line of `references/structural-values.md` — put treatment in the boundary component's
formula, not only the continuous part — produced a finding that four prior reviews of that codebase
had not written down.

**A rule that suppresses a false finding is worth as much as one that generates a true finding.**
Four earned their keep that way, and the pattern is worth copying: `brms-modelling`'s explicit
carve-out that a high `adapt_delta` is *not* by itself a flag; `bayesian-cea-r-hta`'s corrected CEAF
definition; `cheers-2022-reporting`'s instruction to check tables as well as text. On a mature
codebase, precision is the binding constraint, not recall.

**The collection was written for authoring and was being used for review.** Nine of twelve lenses
reported having to construct a review procedure themselves, and two skills mandated output formats
(inline code comments, a script written to disk) that are impossible on a read-only review.

**Routing is the weakest link, and this test could not measure it directly.** Lenses were assigned by
an orchestrator, not chosen by a router, so the test measured how good a skill is once pointed at
code — not how well its description points. Two observations survive that caveat: a skill was pulled
in by the token `extrapolation` in a filename, which is not survival extrapolation; and
`bayesian-cea-r-hta` produced two surviving findings on a branch whose changed lines contain none of
its trigger words, because its description had no trigger for *the inputs to an existing analysis
changed, so re-check the decision quantities*.

## What was changed

Twenty-six prioritised edits, applied in two rounds: one agent per skill, each followed by an
independent checker reading the diff. The check was worth more than the edits.

**Round one applied 60 edits and every checker returned `needs_fixes`** — 64 problems, 11 of them
high severity. Round two fixed 76 problems and rejected 16 with evidence. Four load-bearing claims
were verified against installed packages rather than accepted from either side:

| Claim | Verdict |
|---|---|
| A multivariate brms fit drops an NA row from one submodel, leaving the two fitted to different samples | **False.** The row goes from both, with a warning. The real hazard is a silent complete-case joint model; `y \| mi()` on the response plus `mi(y)` on the right-hand side is what retains the rows |
| `fit$rhats` carries per-imputation diagnostics on a `brm_multiple` fit | **False.** No such element exists in brms 2.23.0 — a fabricated API citation inside an edit meant to fix API citations |
| A testthat suite without a `DESCRIPTION` behaves like a package suite | **False.** It runs edition 2, where `expect_snapshot()` errors |
| A Gamma GLM with a log link is non-collapsible, and fitting separately by arm restores robustness | **False both ways.** The mean *ratio* is collapsible; and by-arm fitting does not rescue a log link, because the guarantee comes from the canonical link's score equation (verified: canonical reproduces the arm mean to 1e-8, log link does not) |

The substantive additions are recorded in the git history. The largest are: a third route for
carrying the cost/effect correlation when families differ; `re_formula` as the estimand under a
group-level term; the multiple-imputation plus standardisation recipe; masses-versus-densities as a
fourth way an `elpd` comparison fails; mutation testing and the validator corollary; a
reproducibility-infrastructure subsection; and a price-year subsection with a cost-side checklist.

### The cross-cutting rule, and what was wrong with it

The highest-leverage edit was a two-paragraph rule added to every review-capable skill — check the
project's record before reporting, and size a finding before grading it. It was written centrally
and inserted verbatim, and four checkers faulted it:

- it offered *a defect in a pre-specified sensitivity analysis* as low-consequence, when anything
  pre-specified and reported is a result somebody acts on — the rule as written licensed downgrading
  exactly the findings that matter;
- it assumed a project record always exists;
- it had no floor, so it fired on typos;
- it carried health-economics vocabulary into a testthat skill, where there is no analysis plan and
  no sensitivity analysis;
- and it lacked the guard the code-review copy already had: **a wrong number stays a finding however
  well documented** — a record that acknowledges a defect documents it, it does not fix it.

All eight copies were rewritten, domain-adapted where the nouns did not fit, with one
`cheers-2022-reporting`-specific limit: a repository-only record informs the finding but never
changes an item's status, because CHEERS asks what a reader of the published article can reach.

**The lesson is about method, not wording.** Mandating one text across domains was the error. One
rule needs consistent substance and local vocabulary; requiring both to be identical guarantees the
second is wrong somewhere.

## Outstanding backlog

Twenty-six low-severity items survived the second round, plus one systemic issue found while
documenting them. None affects correctness; all were judged not worth a third editing round.

**Systemic — descriptions are 2-2.5x over the guideline.** `CLAUDE.md` sets ~100 tokens for the YAML
`description`; **all 22 `hta/` and `biostatistics/` skills measure 190-260** (chars/4). This
predates this work and was not caused by it. `skill-validator` only enforces a 1024-character limit,
so CI does not catch it. Fixing it means rewriting 22 descriptions, and descriptions drive routing,
so it is a substantive change and should be its own piece of work — with the routing gaps above
folded in rather than treated separately.

**By skill.** Each is a single reviewer's flag, not adjudicated:

- **`trial-based-cea-hta`** (4) — the MCF missing-data paragraph attributes row loss to the
  right-hand-side term rather than to the NA response; a quantitative aside reads as a bound when it
  is one realisation; the corrected `bcea()` `ref` semantics rest on the sibling skill's
  documentation because BCEA is not installed locally.
- **`brms-modelling`** (3) — the default-prior quotations hard-code the scale as 2.5, but brms uses
  `max(2.5, mad(y))`; the diagnostics table lost a pointer when the non-centring text was rewritten;
  `coding-conventions.md` says to check Rhat per imputation without giving the route.
- **`nice-economic-evaluation`** (3) — item 6's *Cancels* case conditions on equal quantity but not
  equal timing; its cost-comparison carve-out needs narrowing; the costing-audit scoping paragraph
  excludes clauses it should keep.
- **`ispor-smdm-good-practices`** (3) — the vendored-documents example is ill-chosen for this skill;
  the reproducibility subsection uses code-project vocabulary in a modelling skill.
- **`missing-data-mice`** (2) — a "silently reinstates" claim overstates what the failure looks like.
  (A doubled apostrophe that rendered literally was fixed rather than logged.)
- **`causal-inference-gmethods`** (2) — the `marginaleffects::avg_comparisons()` description
  overstates what the call returns; a reciprocal note belongs in a sibling this pass did not own.
- **`testing-r-packages`** (2) — the edition opt-in route and the `NOT_CRAN` claim are each slightly
  stronger than the source supports.
- **`decision-modelling-and-survival`** (2) — the destination file's scope sentence was not updated
  to match the new pointers; a parenthetical about heemod's failure mode is half right.
- **`cheers-2022-reporting`** (2), **`critical-code-reviewer`** (2), **`bayesian-cea-r-hta`** (1) —
  file-extension lists that disagree between two files, a `gh` flag that could not be verified
  because the extension is not installed, and description length.

## Limits of this evidence

- **One branch, one domain, one house style.** The target is unusually well governed, which is
  exactly where "already ruled on" dominates the refutations. On a repository with no decision
  record the same skills would likely show higher precision and the prior-art rule would be worth
  less. Do not over-fit the collection to one project's governance culture.
- **No skill was tested on the task it was designed for.** All twelve were used to review. The
  authoring content — most of the content — remains unexercised.
- **Verification pressure was one-sided.** Surviving findings were checked twice; findings the
  reviewers killed before reporting were not. The false-negative rate is unmeasured, so a rule that
  quietly suppressed a *true* finding would be invisible here.
- **N = 1 per skill.** Every per-skill judgement rests on one reviewer's single pass.

The findings about the target repository itself are not recorded here: that repository is private
and its analysis is unpublished.
