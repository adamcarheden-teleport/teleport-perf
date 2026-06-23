#!/bin/bash
set -euo pipefail
declare -r EXIT_COMPLETE=0
declare -r EXIT_STARTED=1
declare -r EXIT_RUNNING=2
declare -r EXIT_FAILED=125
declare -r EXIT_DIE=124

### Utilit functions #########################################################
msg() {
  printf >&2 "\n\n-= %s =-\n\n" "${*}"
}
die() {
  msg "ERROR: ${*}"
  exit "${EXIT_DIE}"
}
###############################################################################

### Poor man's autocomplete ###################################################
usage() {
  local self="$(basename "$0")"
  printf >&2 "%s\n\n%s\n" \
  "$(cat <<EOT
Usage:
   ${self} <cluster> <job>
   or
   ${self} config/<cluster.<job>
  (so you can \`touch config/<cluster>.<job>\` to get autocomplete)

EOT
)" \
  "ERROR: ${*}"
  exit "${EXIT_DIE}"
}
declare CLUSTER="${CLUSTER:-}"
declare JOB_NAME="${JOB_NAME:-}"
case "${#}" in
  1)
    arg1_regex='^config/[^.]+\.[^.]+$'
    [[ "${1:-}" =~ ${arg1_regex} ]] || usage "Wrong format for first arg"
    IFS="." read -r CLUSTER JOB_NAME <<<"${1#config/}"
    ;;
  2)
    CLUSTER="${CLUSTER:-${1}}"
    JOB_NAME="${JOB_NAME:-${2}}"
    ;;
  *)
    usage "Wrong number of arguments"
esac
###############################################################################

### Job-Agnostic vars #########################################################
declare -r ROOT_D="$(readlink -f "$(dirname "${BASH_SOURCE}")/..")"
declare -r CLUSTER_D="${ROOT_D}/cluster-config"
declare -r JOB_D="${ROOT_D}/test-config"
declare -r RESULTS_D="${ROOT_D}/results"
declare -r DEFAULTS_YAML="${ROOT_D}/values.yaml"
declare DEBUG="${DEBUG:-}" # Not r/o so we can set it in subshells
declare -r FORCE="${FORCE:-}"
###############################################################################

### Job-specific vars #########################################################

# Input paths
declare -r CLUSTER_YAML="${CLUSTER_D}/${CLUSTER}.yaml"
declare -r JOB_YAML="${JOB_D}/${JOB_NAME}.yaml"
[[ -r "${CLUSTER_YAML}" ]] || die "Cluster params '${CLUSTER_YAML}' not found"
[[ -r "${JOB_YAML}" ]] || die "Job params '${JOB_YAML}' not found"

# Output paths
declare -r JOB_RESULTS_D="${RESULTS_D}/${CLUSTER}.${JOB_NAME}"
declare -r RESULTS_TSV="${JOB_RESULTS_D}/${JOB_NAME}.tsv"
declare -r STATUS_YAML="${JOB_RESULTS_D}/${JOB_NAME}.status.yaml"
mkdir -p "${JOB_RESULTS_D}" || die "Failed to mkdir '${JOB_RESULTS_D}'"

# Config name derivitives
declare -r NAME="${CLUSTER}-${JOB_NAME}"
declare -r RELEASE="${NAME}"
declare -r GROUP="${NAME}"
declare -r TOKEN="${NAME}-bot"
declare -r K8S_JOB_NAME="${RELEASE}-test-runner"
declare -r K8S_COMMON_LABELS="app.kubernetes.io/name=tperf,app.kubernetes.io/instance=${RELEASE}"
declare -r K8S_RUNNER_LABELS="${K8S_COMMON_LABELS},app.kubernetes.io/component=test-runner"
declare -r K8S_TARGET_LABELS="${K8S_COMMON_LABELS},app.kubernetes.io/component=target"
declare -r YQ_CLUSTER='.tbot.services[0].selectors[0].name'
# Config value derivitives
K8S_CLUSTER_TELEPORT_NAME="$(yq -e <"${CLUSTER_YAML}" "${YQ_CLUSTER}")" \
  || die "Failed to get k8s cluster Teleport name. '${CLUSTER_YAML}' must have '${YQ_CLUSTER}'. This must be the name of the k8s cluster in Teleport."
declare -r YQ_TELEPORT='.tbot.clusterName'
TELEPORT_CLUSTER_NAME="$(yq -e <"${CLUSTER_YAML}" "${YQ_TELEPORT}")" \
  || die "Failed to get Teleport cluster name. '${CLUSTER_YAML}' must have '${YQ_TELEPORT}'. This must be the name of the Teleport cluster."
declare -r YQ_NAMESPACE='.tbot.services[0].destination.namespace'
NAMESPACE="$(yq -e <"${CLUSTER_YAML}" "${YQ_NAMESPACE}")" \
  || die "Failed to get namespace. '${CLUSTER_YAML}' must have '${YQ_NAMESPACE}'. This must be name this benchmark will run in."
declare -r CONTEXT="${TELEPORT_CLUSTER_NAME}-${K8S_CLUSTER_TELEPORT_NAME}"
tsh --proxy="${TELEPORT_CLUSTER_NAME}" kube login "${K8S_CLUSTER_TELEPORT_NAME}" \
  || die "Failed to log in to k8s cluster '${K8S_CLUSTER_TELEPORT_NAME}' through Teleport proxy '${TELEPORT_CLUSTER_NAME}'"
declare -a KUBE_CONTEXTS=( $(kubectl config get-contexts -o name) )
[[ -n "${DEBUG}" && "$(echo "${DEBUG}" | tr 'a-z' 'A-Z')" != "false" ]] \
  && printf >&2 'kubectl contexts:\n%s\n' "${KUBE_CONTEXTS[@]}"
printf '%s\n' "${KUBE_CONTEXTS[@]}" | grep -Fxq "${CONTEXT}" \
  || die "kubectl context '${CONTEXT}' not found after tsh kube login"
declare -r YQ_REPLICAS='.replicas'
REPLICAS="$(cat "${JOB_YAML}" | yq -e "${YQ_REPLICAS}")" \
  || REPLICAS="$(cat "${DEFAULTS_YAML}" | yq -e "${YQ_REPLICAS}")" \
  || die "Failed to get replicas. Please set '${YQ_REPLICAS}' in '${JOB_YAML}' or '${DEFAULTS_YAML}'"
###############################################################################


run_kubectl() {
  (debug && set -x; kubectl --context "${CONTEXT}" --namespace "${NAMESPACE}" "${@}")
}

force() {
  [[ -n "${FORCE}" && "(echo "${FORCE}" |tr 'A-Z' 'a-z')" != "false" ]]
}
debug() {
  [[ -n "${DEBUG}" && "(echo "${DEBUG}" |tr 'A-Z' 'a-z')" != "false" ]]
}

started() {
  debug && msg "checking if started"
  run_kubectl >/dev/null 2>/dev/null get "job/${K8S_JOB_NAME}" || return 1
}
has_condition() {
  local condition="${1:-}"
  local timeout="${2:-0}"
  debug && msg "checking for condition '${condition}'..."
  [[ -n "${condition}" ]] || die "no condition provided"
  started || return 1
  run_kubectl 2>/dev/null >/dev/null wait "--for=condition=${condition}" \
    "job/${K8S_JOB_NAME}" --timeout="${timeout}s" || return 1
}
complete() {
  has_condition "Complete" || return 1
}
succeeded() {
  has_condition "SuccessCriteriaMet" || return 1
}
failed() {
  has_condition "Failed" || return 1
}
running() {
  started && ! complete && ! failed
}

have_saved_results() {
  [[ -f "${RESULTS_TSV}" ]]
}

report_saved_results() {
  have_saved_results || die "Saved results '${RESULTS_TSV}' not found"
  "${ROOT_D}/bin/report" "${RESULTS_TSV}"
}
