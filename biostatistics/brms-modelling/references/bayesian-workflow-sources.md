# The Bayesian workflow — sources and the ideas this skill leans on

> Sources: *Bayesian Workflow* — Gelman, Vehtari, Simpson, Margossian, Carpenter, Yao,
> Kennedy, Gabry, Bürkner & Modrák (2020), arXiv:2011.01808
> (<https://arxiv.org/abs/2011.01808>); and the book *Bayesian Workflow* — Gelman, Vehtari,
> McElreath, Simpson, Margossian, Yao, Kennedy, Gabry, Bürkner, Modrák & Leos Barajas
> (Chapman & Hall/CRC, 2026), online companion at
> <https://avehtari.github.io/Bayesian-Workflow/>. *Regression and Other Stories* — Gelman,
> Hill & Vehtari (CUP 2020), online PDF and examples at
> <https://avehtari.github.io/ROS-Examples/>. *Bayesian Data Analysis*, 3rd ed. — Gelman,
> Carlin, Stern, Dunson, Vehtari & Rubin (Chapman & Hall/CRC 2013), free PDF and table of
> contents at <https://sites.stat.columbia.edu/gelman/book/>.
> Verified against these live sources on 3 July 2026: the paper's section/figure structure
> (arXiv:2011.01808v1 table of contents and §§2, 4–8, 12), the book's published chapter list
> (avehtari.github.io/Bayesian-Workflow, "Book contents"), the ROS table of contents
> (avehtari.github.io/ROS-Examples), and the BDA3 table of contents (contents3.pdf). Section
> and chapter numbers below are as printed in those sources on that date.

This file grounds the skill's workflow table in its sources, so the stages read as a coherent
method rather than a checklist. Read it when a model is misbehaving in a way the stage-by-stage
mechanics don't explain, or when writing methods text that needs citations.

## The workflow is iterative model *building*, not model *checking*

*Bayesian Workflow* (Gelman, Vehtari et al. 2020) is the organising frame. The paper's own
definition is that Bayesian workflow includes model building, inference, and model
checking/improvement, *together with* the comparison of many models — not merely to choose or
average between them, but to understand why a model has trouble with certain aspects of the data
(§1.1). Figure 1 of the paper is the canonical overview diagram: it lays out the possible steps
and paths an analysis may follow, with the explicit understanding that any one analysis will
touch only a subset of them. The stages the skill's table draws on map onto the paper as
follows:

- **Before fitting** (§2): choosing an initial model (§2.1), modular construction (§2.2),
  scaling/transforming parameters onto interpretable, roughly unit scales (§2.3), and **prior
  predictive checking** (§2.4).
- **Fitting** (§3): warmup/adaptation (§3.1), how long to run (§3.2 — run at least until
  R-hat < 1.01 for all quantities of interest), and the "fit fast, fail fast" principle (§3.4).
- **Constructed-data checks** (§4): **fake-data simulation** (§4.1) and **simulation-based
  calibration** (§4.2), with §4.3 on using constructed data to probe how a model behaves across
  the parameter space.
- **Computational problems** (§5): the folk theorem of statistical computing — "when you have
  computational problems, often there's a problem with your model" (§5.1); starting simple and
  complex and meeting in the middle (§5.2); and reparameterisation (§5.7), marginalisation
  (§5.8) and adding prior information (§5.9) as the principled fixes for hard geometry, ahead of
  brute force.
- **Evaluating a fitted model** (§6): **posterior predictive checking** (§6.1) and
  cross-validation / influence of individual points via PSIS-LOO (§6.2), plus prior-sensitivity
  analysis (§6.3).
- **Modifying and comparing** (§7–8): the "topology of models" (§7.4) and understanding and
  comparing multiple models fit to the same data (§8), including cross-validation and model
  averaging (§8.2).

Key ideas the skill imports, with their anchors:

- **Start simple, expand deliberately.** The paper stresses that a typical workflow fits a
  *series* of models — some in retrospect poor, some flawed-but-useful, some worth reporting —
  and that the wrong and flawed models are unavoidable steps toward the useful ones (§1.1). Add
  structure one motivated step at a time (§2.2 modular construction; §5.2 meeting in the
  middle). The sequence *is* the analysis narrative; abandoned models are evidence, not
  embarrassments. The book's justification of iterative model building is the paper's §12.2.
- **Computation as diagnostic.** Divergences, low ESS and funnels usually tell you about the
  *model* (weak identification, priors fighting the likelihood, geometry wanting a non-centred
  parameterisation), not just the sampler — this is the folk theorem (§5.1). Reach for
  reparameterisation (§5.7) before pushing `adapt_delta` toward 1.
- **Fake-data simulation and SBC.** Simulating from known parameters and checking recovery is
  the calibration backbone (§4.1). The paper is explicit that a *single* truth-point check can
  flag gross errors but guarantees nothing, because Bayesian inference is calibrated only on
  average over the prior; simulation-based calibration (§4.2) is the systematic form, drawing
  parameters from the prior and checking that rank statistics are uniform. One fake-data
  recovery run is the practical minimum for any novel structure; SBC is worth it for a structure
  you will reuse.
- **Fit many models, present the spread.** The paper motivates comparing inferences across a
  series of related models to understand what each is doing (§1.1, §8.1), and notes that when
  different models yield different conclusions without a clear winner, presenting multiple models
  is how you show uncertainty in model choice (§1.2). Sensitivity analysis over defensible
  specifications is part of the workflow, not an appendix. (This project's cost-family
  candidates and prior-sensitivity grid are exactly this.)

### What the 2026 book adds over the paper

The book keeps the paper's frame but reorganises it into a fuller structure; cite the book
(chapter) when you need more than the paper covers:

- **Prediction, generalization, and causal inference** as a workflow stage in its own right
  (Ch. 7) — the predict-then-average / poststratification move sits here.
- **Visualizing and checking fitted models** (Ch. 8) and **comparing and improving models**
  (Ch. 9) — the "check" and "compare" stages, with a worked LOO model-selection case study
  (§9.4 in the online companion).
- A dedicated **computational workflow** part: fitting (Ch. 11), diagnosing and fixing fitting
  problems (Ch. 12), approximate algorithms (Ch. 13), and a full chapter on **simulation-based
  calibration checking** (Ch. 14). The companion's SBC-in-development case study is Ch. 31.
- Worked brms/Stan case studies that mirror this skill's stages — e.g. posterior predictive
  checking on the "dogs" data (Ch. 21), incremental development and testing (Ch. 22), debugging
  (Ch. 23), and LOO checking/comparison on "roaches" (Ch. 24).

## What Regression and Other Stories contributes

ROS is the regression-craft layer under the workflow. Chapter numbers below are from the
published ROS table of contents (verified 3 July 2026):

- **Scale discipline** (ROS Ch. 10, *Linear regression with multiple predictors*, and Ch. 12,
  *Transformations and regression*): coefficients, priors and interactions are only
  interpretable on a deliberate scale — centre and standardise predictors before reaching for
  any "default" prior. Ch. 12 opens with the book's own framing that "it is not always best to
  fit a regression using data in their raw form", and covers standardising and log/other
  transformations. (The pithier "only fools work on the raw scale" is a lecture-room gloss, not
  a verbatim line in the book, so state the idea rather than quoting it.)
- **Fake-data simulation as a way of life** (ROS Ch. 5, *Simulation* — "you don't understand
  your model until you can simulate from it"): the recover step in this skill's table. Build the
  habit of simulating from the model before trusting fits.
- **Predict-then-average for population effects** (ROS Ch. 9, *Prediction and Bayesian
  inference*, for the predict-under-each-condition machinery; Ch. 17, *Poststratification and
  missing-data imputation*, for averaging over the covariate/population distribution):
  population-average effects come from predicting every unit under each condition and averaging
  — the g-computation / poststratification move. A repository using marginal contrasts from
  `epred` draws (as this one's `cu_incremental_draws()` does) is doing ROS-style
  poststratification over the covariate distribution.
- **Weakly-informative priors as regularisation** (ROS Ch. 9 introduces priors and Bayesian
  inference; the autoscaled weakly-informative *default* prior it explains — normal(0, 2.5) on
  standardised predictors — traces to Gelman, Jakulin, Pittau & Su 2008, *Ann. Appl. Stat.*
  2:1360–83, and is what `rstanarm` implements): the prior is understood jointly with the
  likelihood — weak on the right scale, strong enough to exclude the absurd (see also Gelman,
  Simpson & Betancourt 2017, *Entropy* 19:555).

## What BDA3 contributes

BDA3 is the theory underneath the checks. Chapter/section numbers are from the BDA3 table of
contents (verified 3 July 2026):

- **Posterior predictive checking** (BDA3 Ch. 6, *Model checking*, §6.3 posterior predictive
  checking and §6.4 graphical posterior predictive checks): PPCs compare observed data to
  replicated data under the model via test quantities chosen for their scientific relevance —
  the licence for the skill's insistence on tailored `pp_check` types (zero-shares, group-wise
  overlays) over one default density.
- **Model evaluation, comparison and expansion** (BDA3 Ch. 7, *Evaluating, comparing, and
  expanding models*: §7.1 measures of predictive accuracy, §7.2 information criteria and
  cross-validation, §7.3 comparison on predictive performance, §7.5 continuous model expansion):
  the lineage from within-sample fit through cross-validation to LOO, and model expansion as the
  response to misfit — the "compare" and "expand" stages.
- **Hierarchical models** (BDA3 Ch. 5: §5.2 exchangeability and setting up hierarchical models,
  §5.7 weakly informative priors for hierarchical variance parameters): partial pooling,
  exchangeability, and why few-group hierarchies are weakly identified — the theoretical backing
  for the multilevel file's non-centred parameterisation and regularising SD priors. (BDA3 §2.9
  and §16.3 are the companion sections on weakly informative priors in general and for logistic
  regression specifically.)
- **Missing data as modelling** (BDA3 Ch. 18, *Models for missing data*, in **Part IV:
  Regression Models** — not Part V; §18.2 covers multiple imputation): the joint-modelling view
  behind brms's `mi()` terms; the MI-then-pool alternative lives in the missing-data-mice skill.

## Citation shorthands for methods text

- Workflow/iteration/SBC: Gelman et al. (2020) *Bayesian Workflow*, arXiv:2011.01808 (paper); or
  Gelman, Vehtari, McElreath et al. (2026) *Bayesian Workflow*, Chapman & Hall (book) for the
  expanded treatment.
- Fake-data simulation, scaling, poststratification: Gelman, Hill & Vehtari (2020) *Regression
  and Other Stories* (Ch. 5, Ch. 10/12, Ch. 9/17 respectively).
- PPCs and predictive model evaluation: Gelman et al., *BDA3*, Chs. 6–7.
- Weakly-informative default priors: Gelman, Jakulin, Pittau & Su (2008), *Ann. Appl. Stat.*
  2:1360–83; priors-in-context, Gelman, Simpson & Betancourt (2017), *Entropy* 19:555.
- LOO/PSIS mechanics: Vehtari, Gelman & Gabry (2017), *Stat. Comput.* 27:1413–32; sample-size-
  dependent Pareto-k threshold, Vehtari et al. (2024) via the loo package (see
  `core-workflow.md` §6 for the current rules).
