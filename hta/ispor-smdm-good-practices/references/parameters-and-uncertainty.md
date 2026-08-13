# Parameter estimation and uncertainty (TF-6, Briggs et al.)

Source: *Value in Health* 2012;15:835–842. Recommendations VI-1 to VI-16.
Applies to **all** model types. For the R machinery that computes what this
report says to report — PSA draws, CE plane, CEAC/CEAF, net benefit, EVPI/EVPPI/
EVSI — hand off to `bayesian-cea-r-hta`. TF-6 defines *what* and *why*; that skill
defines *how*.

The value of a model-based analysis is not the point estimate but the
**systematic examination and honest reporting of uncertainty** around it and the
decision it informs. That is the hallmark of good practice (VI-1).

## Contents
- The four-way uncertainty taxonomy (VI-3)
- Decision-maker role and the two purposes of uncertainty analysis (VI-1, VI-2)
- Estimation and uncertainty are one process (VI-4)
- Consistency between DSA and PSA (VI-5)
- Arbitrary ranges are not uncertainty (VI-6)
- Distribution choice (VI-7, VI-9)
- Sparse-information parameters (VI-8)
- Correlation (VI-10)
- Structural uncertainty (VI-11)
- Calibration (VI-14)
- Reporting DSA and PSA (VI-12, VI-13, VI-15, VI-16)

---

## The four-way uncertainty taxonomy (VI-3)

Terminology is genuinely confused across fields, so **define your terms**. TF-6's
preferred taxonomy, with the regression analogy:

| Preferred term | Concept | Regression analogue |
|---|---|---|
| **Stochastic (first-order) uncertainty** | Random variability in outcomes between *identical* patients (a fair coin lands heads or tails) | the error term |
| **Parameter (second-order) uncertainty** | Uncertainty in the *estimate* of a parameter, because it is estimated from finite/imperfect data | standard error of the estimate |
| **Heterogeneity** | Between-patient variability *explained by patient characteristics* (age/sex-specific mortality) | beta coefficients |
| **Structural uncertainty** | The assumptions inherent in the model itself | the form of the regression (linear vs log-linear) |

Key distinctions to get right:
- Stochastic ≠ parameter uncertainty (standard *deviation* of individual outcomes
  vs standard *error* of an estimate). In patient-level simulations (DES,
  microsimulation) you must **eliminate stochastic/Monte Carlo error** before you
  can read parameter uncertainty; in cohort models parameter uncertainty is
  addressed without this concern.
- "Variability" is used ambiguously for both first-order uncertainty and
  between-patient differences — avoid it or define it.
- **Heterogeneity** relevance: it identifies subgroups for separate CEA, which may
  support different decisions per subgroup or a weighted aggregate.
- **Structural** uncertainty: any representation of parameter uncertainty is
  *conditional* on the structural assumptions, so structure is a further,
  higher-order layer.

## Decision-maker role and the two purposes (VI-1, VI-2)

Uncertainty analysis serves two purposes: (a) assess confidence in the chosen
course of action; (b) ascertain the value of collecting more information.

**VI-2** State explicitly, as part of the analytic perspective, what is assumed
about the decision-maker's power to **delay/review** the decision and to
**commission/mandate research**. If the decision is now-or-never with no research
lever, expected values suffice (though PSA may still be needed to generate correct
expected values for non-linear models). A reimbursement body that can delay and
commission research should care about a full uncertainty analysis and the value
of research. Models for general dissemination warrant a full analysis so varied
decision-makers can take what they need.

## Estimation and uncertainty are one process (VI-4)

Populate models per **evidence-based-medicine** principles: incorporate all
relevant evidence rather than cherry-picking one source; use best-practice
methods to avoid bias (e.g., estimating effectiveness from observational
sources); employ formal evidence synthesis (meta-analysis, network meta-analysis
→ `network-meta-analysis-hta`) as appropriate. Standard estimation already yields
a point estimate, a precision measure (SE / 95% CI), and possibly covariance —
these feed **directly** into the uncertainty analysis. The steps to estimate a
parameter and the steps to characterise its uncertainty are one process, not two.

## Consistency between DSA and PSA (VI-5)

Whether using **DSA** (point estimate + defensible range) or **PSA**
(parameterised distribution), the link to the underlying evidence base must be
clear, and the two should be **consistent** — the distributional assumption
behind a 95% CI can ground both the PSA distribution and the DSA range. Under a
formal Bayesian approach, consistency is retained if the DSA interval is the
posterior's 95% highest-density region.

Some analyses don't need formal parameter uncertainty: **threshold / "even-if"
analysis** (the value that would change the decision) can suffice when there is
little decision uncertainty; identifying input-output relationships alone usually
does not, because a low-sensitivity but highly uncertain parameter can matter
more than a high-sensitivity precisely-estimated one.

## Arbitrary ranges are not uncertainty (VI-6)

