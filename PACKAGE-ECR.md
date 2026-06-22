# Build, Package & Publish Helm Charts to AWS ECR

This document describes how the CloudNativePG Helm charts in this repository are
packaged and pushed to an [AWS ECR](https://aws.amazon.com/ecr/) OCI registry,
both locally and through CI.

## Charts

| Chart source dir        | Published name (ECR repo)  | Tag prefix         |
|-------------------------|----------------------------|--------------------|
| `charts/cloudnative-pg` | `cloudnativepg-operator`   | `cnpg-operator-`   |
| `charts/cluster`        | `cloudnativepg-cluster`    | `cnpg-cluster-`    |

> The published chart name comes from the `name:` field in each chart's
> `Chart.yaml`, **not** from the directory name. The ECR repository name must
> match this published name. To keep rendered Kubernetes resource names stable
> after renaming, `nameOverride` is pinned to the original chart name in each
> chart's `values.yaml` (`cloudnative-pg` / `cluster`).

## Prerequisites

- [`helm`](https://helm.sh/) `3.16.4` available on the `PATH` as `helm3.16.4`
- [`aws` CLI](https://docs.aws.amazon.com/cli/) v2, authenticated with permission
  to push to ECR (`ecr:GetAuthorizationToken`, `ecr:DescribeRepositories`,
  `ecr:CreateRepository`, and push/pull actions)
- The following environment variables:

| Variable             | Description                                              | Example                                             |
|----------------------|----------------------------------------------------------|-----------------------------------------------------|
| `ECR_HOST`           | ECR registry host (account-specific)                     | `123456789012.dkr.ecr.us-east-1.amazonaws.com`      |
| `AWS_ECR_REGION`     | AWS region of the registry                               | `us-east-1`                                         |
| `AWS_DEFAULT_REGION` | Defaults to `AWS_ECR_REGION` if unset                    | `us-east-1`                                         |
| `VERSION` / `TAG`    | Chart version to publish (`VERSION` defaults to `TAG`)   | `0.28.3`                                            |

## Build & push locally

The `push-oci-chart` Makefile target logs in to ECR, builds chart dependencies,
packages the chart, creates the ECR repository if needed, pushes the chart, and
logs out.

```bash
# Operator chart
make push-oci-chart \
  DIR=cloudnative-pg \
  NAME=cloudnativepg-operator \
  VERSION=0.28.3 \
  ECR_HOST=123456789012.dkr.ecr.us-east-1.amazonaws.com \
  AWS_ECR_REGION=us-east-1

# Cluster chart
make push-oci-chart \
  DIR=cluster \
  NAME=cloudnativepg-cluster \
  VERSION=0.7.0 \
  ECR_HOST=123456789012.dkr.ecr.us-east-1.amazonaws.com \
  AWS_ECR_REGION=us-east-1
```

The chart is published to `oci://$ECR_HOST/<NAME>:<VERSION>`, e.g.
`oci://123456789012.dkr.ecr.us-east-1.amazonaws.com/cloudnativepg-operator:0.28.3`.

### Make targets

| Target           | Purpose                                                              |
|------------------|----------------------------------------------------------------------|
| `push-oci-chart` | Package and push a chart to ECR. Requires `DIR` and `NAME`.          |
| `ecr-login`      | Log in to the ECR OCI registry with Helm.                            |
| `ecr-logout`     | Log out of the ECR OCI registry.                                     |

### Do it manually (what the target runs)

```bash
# 1. Log in
aws ecr get-login-password --region "$AWS_ECR_REGION" \
  | helm3.16.4 registry login "$ECR_HOST" --username AWS --password-stdin

# 2. Build dependencies (operator chart has a remote dependency)
helm3.16.4 dependency build charts/cloudnative-pg/

# 3. Package
helm3.16.4 package charts/cloudnative-pg/ --version 0.28.3
# -> produces cloudnativepg-operator-0.28.3.tgz

# 4. Ensure the repository exists
aws ecr describe-repositories --repository-names cloudnativepg-operator \
  || aws ecr create-repository --repository-name cloudnativepg-operator --region "$AWS_ECR_REGION"

# 5. Push
helm3.16.4 push cloudnativepg-operator-0.28.3.tgz "oci://$ECR_HOST"

# 6. Log out
helm3.16.4 registry logout "$ECR_HOST"
```

## Publish via CI (GitHub Actions)

Pushing a git tag triggers the
[`push-ecr-cnpg.yml`](.github/workflows/push-ecr-cnpg.yml) workflow. Each chart
has its own job, selected by the tag prefix.

Tag format:

```
<prefix>-<semver-version>
```

| Tag example             | Chart published          | Resulting reference                                  |
|-------------------------|--------------------------|------------------------------------------------------|
| `cnpg-operator-0.28.3`  | `cloudnativepg-operator` | `oci://$ECR_HOST/cloudnativepg-operator:0.28.3`      |
| `cnpg-cluster-0.7.0`    | `cloudnativepg-cluster`  | `oci://$ECR_HOST/cloudnativepg-cluster:0.7.0`        |

The version is the tag with its prefix stripped, so it must be valid SemVer and
should match the `version:` field in the corresponding `Chart.yaml`.

```bash
# Release the operator chart
git tag cnpg-operator-0.28.3
git push origin cnpg-operator-0.28.3

# Release the cluster chart
git tag cnpg-cluster-0.7.0
git push origin cnpg-cluster-0.7.0
```

### Required GitHub secrets

| Secret                 | Used for                                              |
|------------------------|-------------------------------------------------------|
| `DOCKER_HUB_USERNAME`  | Pull the `rubiklabs/k8s_cli_builder` container image  |
| `DOCKER_HUB_PASSWORD`  | Pull the `rubiklabs/k8s_cli_builder` container image  |
| `OIDC_ROLE_ARN`        | AWS IAM role assumed via OIDC                         |
| `AWS_ECR_REGION`       | AWS region of the ECR registry                        |

## Consuming a published chart

```bash
# Log in
aws ecr get-login-password --region "$AWS_ECR_REGION" \
  | helm registry login "$ECR_HOST" --username AWS --password-stdin

# Install directly from ECR
helm install cnpg-operator \
  "oci://$ECR_HOST/cloudnativepg-operator" --version 0.28.3

helm install my-cluster \
  "oci://$ECR_HOST/cloudnativepg-cluster" --version 0.7.0
```
