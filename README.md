# Teleport Kubernetes Performance Test

This repo is a framework for comparing performance of commands run through
Teleport with similar commands run without Teleport. At present, it covers only
Kubernetes commands in two flavors:

- kubectl get - Represents standard k8s API calls
- kubectl exec - Represents streaming k8s API calls

In the future it may or may not also cover k8s port-forward and watch API calls
and non-k8s applications like ssh or https proxying.

## How?

Tests create a k8s StatefulSet as the target of all k8s commands. They then
start k8s Jobs that run kubectl commands targeting the StatefulSet's pods.
Identical commands are run with different kubectl contexts to direct traffic
through Teleport or not through Teleport.

Helm is used to deploy the k8s objects. `tsh` is used to provision the necessary
Teleport objects. Results are temporarily saved to a volume and collected to
your local disk when all jobs are complete. A reporting script summarizes the
resulting data with and without Teleport, showing the deltas. Set `HIST=true`
when running `bin/report` to include histograms.

## Prerequisites

- A Teleport cluster with:
  - Access to create roles, bots, and tokens
  - `tsh` / Teleport client tools installed locally
- A Kubernetes cluster joined to Teleport
- `kubectl` installed locally
- `helm` installed locally
- `yq` installed locally

## Configuration

This repo is a Helm chart. All configuration is done through the Helm values
described in `values.yaml`. However, the `bin/run*` scripts run Helm for you and
take as input one file from each of the directories below:

- `cluster-config/` - Values files with the `tbot` branch of this chart's values
- `test-config/` - Values files with the non-`tbot` branch of this chart's
  values

This lets you configure test parameters and k8s clusters to test against
independently, so you can mix and match.

## Usage

Create cluster files in `cluster-config/<cluster>.yaml` and test files in
`test-config/<test>.yaml`. Start from
[`cluster-config/example.yaml`](/Users/adamcarheden/src/tperf/cluster-config/example.yaml:1)
and
[`test-config/example-ls.yaml`](/Users/adamcarheden/src/tperf/test-config/example-ls.yaml:1).

### Run one test

```
bin/run <cluster> <test>
```

This just starts the job and exits. Run it again until you see the test has
completed. It will either tell you it's still running or download the results
from your k8s cluster if the Job is finished.

Results are archived in `results/`. You can view them either by re-running
`bin/run` or running `bin/report results/<cluster>.<test>/<test>.tsv`.

### Create test cases

```
bin/generate-test-cases cluster-config/my-cluster.yaml
```

Set environment variables before running the script to change which test cases
are generated. For example, `REPLICAS_LIST` and `ITERATIONS` control the
generated matrix.

> [!WARNING] The test spins up 2 pods per replica (a test runner and a target).
> Be careful not to exhaust your k8s IP space, especially on cloud clusters that
> use vpc-native / non-overlay networking.

### Create "auto-complete" files for convenience

In addition to accepting `<cluster>` and `<test>` as parameters, `bin/run` will
**also** accept `config/<cluster>.<test>`. This is so you can create such files
and use your shell's auto-complete to target that test run. The files aren't
read, so their content is irrelevant -- they're just there as a poor man's
auto-complete (because I'm too lazy to write a real one and you don't want to
source that from your dotfiles anyway). However, feel free to dump notes about
each test run in those files.

Once you have your clusters and test cases defined, you can create those files
like so:

```
bin/make-autocomplete cluster-config/my-cluster.yaml
```

### Run all test cases for a cluster

```
bin/run-cases cluster-config/<cluster>.yaml
```

This will run each test case in turn (serially), poll until it's done and
download the results.

Consider running it in `screen` or `tmux`, and using `caffeinate` or similar to
keep your local workstation from sleeping. However, it will pick up where it
left off if it does die or is interrupted.

## Further Reading

- [Machine & Workload Identity with Kubernetes Access](https://goteleport.com/docs/machine-workload-identity/access-guides/kubernetes/)
- [Deploying tbot on Kubernetes](https://goteleport.com/docs/machine-workload-identity/deployment/kubernetes/)
- [Machine & Workload Identity Configuration Reference](https://goteleport.com/docs/reference/machine-workload-identity/configuration/)
- [tbot helm chart](https://github.com/gravitational/teleport/tree/master/examples/chart/tbot)