Completely arbitrary analyses — e.g., varying every input by ±50% — may measure
**sensitivity** but must **not** be presented as **uncertainty**. A range that is
not a reflection of actual uncertainty tells you how reactive the model is, not
how uncertain the answer is. (This is the flip side of the "robust" point in
TF-1: a model *should* react to its inputs; the question is whether the
*conclusion* holds within the *real* uncertainty.)

## Distribution choice (VI-7, VI-9)

**VI-7** Use commonly adopted statistical standards (95% CIs, or distributions
based on agreed methods); justify any departure or any case where no standard
exists. **VI-9** Favour **continuous** distributions that portray uncertainty
realistically over the parameter's theoretical range; give careful consideration
to whether convenient-but-implausible distributions (uniform, **triangular**)
should have any role in PSA. Standard matches: **beta** for binomial/probability
data; **gamma or log-normal** for right-skewed (e.g., costs); **log-normal** for
relative risks / hazard ratios; **logistic** for odds ratios. These serve both to
draw in PSA and to define DSA intervals. Note that reliance on a single study
tends to *underestimate* uncertainty, so some subjective broadening is often
warranted even with a large study.

## Sparse-information parameters (VI-8)

When there is very little information, adopt a **conservative** approach so the
absence of evidence is reflected in a **very broad** range of possible estimates.
**On no account exclude a parameter from uncertainty analysis on the grounds that
"there isn't enough information to estimate uncertainty."** Elicit broad ranges
from experts (formal elicitation methods exist) and combine across experts.

## Correlation (VI-10)

Consider correlation among parameters. **Jointly estimated** parameters (e.g.,
from one regression) carry direct evidence of correlation (the covariance matrix;
multivariate normality on the linear predictor) that **must** be reflected.
**Independently estimated** parameters have no such evidence — but that does *not*
justify assuming independence. Two practical routes: (1) include a correlation
coefficient as a model parameter where an unknown correlation could matter; (2)
**re-parameterise** so the uncertain parameters can reasonably be assumed
independent — e.g., assign distributions to a baseline progression probability
and a relative risk reduction, deriving the on-treatment probability as their
product (switch to odds ratios if relative risks push parameters out of range).

## Structural uncertainty (VI-11)

Where structural uncertainties were identified during conceptualisation/building
(link back to II-4 and `conceptualising-models.md`), **test them in uncertainty
analysis**; look for opportunities to *parameterise* them for easy testing
(trivial for nested structures — e.g., replace a constant hazard with a flexible
one; much harder for non-nested structures needing redesign). Where structural SA
is impossible, **stay aware that this uncertainty may be at least as important as
parameter uncertainty** and be explicit about the assumptions and plausible
alternatives. **Vintage caveat:** the report itself flags structural uncertainty
as an open research problem — do not imply a settled, general method exists.

## Calibration (VI-14)

When calibration derives parameters (matching model outputs to targets such as
overall/disease-specific mortality and event incidence), **report the uncertainty
around the calibrated values** and reflect it in DSA, PSA, or both. Reporting
routes: deterministic (range of calibrated inputs across convergent sets and the
resulting output range) or probabilistic (Bayesian posteriors of calibrated
parameters, or a discrete joint distribution over convergent input sets, weighted
by goodness of fit). Separate calibration analyses under alternative methodological
approaches should each be reported (objective function, search algorithm,
importance weights on targets).

## Reporting DSA and PSA (VI-12, VI-13, VI-15, VI-16)

**VI-12** It is appropriate to report **both** deterministic and probabilistic
analyses in one evaluation. DSA reporting: **tornado diagrams**, threshold plots,
or simple statements of threshold parameter values. For a tornado, order bars by
length (widest at top) and accompany with a legend/table giving each parameter's
justified upper/lower bounds — the range must be **defensible, not arbitrary**.
Scenario analyses (discrete alternative values from different studies/sources) can
complement continuous ranges. In one-way analysis, **avoid reporting negative
ICERs** — restrict the ICER range to quadrant I; label quadrant II results
"dominated" and quadrant IV "dominant", and distinguish quadrant III from
quadrant I.

**VI-13** Disclose and justify any additional assumptions/values introduced for
uncertainty analysis (distribution parameters, ranges); technical appendices suit
this. When reporting a PSA, disclose the specific distribution (beta/normal/
lognormal) and its parameters, and justify them (empirical, Bayesian synthesis,
or subjective — parameters with little leverage may be left subjective, and
alternative specifications should let users apply their own judgements).

**VI-15** When the purpose of PSA is to guide information-acquisition decisions,
present results as **expected value of information**. EVPI combines the
probability of a wrong decision with its consequence; report it for specified
ICER threshold(s) or as a curve over thresholds. EVPPI identifies key parameters
(report for *groups* of parameters given correlation); EVSI additionally
specifies the assumed study (sample size, level of variation).

**VI-16** For economic studies where PSA is performed **without** a VOI analysis,
present **CEACs** and distributions of **net monetary / net health benefit**; with
**more than two comparators, plot a CEAC for each on the same graph** (optionally
with the cost-effectiveness acceptability *frontier*). EVPI is argued to be the
most appropriate presentational technique for decision uncertainty, alongside
CEACs.
