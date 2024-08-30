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
DIR = cloudnative-pg
VERSION = ${TAG}
PACKAGED_CHART = ${DIR}-${VERSION}.tgz

# Push OCI package

push-chart:
	@echo "=== Helm login ==="
	aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | helm3.6.3 registry login ${ECR_HOST} --username AWS --password-stdin --debug
	@echo "=== save chart ==="
	helm3.6.3 chart save ${CH_DIR}/${DIR}/ ${ECR_HOST}/dataos-base-charts:${DIR}-${VERSION}
	@echo
	@echo "=== push chart ==="
	helm3.6.3 chart push ${ECR_HOST}/dataos-base-charts:${DIR}-${VERSION}
	@echo
	@echo "=== logout of registry ==="
	helm3.6.3 registry logout ${ECR_HOST}

push-oci-chart:
	@echo
	echo "=== login to OCI registry ==="
	aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | helm3.14.0 registry login ${ECR_HOST} --username AWS --password-stdin --debug
	@echo
	@echo "=== package OCI chart ==="
	helm3.14.0 package --dependency-update ${CH_DIR}/${DIR}/ --version ${VERSION}
	@echo
	@echo "=== create repository ==="
	aws ecr describe-repositories --repository-names ${DIR} --no-cli-pager || aws ecr create-repository --repository-name ${DIR} --region $(AWS_DEFAULT_REGION) --no-cli-pager
	@echo
	@echo "=== push OCI chart ==="
	helm3.14.0 push ${PACKAGED_CHART} oci://$(ECR_HOST)
	@echo
	@echo "=== logout of registry ==="
	helm3.14.0 registry logout $(ECR_HOST)