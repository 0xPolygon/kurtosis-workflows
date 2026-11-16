# Kurtosis Workflows

Shared GitHub Actions and reusable workflows for the Kurtosis repositories
([kurtosis-cdk](https://github.com/0xPolygon/kurtosis-cdk),
[kurtosis-pos](https://github.com/0xPolygon/kurtosis-pos),
[optimism-package](https://github.com/agglayer/optimism-package)).

This repository must not contain secrets. Credentials and environment-specific identifiers (GCP
workload identity provider, service account, Slack channel) stay in the calling repository and are
passed as inputs.

## Actions

| Action | Description |
| --- | --- |
| [`setup-kurtosis`](.github/actions/setup-kurtosis/action.yml) | Install the Kurtosis CLI and write its CI configuration. |
| [`pull-images`](.github/actions/pull-images/action.yml) | Pre-pull Docker images in parallel with bounded retries, optionally from a registry mirror. |

## Workflows

| Workflow | Description |
| --- | --- |
| [`version-matrix`](.github/workflows/version-matrix.yml) | Check the version matrix, open or refresh a bump PR with Claude, post the outcome to Slack. |

## Usage

Pin to a commit SHA.

### setup-kurtosis

```yaml
- uses: 0xPolygon/kurtosis-workflows/.github/actions/setup-kurtosis@<sha>
  with:
    kurtosis_version: 1.23.0
```

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
- uses: 0xPolygon/kurtosis-workflows/.github/actions/pull-images@<sha>
  with:
    images_file: modified-images.txt

# Images pulled from the mirror and tagged back as listed.
- uses: 0xPolygon/kurtosis-workflows/.github/actions/pull-images@<sha>
  with:
    registry_prefix: europe-west2-docker.pkg.dev/<project>/<repository>
    images: |
      kurtosistech/engine:1.23.0
      kurtosistech/core:1.23.0
```

Other inputs: `attempts` (3), `retry_delay` in seconds (5), `parallelism` (8) and
`skip_present` (false, skips images already loaded, e.g. from a cache).

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
    uses: 0xPolygon/kurtosis-workflows/.github/workflows/version-matrix.yml@<sha>
    with:
      label: Kurtosis PoS version matrix
      notify: ${{ github.event_name == 'schedule' || inputs.notify }}
      slack_channel_id: <channel id>
      kurtosis_version: 1.23.0
    secrets:
      claude_api_key: ${{ secrets.CLAUDE_API_KEY }}
      app_id: ${{ secrets.SEMANTIC_RELEASE_BOT_APP_ID }}
      app_private_key: ${{ secrets.SEMANTIC_RELEASE_BOT_APP_PRIVATE_KEY }}
      slack_bot_token: ${{ secrets.SLACK_BOT_TOKEN }}
```

The Slack message reads `<label>: up to date ✅`, `<label>: outdated ❌, bump PR opened: #123`,
and so on, the label linking to the run.

| Input | Default | Description |
| --- | --- | --- |
| `label` | (required) | Name of the matrix in the Slack message. |
| `notify` | `false` | Post the outcome to Slack. |
| `slack_channel_id` | `""` | Slack channel, required when `notify` is true. |
| `scripts_dir` | `scripts/version-matrix` | Directory of the version matrix scripts. |
| `python_version` | `3.13` | Python version used to run them. |
| `check_timeout_minutes` | `10` | Timeout of the check job. |
| `skill_path` | `.claude/skills/update-version-matrix/SKILL.md` | Skill Claude follows to bump the pins. |
| `kurtosis_version` | `""` | Kurtosis CLI installed for the bump job, empty to skip. |
| `kurtosis_test_version` | `""` | kurtosis-test release installed for the bump job, empty to skip. |
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
