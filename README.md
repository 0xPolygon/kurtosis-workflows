# Kurtosis Workflows

Shared GitHub Actions and reusable workflows for the Kurtosis repositories
([kurtosis-cdk](https://github.com/0xPolygon/kurtosis-cdk),
[kurtosis-pos](https://github.com/0xPolygon/kurtosis-pos),
[optimism-package](https://github.com/agglayer/optimism-package)).

This repository must not contain secrets. Credentials and environment-specific identifiers (GCP
workload identity provider, service account) stay in the calling repository and are passed as
inputs. Defaults cover the common setup, so callers only override what differs.

## Actions

| Action | Description |
| --- | --- |
| [`setup-kurtosis`](.github/actions/setup-kurtosis/action.yml) | Install the Kurtosis CLI and write its CI configuration. |
| [`pull-images`](.github/actions/pull-images/action.yml) | Pre-pull Docker images in parallel with bounded retries, optionally from a registry mirror. |
| [`pull-kurtosis-images`](.github/actions/pull-kurtosis-images/action.yml) | Pre-pull the images a Kurtosis engine needs from the registry mirror. |
| [`verify-package-pins`](.github/actions/verify-package-pins/action.yml) | Check that external package versions are pinned only in the `replace` block of `kurtosis.yml`. |
| [`job-durations`](.github/actions/job-durations/action.yml) | Append a table of each job's duration in the current run to the job summary. |

## Workflows

| Workflow | Description |
| --- | --- |
| [`version-matrix`](.github/workflows/version-matrix.yml) | Check the version matrix, open or refresh a bump PR with Claude, post the outcome to Slack. |
| [`claude`](.github/workflows/claude.yml) | Answer `@claude` mentions in issues and PRs, and submit PR reviews. |
| [`lint`](.github/workflows/lint.yml) | Run `kurtosis lint`, rumdl, ruff, typos and shfmt, each as an opt-in job. |
| [`unit`](.github/workflows/unit.yml) | Run the unit tests of a package with `kurtosis-test`. |
| [`workflow-summary`](.github/workflows/workflow-summary.yml) | Post a one-line Slack recap of a run, linking the failed jobs. |
| [`docs`](.github/workflows/docs.yml) | Build an npm website and optionally deploy it to GitHub Pages. |

## Templates

| Template | Description |
| --- | --- |
| [`dependabot.yml`](templates/dependabot.yml) | Reference Dependabot configuration: one weekly PR for all ecosystems. |

## Usage

Reference a release tag (`@vX.Y.Z`), or a commit SHA for an immutable pin.

### setup-kurtosis

```yaml
- id: kurtosis
  uses: 0xPolygon/kurtosis-workflows/.github/actions/setup-kurtosis@v0.1.2
```

`kurtosis_version` is optional and defaults to the version this release is tested with. The installed
version is the `version` output, e.g. to pull the matching `kurtosistech/engine` image.

### pull-images

Authenticate to the registry first: the action only pulls. Images pulled through
`registry_prefix` are tagged back to their original names (except digest-pinned ones).

```yaml
- uses: google-github-actions/auth@7c6bc770dae815cd3e89ee6cdf493a5fab2cc093 # v3.0.0
  with:
    workload_identity_provider: ${{ vars.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ vars.GCP_SERVICE_ACCOUNT }}

- run: gcloud auth configure-docker europe-west2-docker.pkg.dev

# Images already rewritten with the mirror prefix.
- uses: 0xPolygon/kurtosis-workflows/.github/actions/pull-images@v0.1.2
  with:
    images_file: modified-images.txt

# Images pulled from the mirror and tagged back as listed.
- uses: 0xPolygon/kurtosis-workflows/.github/actions/pull-images@v0.1.2
  with:
    registry_prefix: europe-west2-docker.pkg.dev/<project>/<repository>
    images: |
      kurtosistech/engine:1.23.0
      kurtosistech/core:1.23.0
```

Other inputs: `attempts` (3), `retry_delay` in seconds (5), `parallelism` (8) and
`skip_present` (false, skips images already loaded, e.g. from a cache).

### pull-kurtosis-images

Same registry authentication as `pull-images`. Pulls the Kurtosis engine, core and
files-artifacts-expander images for the installed version, plus the helper images every Kurtosis
engine needs (vector, traefik, the ethereum-package genesis generator, deployment-utils, ...), all
from the mirror and tagged back to their original names. The genesis generator version follows the
ethereum-package commit the Kurtosis packages pin: bump it with them. `images` / `images_file` add
package-specific images.

```yaml
- uses: 0xPolygon/kurtosis-workflows/.github/actions/pull-kurtosis-images@v0.1.6
  with:
    kurtosis_version: ${{ steps.kurtosis.outputs.version }}
```

`registry_prefix` defaults to the Polygon Artifact Registry mirror.

### version-matrix

The calling repository keeps its scripts (`<scripts_dir>/requirements.txt`,
`extract-versions.py`, `generate-markdown.py`), its `update-version-matrix` skill, its schedule and
its secrets. Secrets are passed by name: `secrets: inherit` does not cross organizations.

```yaml
name: version-matrix

on:
  schedule:
    - cron: 0 4 * * 1
  workflow_dispatch:
    inputs:
      notify:
        description: Post the summary to Slack, as scheduled runs do.
        type: boolean
        default: false

permissions: {}

jobs:
  version-matrix:
    permissions:
      actions: read # list the jobs to link them in the Slack message
      contents: read
      id-token: write
      pull-requests: read
    uses: 0xPolygon/kurtosis-workflows/.github/workflows/version-matrix.yml@v0.1.2
    secrets:
      claude_api_key: ${{ secrets.CLAUDE_API_KEY }}
      app_id: ${{ secrets.SEMANTIC_RELEASE_BOT_APP_ID }}
      app_private_key: ${{ secrets.SEMANTIC_RELEASE_BOT_APP_PRIVATE_KEY }}
      slack_bot_token: ${{ secrets.SLACK_BOT_TOKEN }}
```

The outcome is posted to Slack on scheduled runs, and on manual runs whose own `notify` input is true
(declare it as above). The Slack message reads `<label>: up to date ✅`, `<label>: outdated ❌, bump PR opened: #123`,
and so on, the label linking to the run.

| Input | Default | Description |
| --- | --- | --- |
| `label` | `<repository name> version matrix` | Name of the matrix in the Slack message. |
| `notify` | `true` | Post the outcome to Slack on scheduled runs and notifying manual runs, `false` to never post. |
| `slack_channel_id` | `C04DS0SG599` | Slack channel the outcome is posted to. |
| `scripts_dir` | `scripts/version-matrix` | Directory of the version matrix scripts. |
| `python_version` | `3.13` | Python version used to run them. |
| `check_timeout_minutes` | `5` | Timeout of the check job. |
| `skill_path` | `.claude/skills/update-version-matrix/SKILL.md` | Skill Claude follows to bump the pins. |
| `kurtosis_version` | `1.23.0` | Kurtosis CLI installed for the bump job, empty to skip. |
| `kurtosis_test_version` | `v0.0.11` | kurtosis-test release installed for the bump job, empty to skip. |
| `use_mise` | `false` | Install the tools of the repository's `mise.toml` for the bump job. |
| `extra_allowed_tools` | `""` | Tools allowed to Claude on top of the default set (`kurtosis lint`, `kurtosis-test` and `kurtosis run --dry-run` included). |
| `max_turns` | `60` | Maximum number of Claude turns. |
| `bump_timeout_minutes` | `30` | Timeout of the bump job. |
| `base_branch` | `main` | Branch the bump PR targets; bumps only run on it. |
| `pr_branch` | `chore/bump-version-matrix` | Head branch of the bump PR. |
| `add_paths` | `.`, `:!.github/workflows`, `:!.claude` | Pathspecs committed in the bump PR. |

| Secret | Description |
| --- | --- |
| `read_token` | Optional token for `extract-versions.py`, defaults to the workflow token. |
| `claude_api_key` | Anthropic API key. |
| `app_id`, `app_private_key` | GitHub App opening the bump PR, so that the PR triggers CI. |
| `slack_bot_token` | Slack bot token, required when `notify` is true. |

Outputs: `outdated`, `pr-operation`, `pr-url`.

### claude

The calling repository keeps the triggers and the concurrency group. Only human `OWNER`, `MEMBER` and
`COLLABORATOR` accounts can trigger it, and fork heads are never checked out.

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  pull_request_review:
    types: [submitted]
  issues:
    types: [opened, assigned]

concurrency:
  group: claude-${{ github.event.issue.number || github.event.pull_request.number }}
  cancel-in-progress: false

permissions: {}

jobs:
  claude:
    permissions:
      actions: read
      contents: read
      id-token: write
      issues: write
      pull-requests: write
    uses: 0xPolygon/kurtosis-workflows/.github/workflows/claude.yml@v0.1.2
    secrets:
      claude_api_key: ${{ secrets.CLAUDE_API_KEY }}
```

Input: `timeout_minutes` (15).

### lint

Defaults suit a Kurtosis package, so a plain call runs `kurtosis lint`, rumdl on the whole repository,
typos and shfmt. Set an input to an empty value (or `false`) to turn a check off.

```yaml
jobs:
  lint:
    permissions:
      contents: read
    uses: 0xPolygon/kurtosis-workflows/.github/workflows/lint.yml@v0.1.2
```

| Input | Default | Description |
| --- | --- | --- |
| `kurtosis_version` | `1.23.0` | Kurtosis CLI used by `kurtosis lint`, empty to skip. |
| `markdown_paths` | `.` | Paths checked by rumdl, empty to skip. |
| `typos` | `true` | Run typos. |
| `shfmt_version` | `3.13.1` | shfmt release, empty to skip. |
| `python_paths` | `""` | Paths checked by ruff, empty to skip (off by default). |
| `python_version` | `3.13` | Python version of the ruff check. |
| `ruff_version` | `0.14.3` | ruff release. |
| `timeout_minutes` | `5` | Timeout of each job. |

### docs

A plain call builds the website of `docs/` on every run, runs `npm run typecheck` when the website
defines it, and deploys to GitHub Pages on pushes to the default branch. The calling job needs the
`pages` and `id-token` permissions.

```yaml
jobs:
  docs:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: 0xPolygon/kurtosis-workflows/.github/workflows/docs.yml@v0.1.2
```

| Input | Default | Description |
| --- | --- | --- |
| `node_version` | `24.22.1` | Node.js version. |
| `docs_dir` | `docs` | Website directory, holding `package-lock.json`. |
| `build_dir` | `build` | Build output, relative to `docs_dir`. |
| `typecheck` | `true` | Run `npm run typecheck` if defined. |
| `deploy` | `true` | Deploy on pushes to the default branch, `false` to only build. |
| `build_timeout_minutes` | `10` | Timeout of the build job. |
| `deploy_timeout_minutes` | `15` | Timeout of the deploy job. |

### verify-package-pins

```yaml
- uses: actions/checkout@v7
- uses: 0xPolygon/kurtosis-workflows/.github/actions/verify-package-pins@v0.1.3
```

Runs offline. The repository's own package (from `GITHUB_REPOSITORY`) is never required to be pinned.

### job-durations

```yaml
- uses: 0xPolygon/kurtosis-workflows/.github/actions/job-durations@v0.1.3
```

The calling job needs `actions: read`.

### unit

```yaml
jobs:
  unit:
    permissions:
      contents: read
    uses: 0xPolygon/kurtosis-workflows/.github/workflows/unit.yml@v0.1.3
```

| Input | Default | Description |
| --- | --- | --- |
| `kurtosis_test_version` | `v0.0.11` | kurtosis-test release. |
| `path` | `.` | Path of the package to test. |
| `timeout_minutes` | `10` | Timeout of the job. |

### workflow-summary

```yaml
jobs:
  workflow-summary:
    if: always() && github.event_name == 'schedule'
    needs: [build, test]
    permissions:
      actions: read
    uses: 0xPolygon/kurtosis-workflows/.github/workflows/workflow-summary.yml@v0.1.3
    with:
      name: Kurtosis CDK Nightly
      needs: ${{ toJSON(needs) }}
    secrets:
      slack_bot_token: ${{ secrets.SLACK_BOT_TOKEN }}
```

| Input | Default | Description |
| --- | --- | --- |
| `name` | required | Name shown in the message. |
| `needs` | required | `toJSON(needs)` of the calling job. |
| `slack_channel_id` | `C04DS0SG599` | Slack channel. |
| `success_text`, `failure_text`, `skipped_text` | "all tests passed ✅", … | Status wording. |
