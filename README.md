# Posit Claude Skills

A collection of Claude Skills from Posit!

Claude Skills extend Claude's capabilities with specialized knowledge and workflows. Skills are automatically activated by Claude based on your task and can be used in Claude.ai, Claude Code, or via the Claude API. Learn more at the [Claude Skills documentation](https://support.claude.com/en/articles/12512180-using-skills-in-claude).

## Available Skills

### Posit Developer

General-purpose developer skills useful across any language, project type, or context.

- **[critical-code-reviewer](./posit-dev/critical-code-reviewer/)** - Conduct rigorous, adversarial code reviews identifying security holes, lazy patterns, edge case failures, and bad practices across Python, R, JavaScript/TypeScript, SQL, and front-end code
- **[describe-design](./posit-dev/describe-design/)** - Research a codebase and create architectural documentation describing how features or systems work, with Mermaid diagrams and stable code references suitable for humans and AI agents
- **[new-work](./posit-dev/new-work/)** - Create a todo tracking document for a new feature, bug, or task; keeps it updated with decisions, plans, and progress for the rest of the session
- **[review-testing](./posit-dev/review-testing/)** - Review test code for quality, design, and completeness after implementing a feature or fixing a bug, covering assertion completeness, mocking boundaries, fixture design, test smells, and coverage gaps
- **[working-on](./posit-dev/working-on/)** - Set an existing tracking document as the source of truth for the current session, keeping it updated with decisions and progress


### GitHub

Skills for GitHub pull request workflows — creating PRs, addressing review feedback, and resolving threads.

- **[pr-create](./github/pr-create/)** - Creates a pull request from current changes, monitors GitHub CI, and debugs any failures until CI passes
- **[pr-threads-address](./github/pr-threads-address/)** - Review all unresolved PR review threads, address them by making necessary code changes, and commit the changes appropriately
- **[pr-threads-resolve](./github/pr-threads-resolve/)** - Bulk resolve unresolved PR review threads

### Open Source

Skills for open-source R and Python package developers, streamlining common workflows like releases, changelogs, and contributor acknowledgments.

- **[create-release-checklist](./open-source/create-release-checklist/)** - Create a release checklist and GitHub issue for an R package, with automatic version calculation and customizable checklist generation
- **[release-post](./open-source/release-post/)** - Create professional package release blog posts following Tidyverse or Shiny blog conventions, with support for both R and Python packages
- **[maintainer-decline](./open-source/maintainer-decline/)** - Draft issue closure and decline responses as an open-source maintainer, covering won't-fix closures, redirects to other packages, intentional-design explanations, and deprecation notices

### R Package Development

R package development skills for working with the r-lib ecosystem and modern R package workflows.

- **[testing-r-packages](./r-lib/testing-r-packages/)** - Best practices for writing R package tests using testthat 3+, including test structure, expectations, fixtures, snapshots, mocking, and BDD-style testing
- **[cli](./r-lib/cli/)** - Comprehensive guidance for using the cli R package for command-line interface styling, semantic messaging, and user communication with inline markup, progress indicators, and theming
- **[cran-extrachecks](./r-lib/cran-extrachecks/)** - Prepare R packages for CRAN submission by checking for common ad-hoc requirements not caught by `devtools::check()`, including documentation standards, DESCRIPTION field formatting, and URL validation
- **[lifecycle](./r-lib/lifecycle/)** - Manage R package lifecycle according to tidyverse principles using the lifecycle package, covering deprecation workflows, function/argument renaming, superseding, and experimental stages
- **[r-package-development](./r-lib/r-package-development/)** - R package development with devtools, testthat, and roxygen2, covering key commands, coding conventions, testing, documentation, and NEWS.md practices
- **[mirai](./r-lib/mirai/)** - Async, parallel, and distributed computing in R using mirai, covering explicit dependency passing, daemon setup, parallel mapping with `mirai_map()`, Shiny integration, remote/HPC launchers, and migration from future/parallel
- **[alt-text](./alt-text/)** - Generate and improve accessible alt text for data visualizations and images in pkgdown sites and Quarto documents, covering vignette code chunks (`fig.alt`), static markdown images, and multi-plot chunks

### ggsql

Skills for writing ggsql queries — a grammar of graphics for SQL.

- **[ggsql](./ggsql/ggsql/)** - Write ggsql queries — a grammar of graphics for SQL. Use when the user wants to create, modify, or understand a ggsql visualization query

