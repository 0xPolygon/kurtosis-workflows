#!/usr/bin/env bash
# Fails when an image the Kurtosis engine or ethereum-package pulls at a pinned version is not the
# one listed in pull-kurtosis-images: a stale pre-pull is silently useless, the engine just pulls
# the right image itself (and hits the Docker Hub rate limit).
set -euo pipefail

root="${GITHUB_WORKSPACE:-.}"
action_dir="${GITHUB_ACTION_PATH}/.."
images="${action_dir}/pull-kurtosis-images/images.txt"
status=0

# check_listed <label> <upstream file url> <regex matching the image in that file>
check_listed() {
  local label="$1" url="$2" pattern="$3" content expected listed
  if ! content=$(curl -fsSL --retry 3 "${url}"); then
    echo "::warning title=verify-images::Could not fetch ${url}, skipping the ${label} check."
    return 0
  fi
  expected=$(grep -oE "${pattern}" <<< "${content}" | head -n 1 || true)
  if [[ -z "${expected}" ]]; then
    echo "::warning title=verify-images::No ${label} image found in ${url}."
    return 0
  fi
  if grep -qxF "${expected}" "${images}"; then
    echo "${label}: ${expected} is listed."
  else
    listed=$(grep -F "${expected%%:*}" "${images}" || echo "none")
    echo "::error title=verify-images::${label} uses ${expected} but pull-kurtosis-images lists ${listed}. Bump images.txt in kurtosis-workflows and this repository's reference to it."
    status=1
  fi
}

# The engine images are the ones of the Kurtosis version setup-kurtosis installs by default.
version=$(grep -oE 'INPUT_VERSION:-[0-9.]+' "${action_dir}/setup-kurtosis/action.yml" | cut -d- -f2)
version=${version#-}
backend="https://raw.githubusercontent.com/kurtosis-tech/kurtosis/${version}/container-engine-lib/lib/backend_impls/docker/docker_kurtosis_backend"
check_listed "kurtosis ${version} vector" "${backend}/logs_aggregator_functions/implementations/vector/consts.go" 'timberio/vector:[^"[:space:]]+'
check_listed "kurtosis ${version} traefik" "${backend}/reverse_proxy_functions/implementations/traefik/consts.go" 'traefik:[^"[:space:]]+'
check_listed "kurtosis ${version} alpine" "${backend}/logs_collector_functions/implementations/fluentbit/fluentbit_configuration_creator.go" 'alpine:[^"[:space:]]+'

commit=$(sed -nE 's#^[[:space:]]*github\.com/ethpandaops/ethereum-package:[[:space:]]*github\.com/ethpandaops/ethereum-package@([0-9a-f]{40}).*#\1#p' "${root}/kurtosis.yml")
if [[ -n "${commit}" ]]; then
  constants="https://raw.githubusercontent.com/ethpandaops/ethereum-package/${commit}/src/package_io/constants.star"
  check_listed "ethereum-package ${commit:0:12} genesis generator" "${constants}" 'ethpandaops/ethereum-genesis-generator:[^"[:space:]]+'
else
  echo "No ethereum-package pin in kurtosis.yml, skipping the genesis generator check."
fi
exit "${status}"
