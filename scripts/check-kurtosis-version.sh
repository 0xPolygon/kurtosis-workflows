#!/usr/bin/env bash
# The default Kurtosis version is written in the setup-kurtosis action, lint.yml and
# version-matrix.yml: fail when they diverge.
set -euo pipefail

setup=$(grep -oE 'INPUT_VERSION:-[0-9.]+' .github/actions/setup-kurtosis/action.yml | cut -d- -f2)
setup=${setup#-}
for workflow in lint version-matrix; do
  version=$(awk '/^      kurtosis_version:/{f=1} f&&/default:/{print $2; exit}' ".github/workflows/${workflow}.yml")
  if [[ "${version}" != "${setup}" ]]; then
    echo "::error::${workflow}.yml defaults kurtosis_version to '${version}', setup-kurtosis to '${setup}'"
    exit 1
  fi
done
echo "Kurtosis default version: ${setup}"