### Shiny

Skills for Shiny app development in both R and Python.

- **[brand-yml](./brand-yml/)** - Create and apply brand.yml files for consistent styling across Shiny apps, with support for bslib (R) and ui.Theme (Python), including automatic brand discovery and theming functions for plots and tables
- **[shiny-bslib](./shiny/shiny-bslib/)** - Build modern Shiny dashboards using bslib with Bootstrap 5 layouts, cards, value boxes, navigation, theming, and modern inputs. Includes migration guide from legacy Shiny patterns
- **[shiny-bslib-theming](./shiny/shiny-bslib-theming/)** - Comprehensive theming for Shiny apps using bslib, covering bs_theme(), Bootswatch themes, custom colors, typography, Bootstrap Sass variables, custom Sass/CSS rules, dark mode, dynamic theming, and R plot theming

### Quarto

Skills for Quarto document creation and publishing.

- **[brand-yml](./brand-yml/)** - Create and apply brand.yml files for consistent styling across Quarto projects, supporting HTML documents, dashboards, RevealJS presentations, Typst PDFs, and websites with automatic brand discovery and theme layering
- **[authoring](quarto/README.md#quarto-authoring-skill)** - Comprehensive guidance for Quarto document authoring and R Markdown migration. Write new Quarto documents with best practices, convert R Markdown files, migrate bookdown/blogdown/xaringan/distill projects, and use Quarto-specific features like hashpipe syntax, cross-references, callouts, and extensions
- **[alt-text](./alt-text/)** - Generate and improve accessible alt text for figures in Quarto documents using Amy Cesal's three-part formula (chart type, data description, key insight). Supports code-generated plots and static images

### Connect

Skills for deploying and managing content on Posit Connect.

- **[deploy-to-connect](./connect/deploy-to-connect/)** - Deploy or publish Python and R content to a Posit Connect server using rsconnect-python or the R rsconnect package. Covers interactive apps and dashboards, web APIs, rendered documents, and prepared bundles/manifests

### Health Technology Assessment

Health economic evaluation and HTA in R — model structure, estimation, evidence synthesis, costing, and reporting.

- **[nice-economic-evaluation](./hta/nice-economic-evaluation/)** - Align economic evaluations to the NICE reference case and methods manual (PMG36), covering comparators, time horizon, discounting, utilities, the severity modifier, fully incremental analysis, and the DSU Technical Support Documents
- **[ispor-smdm-good-practices](./hta/ispor-smdm-good-practices/)** - Apply the ISPOR-SMDM Modeling Good Research Practices reports when conceptualising, structuring, validating, or auditing a decision-analytic model, including model-type choice and the uncertainty taxonomy
- **[decision-modelling-hta](./hta/decision-modelling-hta/)** - Build, review, and debug decision trees and cohort Markov models with heemod, covering transition matrices, ICERs, net benefit, and probabilistic sensitivity analysis
- **[multistate-models-hta](./hta/multistate-models-hta/)** - Continuous-time and individual-level multistate models with flexsurv, msm, and hesim, covering transition intensities, clock-forward versus clock-reset timing, and individual-level simulation
- **[hesim-ctstm-hta](./hta/hesim-ctstm-hta/)** - Implementation depth for the hesim IndivCtstm engine: params_surv_list assembly, mixed clock-reset and clock-forward transitions, pwexp background mortality with state-specific SMRs, define_rng PSA, and the native CEA
- **[discrete-event-simulation-hta](./hta/discrete-event-simulation-hta/)** - Discrete event simulation for economic evaluation with simmer, for pathways where event history, competing events, or resource constraints and queues matter
- **[survival-analysis-hta](./hta/survival-analysis-hta/)** - Parametric survival modelling and extrapolation with flexsurv, flexsurvcure, and survHE, covering distribution choice, restricted mean survival, KM curve reconstruction, and conversion to transition probabilities
- **[bayesian-cea-r-hta](./hta/bayesian-cea-r-hta/)** - Post-process and present Bayesian cost-effectiveness analyses — PSA draws, cost-effectiveness planes, CEAC/CEAF curves, incremental net benefit, BCEA, and value of information (EVPI/EVPPI/EVSI)
- **[network-meta-analysis-hta](./hta/network-meta-analysis-hta/)** - Network meta-analysis and indirect treatment comparison with multinma and netmeta, covering heterogeneity, meta-regression, treatment ranking, and the consistency assumption
- **[population-adjusted-comparisons](./hta/population-adjusted-comparisons/)** - Population-adjusted indirect comparisons (MAIC, STC, ML-NMR) for effect-modifier imbalance across trials, following NICE DSU TSD 17 and TSD 18
- **[hrg4-costing-grouper](./hta/hrg4-costing-grouper/)** - Prepare inputs for, run, and interpret output from the NHS England HRG4+ National Costs Grouper, covering Record Definition Files, the dataset specifications, and diagnosing grouper validation failures
- **[cheers-2022-reporting](./hta/cheers-2022-reporting/)** - Apply the CHEERS 2022 statement so economic evaluations are completely and transparently reported, for manuscript drafting, checklist completion, and reporting-quality appraisal
- **[shiny-hta](./hta/shiny-hta/)** - Wrap an R health economic model in an interactive Shiny application, covering ui/server design, controlling recomputation, editable input tables, dynamic UI, and saving model state

### Biostatistics

Applied biostatistics for clinical research in R — estimation, causal questions, prediction, and reporting.

- **[brms-modelling](./biostatistics/brms-modelling/)** - Write, debug, and review Bayesian regression models with brms, covering formulas, priors, fitting arguments, convergence diagnostics, posterior predictive checks, model comparison with loo, and reporting
- **[missing-data-mice](./biostatistics/missing-data-mice/)** - Multiple imputation with mice following van Buuren's Flexible Imputation of Missing Data, covering predictor selection, convergence diagnostics, multilevel and longitudinal imputation, MNAR sensitivity analysis, and pooling
- **[causal-inference-gmethods](./biostatistics/causal-inference-gmethods/)** - Estimate causal treatment effects from observational data using DAGs, propensity scores, inverse probability weighting, g-computation, doubly robust estimation, and target trial emulation
- **[mediation-analysis](./biostatistics/mediation-analysis/)** - Decompose total effects into direct and indirect pathways using the counterfactual framework, covering natural and interventional effects, exposure-mediator interaction, and sensitivity analysis
- **[clinical-prediction-models](./biostatistics/clinical-prediction-models/)** - Develop, validate, and appraise diagnostic and prognostic risk models, covering sample size, shrinkage, discrimination, calibration, decision curves, optimism correction, and external validation
- **[continuous-predictors-splines](./biostatistics/continuous-predictors-splines/)** - Model continuous predictors with restricted cubic splines and fractional polynomials, covering knot placement, testing and reporting non-linearity, and the case against categorising
- **[penalised-regression](./biostatistics/penalised-regression/)** - Fit and interpret ridge, LASSO, and elastic net with glmnet, covering lambda selection, regularisation paths, standardisation, and when penalisation actually helps
- **[tripod-ai-reporting](./biostatistics/tripod-ai-reporting/)** - Apply the TRIPOD+AI reporting statement and PROBAST+AI risk-of-bias appraisal to prediction model studies, for manuscript drafting, checklist completion, and systematic review

### Clinical Machine Learning

Machine learning on tabular clinical data in R.

- **[ml-supervised-tabular](./ml-clinical/ml-supervised-tabular/)** - Apply and appraise decision trees, random forests, gradient boosting, and neural networks on tabular clinical data, covering train/test design, cross-validation, tuning, calibration, and class imbalance
- **[ml-explainability-clinical](./ml-clinical/ml-explainability-clinical/)** - Interrogate black-box models with permutation importance, partial dependence, accumulated local effects, SHAP, and LIME, and judge what those explanations do and do not establish
- **[clustering-clinical](./ml-clinical/clustering-clinical/)** - Find and validate patient subgroups with k-means, hierarchical clustering, DBSCAN, and latent class analysis, with emphasis on establishing whether the clusters are real
- **[dimensionality-reduction-clinical](./ml-clinical/dimensionality-reduction-clinical/)** - Reduce and visualise high-dimensional clinical or omics data with PCA, t-SNE, and UMAP, covering component choice, hyperparameters, and reading the output without over-reading it

## Installation

### Using `npx skills add` (Any Agent)

Install skills from this repository into any supported coding agent (Claude Code, Codex, Cursor, Cline, and [many more](https://github.com/vercel-labs/skills)) using the `npx skills add` CLI:

```bash
# List available skills without installing
npx skills add posit-dev/skills --list

# Install skills via an interactive menu
npx skills add posit-dev/skills --all

# Install specific skills by category name
npx skills add posit-dev/skills --skill cli --skill lifecycle

# Install to Claude Code only, globally
npx skills add posit-dev/skills --agent claude-code --global
```

### Claude Code

#### Method 1: Add Marketplace

Add this repository as a plugin marketplace in Claude Code:

```
/plugin marketplace add posit-dev/skills
```

Then browse and install the skill categories you need through the Claude Code UI.

#### Method 2: Direct Installation

Install specific skill categories directly:

```
/plugin install posit-dev@posit-dev-skills
/plugin install github@posit-dev-skills
/plugin install open-source@posit-dev-skills
/plugin install ggsql@posit-dev-skills
/plugin install r-lib@posit-dev-skills
/plugin install shiny@posit-dev-skills
/plugin install quarto@posit-dev-skills
/plugin install connect@posit-dev-skills
/plugin install hta@posit-dev-skills
/plugin install biostatistics@posit-dev-skills
/plugin install ml-clinical@posit-dev-skills
```

Each command installs all skills in that category.

#### Method 3: Manual Installation

For customization or offline use:

1. Clone this repository:

   ```bash
   git clone https://github.com/posit-dev/skills.git
   cd skills
   ```

2. Copy individual skills to your Claude Code skills directory:

   ```bash
   cp -r open-source/release-post ~/.config/claude-code/skills/
   ```

3. Or install all skills from a category:
   ```bash
   for skill in open-source/*/; do
     cp -r "$skill" ~/.config/claude-code/skills/
   done
   ```

### Claude.ai

Skills can be uploaded to Claude.ai following the [Creating Custom Skills guide](https://support.claude.com/en/articles/12512198-creating-custom-skills).

### Claude API

Use the [Skills API](https://docs.claude.com/en/api/skills-guide) to programmatically load and manage skills in your applications.

## Using Skills

Once installed, Claude will automatically activate relevant skills based on your task. You don't need to explicitly invoke them.

For example, with the `release-post` skill installed:

```
You: Help me write a release post for dplyr 1.2.0

Claude: I'll help you create a release post. First, let me gather some information...
```

Claude will use the skill's knowledge to guide you through creating a properly formatted release post.

## Skill Categories

This repository organizes skills into categories to make it easier to find and install skills relevant to your work:

| Category        | Description                                                 |
| --------------- | ----------------------------------------------------------- |
| **posit-dev**   | General-purpose developer skills (code review, architecture docs) |
| **ggsql**     | ggsql query writing — a grammar of graphics for SQL                 |
| **github**    | GitHub PR workflows (create PRs, address review threads, resolve threads) |
| **open-source** | Open-source R/Python package workflows (releases, changelogs)     |
| **r-lib**       | R package development with the r-lib ecosystem              |
| **shiny**       | Shiny app development and deployment (R and Python)         |
| **quarto**      | Quarto document creation and publishing                     |
| **connect**     | Posit Connect deployment and management                     |
| **hta**         | Health technology assessment and health economic evaluation in R |
| **biostatistics** | Applied biostatistics for clinical research in R          |
| **ml-clinical** | Machine learning on tabular clinical data in R              |

<!-- Future category ideas

| **tidyverse** | Tidyverse-specific package development |
-->

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on creating new skills.

**We highly recommend using Anthropic's [skill-creator](https://github.com/anthropics/skills) skill** to help you build high-quality skills. Skills should be grouped together by category, but the category groups are flexible. Feel free to propose new categories as needed.

## License

This repository is licensed under the MIT License. See [LICENSE](./LICENSE) for details.

## Resources

- [Claude Skills Overview](https://www.anthropic.com/news/skills)
- [Using Skills in Claude](https://support.claude.com/en/articles/12512180-using-skills-in-claude)
- [Creating Custom Skills](https://support.claude.com/en/articles/12512198-creating-custom-skills)
- [Skills API Documentation](https://docs.claude.com/en/api/skills-guide)
- [Anthropic's Official Skills Repository](https://github.com/anthropics/skills)

## Support

If you have questions or encounter issues, check the [Claude Skills documentation](https://support.claude.com/en/articles/12512180-using-skills-in-claude) or [open an issue](https://github.com/posit-dev/skills/issues/new) on GitHub.

---

**Built with ❤️ + ☕ + 🤖 at Posit**
