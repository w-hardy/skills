# Constructing QALYs and adjusting for baseline

> Source: BMHTA §5.1, Example 5.1 (Eq 5.1 for the AUC, Eq 5.2 for discounting), verified against the
> online edition 2026-09-09. The 10TT trial (Beeken et al. 2017) randomised 537 patients and measures
> HRQL utility at 0, 3, 6, 12, 18 and 24 months; the chapter analyses the **167** complete cases.
> Companion code: `05-ild/ild.R` (bmhta-examples @ `d2a6298`). Discount rate and perspective are
> policy choices — take them from `nice-economic-evaluation`, not from here.

## A QALY is an area, not a measurement

Utility is measured at a handful of visits; the QALY is the **area under the utility profile over
time**. With utilities `u_0 … u_K` at times `t_0 … t_K` (in years), the trapezoid rule gives

```
QALY_i = Σ_k (u_{k-1} + u_k) / 2 × (t_k − t_{k-1})
```

Three errors this formula prevents, all common:

- **Averaging the utilities.** The mean of the visit utilities is not a QALY unless the visits are
  equally spaced *and* you multiply by the horizon. Unequal spacing (as in 0/3/6/12/18/24 months) makes
  a plain mean silently wrong — it over-weights the densely-sampled early period.
- **Summing the utilities.** Dimensionally wrong; a QALY is utility × time.
- **Ignoring the units.** If times are in months, the AUC is in utility-months. Divide by 12.

Linear interpolation between visits is an assumption: it says utility moves smoothly between
measurements. Where a treatment causes a short sharp dip (e.g. surgery, an infusion reaction) that
the visit schedule misses, the trapezoid rule will miss it too. Say so rather than pretending the
AUC is exact.

## Discounting within the trial

For a trial longer than a year, outcomes accruing later are discounted. Apply the discount factor to
each measurement *before* forming the trapezoids, at the year in which it falls:

```r
disc <- function(x, year, rate = 0.035) x / (1 + rate)^(year - 1)
```

Note the `year - 1`: with baseline in year 1, the baseline measurement is undiscounted (factor
`(1+r)^0 = 1`), and only later years are discounted. Getting the offset wrong discounts baseline
too, which shrinks every arm's QALYs by the same factor and is easy to miss because the
*incremental* result barely moves.

A worked implementation, per patient, from wide-format utility columns:

```r
qalys <- trial |>
  select(id, arm, starts_with("qol_")) |>
  pivot_longer(
    starts_with("qol_"),
    names_to = "month", names_prefix = "qol_",
    names_transform = list(month = as.integer),
    values_to = "utility"
  ) |>
  mutate(
    year          = pmax(1, ceiling(month / 12)),
    utility_disc  = disc(utility, year)
  ) |>
  group_by(id) |>
  arrange(month, .by_group = TRUE) |>
  mutate(
    width = month - lag(month, default = 0),
    # trapezoid height: this visit's utility plus the previous one
    height = utility_disc + lag(utility_disc, default = 0),
    area   = height * width / 2
  ) |>
  summarise(qaly = sum(area) / 12, .groups = "drop")   # months -> years
```

`lag(..., default = 0)` makes the first interval run from time 0 with a utility of 0 on its left
edge. That is only right if the *baseline visit is at time 0* and is itself included in the series —
which it is here, contributing a zero-width trapezoid. Check that assumption against the visit
schedule rather than copying the idiom; a trial whose first utility measurement is at 3 months needs
an explicit decision about the first three months, not a silent zero.

Costs are usually already a per-patient total. Discount them on the same schedule as the utilities,
using the same rate, and say which resource-use period each cost covers.

## Adjusting for baseline utility

**Always include baseline utility as a covariate in the effects model.** (§5.2.1.) This is not optional
tidying; it is the single most consequential covariate in a within-trial CEA.

Randomisation balances baseline utility *in expectation*, not in any particular trial. Because
follow-up utility is strongly correlated with baseline utility, a chance imbalance at baseline
propagates directly into the QALY difference and is indistinguishable from a treatment effect.
Adjusting removes that component and, as a bonus, reduces the residual variance and so tightens the
incremental estimate.

Mean-centre it:

```r
trial <- trial |> mutate(u0_c = qol_0 - mean(qol_0, na.rm = TRUE))
```

Centring does not change the treatment coefficient, but it makes the intercept interpretable as the
outcome at *average* baseline utility rather than at a utility of zero (which no one has), and it
improves sampler geometry. In the effects model the linear predictor is then
`alpha0 + alpha1 * treatment + alpha2 * u0_c`, and the arm-level means are read off at `u0_c = 0`.

Two things not to do:

- **Do not adjust the cost model for baseline utility by reflex.** In the source's models, baseline
  utility enters the *effects* equation; costs are linked to effects through the joint structure
  (see `joint-cost-effect-models.md`). Adding it to costs as well is defensible if baseline health
  plausibly drives cost directly, but it should be a stated choice, not an accident of copying the
  formula.
- **Do not use change-from-baseline as the outcome.** Model the QALY and adjust for baseline;
  differencing throws away information and reintroduces regression to the mean.

## Scaling costs before fitting

Total costs in pounds often run to five figures, while QALYs run 0–2. A prior that is weak for a
QALY coefficient is extremely informative for a cost coefficient on the raw scale, and the sampler
has to explore wildly different scales at once.

Rescale costs to £1,000 units before fitting, and rescale the *posterior* back at the end:

```r
trial <- trial |> mutate(cost_k = total_cost / 1000)
# ... fit on cost_k ...
# draws of the arm-level mean cost, back on the natural scale:
mu_cost <- 1000 * mu_cost_k
```

Two rules that follow. First, whatever you rescale by, **state the prior in the rescaled units** —
a `normal(0, 10)` prior on a £1,000-scale coefficient means something entirely different from the
same prior on a £1 scale, and reviewers cannot check a prior whose units are implicit. Second,
**rescale back before handing draws downstream**: `bayesian-cea-r-hta` and BCEA expect costs in the
currency the willingness-to-pay threshold is denominated in. Multiplying by 1,000 is linear, so it
can be applied to the draws directly without disturbing the joint distribution.
