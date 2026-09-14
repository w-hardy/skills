# Preparing and Publishing a Pull Request Review

Read this file once the user asks for implementer-facing feedback, a pending review, or a
submitted review. It covers how to turn accepted findings into comments and how to post them.
Nothing here changes what counts as a finding.

## Preparing Implementer Feedback

Do not submit the internal review report verbatim. Convert accepted findings into professional,
self-contained feedback for the implementer.

For each proposed inline comment, include:
- The file and diff line
- The observable problem
- The failure mode or practical impact
- A concrete requested change or a focused question

Keep unverified concerns phrased as questions. Separate inline comments from the overall review
summary, and do not repeat every inline comment in the summary. Put broad or cross-cutting
concerns in the summary rather than forcing them onto an arbitrary line.

Only attach an inline comment to a line that is part of the PR diff. Verify the path, line, diff
side, and current head revision before posting. Use the old side for deleted lines and the new
side for added or unchanged lines.

When preparing feedback without posting, provide:
1. A proposed review summary
2. Proposed inline comments with `path:line` locations
3. A recommended GitHub disposition: Approve, Comment, or Request Changes

## Publishing a Pull Request Review

Never write to GitHub without the user's explicit confirmation. Distinguish these actions:

1. **Prepare only**: Draft the summary and inline comments without changing GitHub
2. **Create pending review**: Create one pending review and add the approved inline comments, but
do not submit it
3. **Submit review**: Submit as `APPROVE`, `COMMENT`, or `REQUEST_CHANGES`

Before creating or submitting a review, confirm the repository, PR number, selected comments, and
intended action. Before submission, ask the user to choose the exact event:
- **Approve** maps to `APPROVE`
- **Comment** maps to `COMMENT`
- **Request Changes** maps to `REQUEST_CHANGES`

A pending review can contain inline comments, but its overall summary cannot be pre-submitted.
Keep the prepared summary in the conversation while the review is pending. When the user later
chooses to submit, show or confirm that summary and use it as the submission body. Do not post it
early as a separate PR comment.

When available, the `gh-pr-review` extension and its associated skill are convenient for line-level reviews:

```sh
gh pr-review review --start -R owner/repo <pr-number>
gh pr-review review --add-comment -R owner/repo <pr-number> \
  --review-id <PRR_...> --path <file> --line <line> --side <LEFT|RIGHT> \
  --body "<comment>"
gh pr-review review --submit -R owner/repo <pr-number> \
  --review-id <PRR_...> --event <APPROVE|COMMENT|REQUEST_CHANGES> \
  --body "<review-summary>"
```

The extension is optional. Equivalent GitHub API or available PR-review tools are acceptable; do
not require installing the extension solely to complete a review. Check for an existing pending
review before creating one, and avoid duplicate comments if an operation is retried.

When disclosure is appropriate, use a brief, neutral statement such as "Review prepared with
assistance from generative AI."
