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

## Usage

Pin to a commit SHA:

```yaml
- uses: 0xPolygon/kurtosis-workflows/.github/actions/setup-kurtosis@<sha>
  with:
    kurtosis_version: 1.23.0
```
