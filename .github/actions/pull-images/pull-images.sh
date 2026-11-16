#!/usr/bin/env bash
# Pulls the images listed in $IMAGES and $IMAGES_FILE, see action.yml for the inputs.
set -euo pipefail

for name in ATTEMPTS RETRY_DELAY PARALLELISM; do
  if [[ ! "${!name}" =~ ^[1-9][0-9]*$ ]]; then
    echo "::error title=pull-images::${name,,} must be a positive integer, got '${!name}'"
    exit 1
  fi
done
if [[ "${SKIP_PRESENT}" != true && "${SKIP_PRESENT}" != false ]]; then
  echo "::error title=pull-images::skip_present must be true or false, got '${SKIP_PRESENT}'"
  exit 1
fi

images=()
add_images() {
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    if [[ -n "${line}" && "${line}" != \#* ]]; then
      images+=("${line}")
    fi
  done
}
# shellcheck disable=SC2153 # IMAGES comes from the action inputs.
add_images <<< "${IMAGES}"
if [[ -n "${IMAGES_FILE}" ]]; then
  if [[ ! -f "${IMAGES_FILE}" ]]; then
    echo "::error title=pull-images::images_file not found: ${IMAGES_FILE}"
    exit 1
  fi
  add_images < "${IMAGES_FILE}"
fi
if ((${#images[@]} == 0)); then
  echo "::warning title=pull-images::No image to pull."
  exit 0
fi

# Registry mirrors (e.g. an Artifact Registry remote repository) intermittently 404 a layer blob
# that exists upstream, which would fail the whole job; a later attempt usually succeeds.
pull_one() {
  local image="$1" source attempt
  source="${REGISTRY_PREFIX:+${REGISTRY_PREFIX%/}/}${image}"
  if [[ "${SKIP_PRESENT}" == true ]] && docker image inspect "${source}" > /dev/null 2>&1; then
    echo "Already present, skipping pull: ${source}"
  else
    for ((attempt = 1; ; attempt++)); do
      docker pull "${source}" && break
      echo "::warning::docker pull ${source} failed (attempt ${attempt}/${ATTEMPTS})"
      if ((attempt >= ATTEMPTS)); then
        echo "::error::docker pull ${source} failed after ${ATTEMPTS} attempts"
        return 1
      fi
      sleep "${RETRY_DELAY}"
    done
  fi
  if [[ -n "${REGISTRY_PREFIX}" && "${image}" != *@sha256:* ]]; then
    docker tag "${source}" "${image}"
  fi
}
export -f pull_one
export REGISTRY_PREFIX ATTEMPTS RETRY_DELAY SKIP_PRESENT

# xargs exits non-zero (123) when any pull runs out of attempts, so the step fails instead of
# silently dropping that image.
# shellcheck disable=SC2016 # $1 is expanded by the child shell.
printf '%s\n' "${images[@]}" | xargs -r -d '\n' -n 1 -P "${PARALLELISM}" bash -c 'pull_one "$1"' _
