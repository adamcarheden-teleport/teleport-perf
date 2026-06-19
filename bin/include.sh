#!/bin/bash
set -euo pipefail

declare -r ROOT_D="$(readlink -f "$(dirname "${BASH_SOURCE}")/..")"
declare -r CLUSTER_D="${ROOT_D}/cluster-config"
declare -r JOB_D="${ROOT_D}/test-config"
declare -r RESULTS_D="${ROOT_D}/results"

declare -r CLUSTER="${CLUSTER:-${1:-example}}"
declare -r JOB_NAME="${JOB_NAME:-${2:-example}}"
declare -r CLUSTER_YAML="${CLUSTER_D}/${CLUSTER}.yaml"
declare -r JOB_YAML="${JOB_D}/${JOB_NAME}.yaml"
declare -r RESULTS_TSV="${RESULTS_D}/${JOB_NAME}.tsv"

# TODO: Get these from config
declare -r CONTEXT="c-westus2-aks"
declare -r NAME="tperf"
declare -r RELEASE="${NAME}-test"
declare -r NAMESPACE="teleport-performance"
declare -r GROUP="${NAME}"
declare -r TOKEN="${NAME}-bot"

msg() {
  printf >&2 "%s\n" "${*}"
}
die() {
  msg "ERROR: ${*}"
  exit 1
}

[[ -r "${CLUSTER_YAML}" ]] || die "Cluster params '${CLUSTER_YAML}' not found"
[[ -r "${JOB_YAML}" ]] || die "Job params '${JOB_YAML}' not found"
mkdir -p "${RESULTS_D}" || die "Failed to mkdir '${RESULTS_D}'"

run_kubectl() {
  (set -x; kubectl --context "${CONTEXT}" --namespace "${NAMESPACE}" "${@}")
}