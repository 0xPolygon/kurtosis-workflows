#!/usr/bin/env bash
# Fails when the ethereum-genesis-generator image listed in pull-kurtosis-images is not the one the
# ethereum-package commit pinned in kurtosis.yml uses: a stale pre-pull is silently useless, the
# engine just pulls the right image itself.
set -euo pipefail

root="${GITHUB_WORKSPACE:-.}"
images="${GITHUB_ACTION_PATH}/../pull-kurtosis-images/images.txt"

commit=$(sed -nE 's#^[[:space:]]*github\.com/ethpandaops/ethereum-package:[[:space:]]*github\.com/ethpandaops/ethereum-package@([0-9a-f]{40}).*#\1#p' "${root}/kurtosis.yml")
if [[ -z "${commit}" ]]; then
  echo "No ethereum-package pin in kurtosis.yml, skipping the pre-pull image check."
  exit 0
fi

url="https://raw.githubusercontent.com/ethpandaops/ethereum-package/${commit}/src/package_io/constants.star"
if ! constants=$(curl -fsSL --retry 3 "${url}"); then
  echo "::warning title=check-pull-images::Could not fetch ${url}, skipping the pre-pull image check."
  exit 0
fi

expected=$(grep -oE 'ethpandaops/ethereum-genesis-generator:[^"[:space:]]+' <<< "${constants}" | head -n 1 || true)
if [[ -z "${expected}" ]]; then
  echo "::warning title=check-pull-images::No ethereum-genesis-generator image found in ${url}."
  exit 0
fi

if ! grep -qxF "${expected}" "${images}"; then
  listed=$(grep 'ethereum-genesis-generator' "${images}" || echo "none")
  echo "::error title=check-pull-images::ethereum-package ${commit:0:12} uses ${expected} but pull-kurtosis-images lists ${listed}. Bump images.txt in kurtosis-workflows and this repository's reference to it."
  exit 1
fi
echo "ethereum-genesis-generator ${expected} matches ethereum-package ${commit:0:12}."
