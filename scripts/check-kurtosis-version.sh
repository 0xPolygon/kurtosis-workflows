#!/usr/bin/env bash
# The default Kurtosis version is written in the setup-kurtosis action, lint.yml and
# version-matrix.yml, and the default kurtosis-test version in unit.yml and version-matrix.yml:
# fail when they diverge.
set -euo pipefail

default_of() {
  awk -v input="$2" '$0 ~ "^      " input ":"{f=1} f&&/default:/{print $2; exit}' ".github/workflows/$1.yml"
}

setup=$(grep -oE 'INPUT_VERSION:-[0-9.]+' .github/actions/setup-kurtosis/action.yml | cut -d- -f2)
setup=${setup#-}
for workflow in lint version-matrix; do
  version=$(default_of "${workflow}" kurtosis_version)
  if [[ "${version}" != "${setup}" ]]; then
    echo "::error::${workflow}.yml defaults kurtosis_version to '${version}', setup-kurtosis to '${setup}'"
    exit 1
  fi
done

unit=$(default_of unit kurtosis_test_version)
matrix=$(default_of version-matrix kurtosis_test_version)
if [[ "${unit}" != "${matrix}" ]]; then
  echo "::error::unit.yml defaults kurtosis_test_version to '${unit}', version-matrix.yml to '${matrix}'"
  exit 1
fi
echo "Kurtosis default version: ${setup}, kurtosis-test: ${unit}"
