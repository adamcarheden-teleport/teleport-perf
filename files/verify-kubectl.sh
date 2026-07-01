#!/usr/bin/env bash

TELEPORT_KUBECONFIG="/opt/machine-k8s/kubeconfig.yaml"

msg() {
  printf >&2 "\n%s\n\n" "${*}"
}
die() {
  msg "ERROR: ${*}"
  exit 1
}

test -r "${TELEPORT_KUBECONFIG}" \
  || die "Teleport kubeconfig '${TELEPORT_KUBECONFIG}' missing or unreadable"

if [ "$(kubectl config current-context 2>&1)" != "error: current-context is not set" ]; then
  die "Default kubectl has a context set. It shouldn't. Is KUBECONFIG set to Teleport's kubeconfig?"
else
  msg "Default kubeconfig has no context set, as expected"
fi

TP_CONTEXT="$(kubectl --kubeconfig="${TELEPORT_KUBECONFIG}" config current-context)" \
  || die "Teleport's kubeconfig '${TELEPORT_KUBECONFIG}' has no default context. Did you configure a cluster in tbot?"
test -z "${TELEPORT_PROXY:-}" \
  && die "TELEPORT_PROXY not set. We need this to know what context to look for."
prefix="${TELEPORT_PROXY%:*}-"
if echo "${TP_CONTEXT}" | grep -q "^${prefix}"; then
  msg "Teleport's kubeconfig '${TELEPORT_KUBECONFIG}' has a context set that starts with the proxy name '${prefix}', as expected."
else 
  msg "Teleport's kubeconfig '${TELEPORT_KUBECONFIG}' has a context that doesn't start with the proxy name '${prefix}'. Something's wrong."
fi

POD="$(hostname)"

if kubectl                                       exec "${POD}" -c test-runner -- hostname; then
  msg "SUCCESS: ran command on this pod with kubectl exec WITHOUT Teleport"
else
  msg "ERROR: Failed to run exec on this pod WITHOUT Teleport."
fi

if kubectl --kubeconfig="${TELEPORT_KUBECONFIG}" exec "${POD}" -c test-runner -- hostname; then
  msg "SUCCESS: ran command on this pod with kubectl exec WITH Teleport"
else
  msg "ERROR: Failed to run exec on this pod WITH Teleport."
fi
