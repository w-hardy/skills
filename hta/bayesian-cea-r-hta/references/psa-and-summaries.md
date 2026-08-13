# PSA draws, the net-benefit framework, and the standard summaries

> Sources: *R for Health Technology Assessment* (Baio et al., online at
> <https://gianluca.statistica.it/books/online/r-hta/>) — Ch. 1 §1.7 (net (monetary/health)
> benefit, `nb_d = k·e_d − c_d`; decision rule = maximise expected NB; Stinnett & Mullahy 1998)
> and §1.7.1 (probabilistic analysis; the book prefers "(parameter) uncertainty analysis" to
> "PSA"), and Ch. 5 §5.3.3–§5.3.4 (within-trial bootstrap, CE plane, CEAC via
> `p_ce = mean(nb > 0)` over a WTP grid) with §5.4 ("the CEAC is an inherently Bayesian
> concept"). *Bayesian Cost-Effectiveness Analysis with BCEA* (Baio, Berardi & Heath 2017).
> Accessed 2026-07-03; anchors are section-level.

## Draws conventions

The unit of currency is a matrix (or long tibble) of simulations: one row per draw, one
cost column and one effect column **per strategy**, all on natural scales (£ and QALYs, not
log-£ or rescaled utilities). Everything downstream is a row-wise transformation followed by an
average — never the other way round.

- **Pairing.** Row *i* must be one coherent state of the world: the same parameter draw through
  the whole model, the same posterior draw for costs and effects, the same imputed dataset. In a
  multiple-imputation pipeline, pair within imputation and stack imputations (each contributes
  its own block of draws); do not average over imputations before forming contrasts.
- **Size.** ≥1,000 draws for stable CEACs; EVPPI regression methods want the full set (5,000+
  is comfortable). CEAC wiggle or EVPI jitter across reruns means too few draws, not a finding.
- **Incrementals.** Δc and Δe are formed per draw against a stated comparator. With more than
  two strategies keep all strategies' draws; pairwise incrementals against a fixed baseline are
  not sufficient for a frontier (see below).

## Why net benefit, not the ICER, is the working scale

ICER = E[Δc]/E[Δe] is a ratio of expectations — fine as a headline, pathological as a
per-draw quantity:

- its distribution has no finite moments when Δe has mass near 0;
- the same numeric value means opposite things in the NE and SW quadrants (an ICER of £10k/QALY
  is good when buying QALYs, bad when selling them);
- averaging per-draw ICERs is meaningless.

The monetary net benefit **INB(λ) = λ·Δe − Δc** is linear in the draws, so per-draw INB is
well-defined, its mean is the decision criterion (choose the strategy with highest expected NB —
R-HTA §1.7), and P(INB > 0) is directly readable. Report the ICER as a summary of the point decision;
compute everything through net benefit. Net *health* benefit (INB/λ) is the same information in
QALY units.

## The cost-effectiveness plane

Scatter the (Δe, Δc) draws with the comparator at the origin; overlay the λ line through the
origin (slope λ). Reading:

- Draws below the λ line are cost-effective at λ — this is exactly P(INB > 0), the CEAC value.
- Quadrant shares tell you *why*: SE (dominant) vs NE (buying QALYs) vs SW (cost-saving at a
  QALY loss — read the ICER inversely there) vs NW (dominated).
- The cloud's *tilt* shows the cost–effect correlation the pairing preserves; a perfectly
  axis-aligned cloud in a trial-based CEA is a hint the draws were recombined marginally.

## CEAC and CEAF

- **CEAC**: for each λ on a grid (e.g. £0–£50k by £100), the share of draws with INB(λ) > 0 —
  i.e. P(strategy is cost-effective at λ). R-HTA computes this directly as
  `p_ce = mean(nb > 0)` over the grid (§5.3.4). It is a statement about *decision uncertainty*,
  not an interval for the ICER, and it need not be monotone.
- **Multi-comparator CEAC**: P(strategy s has the highest NB at λ), computed across all
  strategies simultaneously — the pairwise version overstates each strategy.
- **CEAF (frontier)**: at each λ, mark the strategy with the highest *expected* NB. The frontier
  strategy can differ from the CEAC-maximal strategy (expectation vs probability); when they
  disagree, say so explicitly — the decision follows expected NB, the CEAC describes the
  uncertainty around it.
- A CEAC hovering near 0.5 across the relevant λ range is the classic "decision on a knife-edge"
  picture — that is where VOI analysis (see `value-of-information.md`) earns its keep.

## Multi-comparator discipline

With >2 strategies: (1) drop strictly dominated strategies (higher cost, lower effect than
another); (2) drop extendedly dominated ones (dominated by a mixture — ICERs must increase
moving up the frontier); (3) quote ICERs only between adjacent frontier strategies ("fully
incremental analysis"). Pairwise-vs-placebo ICER tables are not a substitute.

## Reporting set

A complete draws-based results block: expected Δc and Δe with 95% credible intervals; the ICER
(with dominance annotations); expected INB and P(INB>0) at the stated thresholds; CE plane;
CEAC (all strategies); CEAF if >2 strategies. All of it from one draws object, so every number
is mutually consistent.

## In this repository

The within-trial pipeline's `cu_incremental_draws()` → `cu_summary()` objects (`.draw`,
`inc_cost`, `inc_qaly`) are exactly the paired-draws format above — g-computation contrasts per
posterior draw, paired within imputation. `incremental_results_table()` is the reporting set;
the CE plane and CEAC figures in notebooks 01–03 follow these conventions. Anything new built
on those draws should stay row-wise-then-average.
