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
ECR_DEFAULT_REGIONS = us-east-1

# Push OCI package

push-oci-chart:
	@echo
	echo "=== login to OCI registry ==="
	aws ecr-public get-login-password --region us-east-1 | helm3.14.0 registry login  --username AWS --password-stdin public.ecr.aws
	@echo
	@echo "=== package OCI chart ==="
	helm3.14.0 package --dependency-update ${CH_DIR}/${DIR}/ --version ${VERSION}
	@echo
	@echo "=== create repository ==="
	aws ecr-public describe-images --repository-name ${DIR} --region us-east-1 || aws ecr-public create-repository --repository-name ${DIR} --region us-east-1
	@echo
	@echo "=== push OCI chart ==="
	helm3.14.0 push ${PACKAGED_CHART} oci://public.ecr.aws/z2k6n2n9
	@echo
	@echo "=== logout of registry ==="
	helm3.14.0 registry logout public.ecr.aws