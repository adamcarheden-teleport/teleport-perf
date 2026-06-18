#!/bin/bash
set -euo pipefail

# Cluster to run on
declare -r K8S_CLUSTER_KUBECTL_CONTEXT="${1:-${K8S_CLUSTER_KUBECTL_CONTEXT:-}}"

# Teleport Objects
declare -r BOT="${BOT:-my-bot}"
declare -r ROLE="${ROLE:-my-role}"
declare -r TOKEN="${TOKEN:-my-token}"
# Kubernetes Objects
declare -r K8S_GROUP="${K8S_GROUP:-my-group}"
declare -r K8S_NAMESPACE="${K8S_NAMESPACE:-my-namespace}"
declare -r K8S_SA="${K8S_SA:-my-sa}"

declare -r DEBUG="${DEBUG:-}"
declare -r OVERWRITE=''
die() {
  echo >&2 "ERROR: ${*}"
  exit 1
}

[[ -n "${K8S_CLUSTER_KUBECTL_CONTEXT}" ]] \
  || die "Please supply a kubectl context for the k8s cluster the bot will run on as either the first argument or the K8S_CLUSTER_KUBECTL_CONTEXT envvar (got '${K8S_CLUSTER_KUBECTL_CONTEXT}')"
kubectl config get-contexts -o name \
  | grep -Fxq "${K8S_CLUSTER_KUBECTL_CONTEXT}" \
  || die "'${K8S_CLUSTER_KUBECTL_CONTEXT}' is not configured as a kubectl context"

OIDC_ISSUER="$(
  kubectl --context "${K8S_CLUSTER_KUBECTL_CONTEXT}" \
    get --raw /.well-known/openid-configuration \
    | yq -r '.issuer'
  )" || die "Failed to discover OIDC issuer for context '${K8S_CLUSTER_KUBECTL_CONTEXT}'"


for f in $(dirname "${BASH_SOURCE}")/*.yaml; do
  kind="$(basename "${f}" .yaml)"
  name_ref="$(echo "${kind}" | tr 'a-z' 'A-Z')"
  name="${!name_ref}"
  [[ -z "${OVERWRITE}" ]] \
    && tctl get "${kind}/${name}" >/dev/null \
    && echo >&2 "${kind}/${name} already exists in Teleport, skipping creation." \
    && continue
  cat "${f}" \
    | sed \
      -e "s~__BOT__~${BOT}~g" \
      -e "s~__ROLE__~${ROLE}~g" \
      -e "s~__TOKEN__~${TOKEN}~g" \
      -e "s~__K8S_GROUP__~${K8S_GROUP}~g" \
      -e "s~__K8S_NAMESPACE__~${K8S_NAMESPACE}~g" \
      -e "s~__K8S_SA__~${K8S_SA}~g" \
      -e "s~__OIDC_ISSUER__~${OIDC_ISSUER}~g" \
  | ([[ -n "${DEBUG}" ]] && cat - || tctl create -f -) \
  || die "Failed to apply ${f}"
done