# Reviewing an existing missing-data workflow

Steps 1–4 of `SKILL.md` are the standard you hold the work to; this file is the part that is
specific to reviewing. Read it before writing anything up. The one rule that fires earlier — review
the *specification* when the data are out of reach — is in `SKILL.md` under "Reviewing an existing
missing-data workflow".

## The checklist

Work down this list, roughly in order of how often each is wrong:

- **Imputation model ⊇ analysis model** — is the outcome in it? Every interaction, transformation
  and derived variable the analysis uses, in some form? A *richer* imputation model is not
  automatically a defect — see `multilevel-imputation.md`, "Fixed cluster dummies in the imputation
  model", for the pairing that is most often miscalled.
- **Pooling** — does each analysis run once per imputation and end at `pool()`? A
  `complete(imp, 1)`, a row-bind or a cell-wise average between imputation and results is the
  defect to hunt for.
- **Derived variables** — imputed passively, or computed afterwards from separately imputed
  components?
- **`m`, `maxit`, `seed`** — all three set explicitly, and `m` justified against the percentage of
  incomplete cases rather than left at 5?
- **Diagnostics** — evidence that someone read `plot(imp)` and `loggedEvents`, not just that the
  code ran.
- **Assumption** — is MAR stated, and does the imputation model hold the variables that would make
  it plausible?
- **Upstream fill-ins** — Step 1's point: single imputations made during derivation never reach
  `md.pattern()` and are often the larger half of the story.
- **A Bayesian fitter downstream** — `brm_multiple()`, or `mice` output handed to Stan, adds three
  failure modes that sit on the seam itself: see `bayesian-alternatives.md`, "Reviewing a
  `brm_multiple()` fit".

## Before you report

**Check the record before reporting.** Where the work has one — a decision log, a plan, an issue
tracker, a statistical analysis plan, prior review artefacts — search it for the finding before you
write it up, and say what you searched. A deviation that is documented, ruled on and justified is a
conforming outcome, not a defect, and reporting it as one costs the reader more than it saves.
Where there is no such record, say so: "not addressed anywhere I could find" is itself part of the
finding. This applies to substantive findings, not to every observation — do not spend a search on
a typo. This retires a deviation from a plan, a convention or a prior recommendation; a wrong
number, an invalid inference, or a defect in something reported stays a finding however well
documented — cite the ruling and report it anyway, because a record that acknowledges a defect
documents it, it does not fix it.

**Size the finding before you grade it.** Say what the finding moves, and by how much, before
assigning severity: the estimate, the decision, the reported number, the failure rate, the runtime.
A defect in a path nothing consumes — dead code, an unreported exploratory branch, a value computed
and discarded — is not the same as one in a result somebody acts on, and grading them alike makes
the whole list harder to act on. Note the trap in the other direction: anything pre-specified and
reported *is* a result somebody acts on, sensitivity and scenario analyses included, so "it's only
a sensitivity analysis" is not a reason to downgrade.

The deliverable is findings, not a script — `SKILL.md`'s "Deliverable" section says what that means
in practice.
