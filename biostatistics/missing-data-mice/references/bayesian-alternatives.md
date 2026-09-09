# Full Bayesian modelling as an alternative to multiple imputation

> Context: van Buuren (FIMD) presents MI as "Bayesianly proper" — it is a posterior-predictive
> procedure — but the book's workflow is two-stage throughout. The one-stage alternative, and the
> argument for choosing between them, is set out in Baio, *Bayesian Models in Health Technology
> Assessment* (CRC Press, published 7 August 2026), Ch. 10 §10.3.1-10.3.2 — verified against the
> online edition <https://gianluca.statistica.it/books/online/bmhta/>, 2026-09-09. Companion code:
> <https://github.com/giabaio/bmhta-examples> commit `d2a6298`.

## The argument

Multiple imputation and a fully Bayesian analysis are answering the same question with the same
logic. MI draws plausible values from a predictive distribution, analyses each completed dataset,
and pools — which is Monte Carlo integration over the posterior of the missing data. The difference
is that MI does it in **two stages**, with a seam between them.

The seam has a name: **uncongeniality** (Meng, 1994). The imputation model and the analysis model
are different objects, fitted separately, and they can imply different joint distributions for the
data. The source's framing is that the seam is an artefact of when MI was invented: Rubin's design
was to "think like a Bayesian and do as a frequentist", settling for a handful of completed datasets
because MCMC did not yet exist, and it observes that there is no longer any need to keep that
compromise (§10.3.1). A single unified model has no two stages, so congeniality is not something it
can fail. When the two diverge, the pooled result is not the posterior the analysis model would have
produced — Rubin's rules assume a compatibility that has not been checked. In practice this bites
when the analysis model is more structured than the imputation model: interactions, non-linear
terms, multilevel structure, a hurdle or mixture component, or a bounded outcome. The standard
advice ("the imputation model must be at least as rich as the analysis model" — Step 2's rule) is
exactly an instruction to avoid uncongeniality by hand, and it gets harder to follow as the analysis
model gets more elaborate.

The **direction** of the mismatch matters, not the presence of structure on one side. An imputation
model that is *richer* than the analysis model — fixed group dummies against an analysis with a
shrunk random intercept over the same groups, say — satisfies the containment rule: it omits no
term the analysis needs, and Rubin's variance estimator then tends to come out conservative rather
than anticonservative. It is still uncongenial in Meng's sense; the error is just on the safe side.
That carve-out has conditions, and `multilevel-imputation.md` ("Fixed cluster dummies in the
imputation model") sets them out — read it before deciding whether such a pairing is a finding.
What breaks containment outright is structure the imputation model cannot express: an interaction
it omits, a point mass at zero it smooths over, a bound its draws can cross.

In a **fully Bayesian model** there is no seam. An unobserved value is a parameter with no likelihood
contribution; it is sampled alongside every other parameter in the same MCMC run, conditioned on
everything the model says is relevant. Congeniality is automatic because there is only one model.
Under MAR, conditioning on the observed data is precisely what the sampler already does, so no extra
machinery is needed to make the missingness ignorable.

What you get out is also different in kind: a joint posterior over all quantities, rather than a set
of pooled point estimates and standard errors. Anything that is a function of several parameters —
a contrast, a ratio, a predicted probability, a cost-effectiveness quantity — can be computed on the
draws with its uncertainty intact, without a delta-method approximation or a second pooling step.

## The routing rule

| Situation | Route |
| --- | --- |
| Many incomplete variables, especially **covariates**, arbitrary missingness pattern | `mice`. Chained equations exist for this; a joint model per incomplete variable is unwieldy |
| The analysis model is **not** Bayesian | `mice` |
| Missingness confined to the **outcomes** an already-Bayesian model owns | Model it in place |
| The analysis model has structure that is hard to mirror in an imputation model (mixture, hurdle, bounded outcome, strong non-linearity) | Model it in place — this is where uncongeniality bites hardest |
| A pre-specified SAP commits to MI | `mice` — a real constraint in regulatory and HTA work |
| Incomplete **components** feeding a derived outcome (e.g. utilities at each visit that become a QALY) | `mice` upstream, then the Bayesian model downstream |

The last row is the combined route, and it is common. Impute the components, derive the outcome
inside each imputed dataset, fit the model to each, and keep the imputations separate to the end —
Step 4's rule does not relax because the analysis is Bayesian. Never average the imputed datasets
into one and fit once.

## Implementation

`brms-modelling` owns the mechanics; do not reimplement them here. The checks at the end of this
file are the ones specific to the imputation seam, which that skill does not cover.

- `references/special-terms.md` covers `mi()`, brms's in-formula route for modelling missing values
  as parameters, including `mi(x)` on the right-hand side so records with a missing predictor are
  not silently dropped.
- `references/coding-conventions.md` covers the choice between `mi()` and `brm_multiple()` (the
  fit-to-each-imputation route) and the reporting implications of each.

Two checks that apply whichever route you take:

- **Confirm what was actually used.** `brm()` drops incomplete rows with at most a message, exactly
  like `lm()`. Compare `nobs(fit)` against your sample size on every model, every time — a
  complete-case analysis you did not intend is the most common failure here and it is silent.
- **The missingness assumption is unchanged.** A Bayesian model handles MAR natively; it does not
  make MAR true. MNAR needs the same explicit sensitivity analysis either way — see
  `sensitivity-and-nonignorable.md`, including the Bayesian variant that puts a prior on δ.

## Reviewing a `brm_multiple()` fit

Three failure modes sit exactly on the seam between the imputations and the model. Check them
whenever a review meets `brm_multiple()`, or `mice` output handed to any Bayesian fitter.

- **It stacks; it does not pool.** `brm_multiple()` fits the model once per completed dataset and
  concatenates the draws, so the object holds a **mixture posterior** over imputations rather than a
  Rubin-pooled estimate. That is correct and intended — the mixture already carries the
  between-imputation variance — but it means every summary is a mixture summary, and the draws sit
  in *m* contiguous blocks rather than being exchangeable end to end.
- **Judge convergence per imputation, before combining.** The `Rhat` on the combined object
  conflates within-chain non-convergence with genuine between-imputation variability: a pooled
  `Rhat` near 1 can hide one imputation whose chains never mixed, and a large one need not mean
  anything is broken. `?brm_multiple` documents the route: `posterior::as_draws_array(fit)`, then
  `subset_draws()` on the chains belonging to each imputed dataset (`brm_multiple()` concatenates
  the chains in order, so with one chain per fit chain *i* is imputation *i*), then
  `summarise_draws(default_convergence_measures())` on each. Or fit with `combine = FALSE` and check
  the *m* `brmsfit` objects individually. There is no `fit$rhats` element in current brms — the name
  appears in older material and returns `NULL` without complaint, so a review that cites it reports
  a check that never ran. (`brms-modelling`'s `references/coding-conventions.md` states the same
  rule from the brms side.)
- **Pair each block of draws with its own completed dataset.** Post-processing on `newdata` —
  `posterior_epred()`, `posterior_predict()`, a cost or QALY calculation built from a covariate
  frame — is only valid *within* a block: block *i* was fitted to completed dataset *i* and its
  draws are conditional on that dataset's imputed covariates. Predict for each imputation against
  its own frame and stack the results. Running the whole combined draw matrix against one frame
  (usually imputation 1, or a complete-case frame) discards the imputation uncertainty in the
  covariates and silently reinstates the single-imputation error the *m* fits existed to avoid.
