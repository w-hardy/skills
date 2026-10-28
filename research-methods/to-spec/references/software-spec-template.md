# Software spec template

From mattpocock/skills `to-spec` (MIT), commit 59db609. Changes: the user-story count is tied to coverage rather than "extremely extensive", and Assumptions and Open questions sections are added.

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A numbered list of user stories covering every behaviour the feature must have; as many as that takes and no padding. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a reviewer of the cost-effectiveness model, I want to change the discount rate in the app, so that I can see how sensitive the ICER is to it
</user-story-example>

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behaviour, not implementation details)
- Which modules will be tested, and at which seam
- Prior art for the tests (i.e. similar tests in the codebase, such as existing testthat files)

## Assumptions

What the conversation assumed without the user stating it.

## Out of Scope

A description of the things that are out of scope for this spec.

## Open Questions

Anything the spec needs that was never settled.

## Further Notes

Any further notes about the feature.

</spec-template>
