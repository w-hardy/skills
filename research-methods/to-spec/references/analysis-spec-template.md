# Analysis spec template

Omit a section only when it genuinely does not apply, and say so in one line rather than leaving it out silently.

<analysis-spec-template>

## Question and decision

The question the analysis answers and the decision or claim it informs, from the reader's perspective. Who the audience is.

## Estimand

Population, treatment conditions being compared, outcome variable, handling of each intercurrent event (and the strategy chosen), and the population-level summary. For an economic evaluation, also: perspective (defined by the cost components included), comparators, time horizon, discount rates, currency and price year, and the threshold or willingness-to-pay range used.

## Data

Sources, linkage and how linkage success is checked (including by arm), inclusion and exclusion, unit of analysis, repeated measures or clustering, and the sample size against the complexity of the planned models.

## Derived variables

Each derived concept, named with the glossary's term, and in one line what it is built from. Derivation rules themselves belong in the codebook.

## Analysis methods

The primary analysis, then secondary analyses. For each: the model, what it adjusts for and why, and how the estimand above maps onto it.

## Missing data

Expected extent, the assumed mechanism and why, the primary approach, and the sensitivity analyses that test departures from it.

## Uncertainty, sensitivity and scenario analyses

Which kinds of uncertainty are characterised (sampling, structural, methodological, parameter) and how. Each prespecified sensitivity or scenario analysis in one line.

## Outputs

Each table and figure the analysis will produce, with a short identifier and one line on what it shows.

## Checks

The agreed checks that would show the analysis is right (step 2 of the skill), and the reproducibility requirements (fixed seeds, pinned package versions, how caches are invalidated).

## Decisions and deviations

Hard-to-reverse decisions made in the conversation, linking any ADRs. Every departure from the SAP or HEAP, with its timing relative to seeing outcome data.

## Assumptions

What the conversation assumed without the user stating it.

## Out of scope

What this analysis will not do.

## Open questions

Anything the spec needs that was never settled.

</analysis-spec-template>
