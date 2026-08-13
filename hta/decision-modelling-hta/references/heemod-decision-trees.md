# Decision trees in heemod

> Sources: *R for Health Technology Assessment* (Baio et al.) Ch. 8 (decision trees) —
> forward/fold-back evaluation, branch probabilities summing to 1 at each chance node, the
> "beware of recurrence" / bushy-tree warning (§8.4), when a tree is the wrong structure
> (§8.8), and PSA on tree inputs (§8.6). Accessed 2026-07-03. The book evaluates trees by hand
> in base R; the tree-as-1-cycle-heemod-model pattern here is this skill's deliberate choice
> (see SKILL.md).

heemod has no dedicated "decision tree" object — a decision tree is represented as a Markov model with `cycles = 1` (or one cycle per tree level, for deeper trees), where each strategy is one root-level decision branch. This file shows the pattern and when to extend it.

## Pattern 1: single chance node per branch (the common case)

Worked example — two treatment strategies, each with a single success/failure chance node. This is the most common decision-tree shape in HTA practice (e.g. "does the index test correctly identify the condition", "does the treatment work").

```r
library(heemod)

# Parameters: anything that might later go into PSA/DSA
par_tree <- define_parameters(
  p_success_X = 0.62,
  p_success_Y = 0.81
)

# One transition matrix per strategy. States: Start -> {Success, Failure}.
# Start is a "launch" state visited only at cycle 0 with probability 1 of
# leaving; Success/Failure are absorbing terminal states (self-loop = 1)
# because the tree ends there.
trans_X <- define_transition(
  state_names = c("Start", "Success", "Failure"),
  0, p_success_X,        C,
  0, 1,                  0,
  0, 0,                  1
)

trans_Y <- define_transition(
  state_names = c("Start", "Success", "Failure"),
  0, p_success_Y,        C,
  0, 1,                  0,
  0, 0,                  1
)

# State values: cost and QALY/utility payoff for landing in that pathway.
# Start carries the up-front treatment cost; Success/Failure carry the
# downstream payoff for that outcome.
state_start_X  <- define_state(cost = 1500, utility = 0)
state_success  <- define_state(cost = 4000, utility = 0.82)
state_failure  <- define_state(cost = 9000, utility = 0.55)

state_start_Y  <- define_state(cost = 2600, utility = 0)

strat_X <- define_strategy(
  transition = trans_X,
  Start = state_start_X, Success = state_success, Failure = state_failure
)
strat_Y <- define_strategy(
  transition = trans_Y,
  Start = state_start_Y, Success = state_success, Failure = state_failure
)

res <- run_model(
  X = strat_X, Y = strat_Y,
  parameters = par_tree,
  cycles = 1,
  cost = cost, effect = utility,
  init = c(1, 0, 0)   # everyone starts in "Start"
)

summary(res)
```

Why this reproduces the textbook's "forward" decision-tree calculation: with `cycles = 1` and everyone starting in `Start`, `run_model()` computes the weighted sum of terminal payoffs by their joint probability in a single matrix step — no recursion needed.

> **Verify the counting method here.** Whether the cohort's per-cycle state values are counted at the *start* state or the *destination* state over a single cycle depends on `run_model()`'s `method` argument (`"beginning"`, `"end"`, `"life-table"`). For a decision tree you almost always want the payoff attached to the terminal state to be the thing that's counted, so set `method` explicitly and check the totals against a hand-built payoff table (rows = pathways, columns = joint probability × cost/QALY) before trusting the output. This is the single most error-prone point in representing a tree as a 1-cycle Markov model, and it must be checked against the installed heemod version rather than assumed — heemod's discrete-time cost accounting is built for multi-cycle models, and the single-cycle edge case behaves differently across counting methods.

## Pattern 2: multiple sequential chance nodes (deeper trees)

If a branch has more than one chance node in sequence (e.g. test result, *then* response to treatment), there are two options:

**(a) Collapse to joint terminal probabilities (recommended default).** Multiply out the path probabilities by hand (or in `define_parameters()`) into one transition per *terminal pathway*, and use `cycles = 1` exactly as above but with more terminal states (one per distinct pathway through the tree). This always works regardless of tree depth and keeps the model auditable against a payoff table, which is worth building separately as a sanity check (rows = pathways, columns = joint probability, cost, QALY — should match what `run_model()` reports).

**(b) One cycle per tree level, using tunnel states.** Set `cycles` to the number of sequential chance nodes, and give each intermediate node its own named state that's only ever occupied for one cycle (a "tunnel" state, in heemod's terminology — heemod detects these automatically when a state's outgoing transitions don't include a self-loop). This is more code but lets you inspect the cohort distribution at each tree level, which is useful if W wants to show the proportion of the cohort in each intermediate branch (e.g. for a CONSORT-style diagram check) rather than just the final payoff.

Default to (a) unless there's a specific reason to want the intermediate-cycle detail.

## Sanity checks specific to decision trees in heemod

- Every terminal/absorbing state needs a self-transition of `1` (or `C` with all other entries `0`) — if you forget this, `run_model()` will run but the cohort "leaks" probability mass out of the terminal state into nothing, and results will be too low.
- All branch-defining probabilities in a row must sum to 1 — use `C` for the last one rather than computing `1 - p1 - p2` by hand.
- If chaining a tree into a downstream Markov model (tree terminal node → long-run disease model), the tree's terminal-state proportions become the `init` vector for the Markov model's first cycle. Don't re-run the tree's costs/QALYs a second time inside the Markov stage — the tree's own state values should only cover what happens up to and including reaching that terminal node.
