.DEFAULT_GOAL := help

# Credits: https://gist.github.com/prwhite/8168133
.PHONY: help
help: ## Prints help command output
	@awk 'BEGIN {FS = ":.*##"; printf "\ncnpg CLI\nUsage:\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

## Update chart's README.md
.PHONY: docs
docs: ## Generate charts' docs using helm-docs
	helm-docs || \
		(echo "Please, install https://github.com/norwoodj/helm-docs first" && exit 1)

.PHONY: schema
schema: cloudnative-pg-schema cluster-schema ## Generate charts' schema using helm-schema-gen

cloudnative-pg-schema:
	@helm schema-gen charts/cloudnative-pg/values.yaml | cat > charts/cloudnative-pg/values.schema.json || \
		(echo "Please, run: helm plugin install https://github.com/karuppiah7890/helm-schema-gen.git" && exit 1)

cluster-schema:
	@helm schema-gen charts/cluster/values.yaml | cat > charts/cluster/values.schema.json || \
		(echo "Please, run: helm plugin install https://github.com/karuppiah7890/helm-schema-gen.git" && exit 1)


CH_DIR = charts
OPERATOR_DIR = cloudnative-pg
CLUSTER_DIR = postgres
VERSION = ${TAG}
OPERATOR_PACKAGED_CHART = ${OPERATOR_DIR}-${VERSION}.tgz
CLUSTER_PACKAGED_CHART = ${CLUSTER_DIR}-${VERSION}.tgz

# Push OCI package

push-chart:
	@echo "=== Helm login ==="
	aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | helm3.6.3 registry login ${ECR_HOST} --username AWS --password-stdin --debug
	@echo "=== save ${OPERATOR_DIR} chart ==="
	helm3.6.3 chart save ${CH_DIR}/${OPERATOR_DIR}/ ${ECR_HOST}/dataos-base-charts:${OPERATOR_DIR}-${VERSION}
	@echo
	@echo "=== push ${OPERATOR_DIR}  chart ==="
	helm3.6.3 chart push ${ECR_HOST}/dataos-base-charts:${OPERATOR_DIR}-${VERSION}
	@echo
	@echo "=== save ${CLUSTER_DIR} chart ==="
	helm3.6.3 chart save ${CH_DIR}/${CLUSTER_DIR}/ ${ECR_HOST}/dataos-base-charts:${CLUSTER_DIR}-${VERSION}
	@echo
	@echo "=== push ${CLUSTER_DIR} chart ==="
	helm3.6.3 chart push ${ECR_HOST}/dataos-base-charts:${CLUSTER_DIR}-${VERSION}
	@echo
	@echo "=== logout of registry ==="
	helm3.6.3 registry logout ${ECR_HOST}

push-oci-chart:
	@echo
	echo "=== login to OCI registry ==="
	aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | helm3.14.0 registry login ${ECR_HOST} --username AWS --password-stdin --debug
	@echo
	@echo "=== package ${OPERATOR_DIR} OCI chart ==="
	helm3.14.0 package ${CH_DIR}/${OPERATOR_DIR}/ --version ${VERSION}
	@echo
	@echo "=== create ${OPERATOR_DIR} repository ==="
	aws ecr describe-repositories --repository-names ${OPERATOR_DIR} --no-cli-pager || aws ecr create-repository --repository-name ${OPERATOR_DIR} --region $(AWS_DEFAULT_REGION) --no-cli-pager
	@echo
	@echo "=== push ${OPERATOR_DIR} OCI chart ==="
	helm3.14.0 push ${OPERATOR_PACKAGED_CHART} oci://$(ECR_HOST)
	@echo
	@echo
	@echo "=== package ${CLUSTER_DIR} OCI chart ==="
	helm3.14.0 package ${CH_DIR}/postgres/ --version ${VERSION}
	@echo
	@echo "=== create ${CLUSTER_DIR} repository ==="
	aws ecr describe-repositories --repository-names ${CLUSTER_DIR} --no-cli-pager || aws ecr create-repository --repository-name ${CLUSTER_DIR} --region $(AWS_DEFAULT_REGION) --no-cli-pager
	@echo
	@echo "=== push ${CLUSTER_DIR} OCI chart ==="
	helm3.14.0 push ${CLUSTER_PACKAGED_CHART} oci://$(ECR_HOST)
	@echo
	@echo "=== logout of registry ==="
	helm3.14.0 registry logout $(ECR_HOST)