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
declare -r STATUS_YAML="${RESULTS_D}/${JOB_NAME}.status.yaml"

declare DEBUG="${DEBUG:-}" # Not r/o so we can set it in subshells
declare -r FORCE="${FORCE:-}"

# TODO: Get these from config
declare -r CONTEXT="c-westus2-aks"
declare -r NAME="tperf"
declare -r RELEASE="${NAME}-test"
declare -r NAMESPACE="teleport-performance"
declare -r GROUP="${NAME}"
declare -r TOKEN="${NAME}-bot"
declare -r K8S_JOB_NAME="${RELEASE}-test-runner"
declare -r K8S_COMMON_LABELS="app.kubernetes.io/name=tperf,app.kubernetes.io/instance=${RELEASE}"
declare -r K8S_RUNNER_LABELS="${K8S_COMMON_LABELS},app.kubernetes.io/component=test-runner"
declare -r K8S_TARGET_LABELS="${K8S_COMMON_LABELS},app.kubernetes.io/component=target"


declare -r REPLICAS="$(cat "${JOB_YAML}" | yq -e .replicas)" \
  || die "Failed to get replicas"

msg() {
  printf >&2 "\n\n-= %s =-\n\n" "${*}"
}
die() {
  msg "ERROR: ${*}"
  exit 1
}

[[ -r "${CLUSTER_YAML}" ]] || die "Cluster params '${CLUSTER_YAML}' not found"
[[ -r "${JOB_YAML}" ]] || die "Job params '${JOB_YAML}' not found"
mkdir -p "${RESULTS_D}" || die "Failed to mkdir '${RESULTS_D}'"

run_kubectl() {
  ([[ -n "$DEBUG" ]] && set -x; kubectl --context "${CONTEXT}" --namespace "${NAMESPACE}" "${@}")
}

force() {
  [[ -n "${FORCE}" && "(echo "${FORCE}" |tr 'A-Z' 'a-z')" != "false" ]]
}

started() {
  run_kubectl 2>/dev/null >/dev/null get "job/${K8S_JOB_NAME}"
}
has_condition() {
  local condition="${1:-}"
  local timeout="${2:-0}"
  [[ -n "${condition}" ]] || die "no condition provided"
  started || return 1
  run_kubectl >/dev/null 2>/dev/null wait "--for=condition=${condition}" \
    "job/${K8S_JOB_NAME}" --timeout="${timeout}s"
}
complete() {
  has_condition "Complete"
}
succeeded() {
  has_condition "SuccessCriteriaMet"
}
failed() {
  has_condition "Failed"
}
running() {
  started && ! complete && ! failed
}