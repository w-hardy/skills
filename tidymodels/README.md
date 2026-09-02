# tidymodels

Vendored copy of the `tabular-data-ml` user skill from
[tidymodels/skills](https://github.com/tidymodels/skills) — supervised machine
learning on tabular data with the tidymodels framework, covering data spending,
resampling, feature engineering, model tuning, and evaluation.

## Provenance

| | |
| --- | --- |
| Upstream | https://github.com/tidymodels/skills |
| Upstream path | `users/tabular-data-ml` |
| Vendored commit | `ebc3689458a9d69d4ee383f762f83e2e880f5171` (2026-08-28) |
| Licence | MIT — upstream README declares MIT but ships no LICENSE file at that commit, so `tabular-data-ml/LICENSE` reproduces the MIT text attributed to the tidymodels authors |

The skill's frontmatter declares `name: tidymodels`, even though the directory
here (matching upstream's directory layout) is `tabular-data-ml`.

`tidymodels/tabular-data-ml/SKILL.md` and `tidymodels/tabular-data-ml/references/`
are copied **verbatim** from upstream, so that refreshing them is a clean
overwrite rather than a merge. Do not edit them in place; send fixes upstream
instead.

## What is not vendored

Upstream ships more than this one skill, and this one skill ships more than
what is carried here:

- `evals/` under `users/tabular-data-ml` — dev-only evaluation fixtures for
  upstream's own skill authoring workflow.
- Everything outside `users/tabular-data-ml` in the upstream repository —
  other user skills, `.claude-plugin/`, docs, etc.

## Refreshing from upstream

This is automated weekly by `.github/workflows/refresh-vendored-skills.yml`, driven
by `.github/vendored-skills.json`; that workflow updates the provenance table above.
Adding or removing upstream skills still needs a manual edit to
`.claude-plugin/marketplace.json` and the root `README.md` — the workflow's PR body
flags when one is needed but does not make the edit itself. The manual recipe below
is what that workflow runs, for testing or a one-off refresh:

```bash
git clone https://github.com/tidymodels/skills /tmp/tidymodels-skills
rm -rf tidymodels/tabular-data-ml/SKILL.md tidymodels/tabular-data-ml/references
cp /tmp/tidymodels-skills/users/tabular-data-ml/SKILL.md tidymodels/tabular-data-ml/SKILL.md
cp -r /tmp/tidymodels-skills/users/tabular-data-ml/references tidymodels/tabular-data-ml/references
```

Keep `tidymodels/tabular-data-ml/LICENSE` and this `tidymodels/README.md` as they
are — they are locally authored, since upstream ships nothing to replace them.
Then update the provenance table above with the new commit SHA and date.
