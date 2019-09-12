# Contributing to CKAN Cloud Helm

* Welcome to CKAN Cloud!
* Contributions of any kind are welcome.
* Please [Search for issues across the different CKAN Cloud repositories](https://github.com/search?q=repo%3AViderumGlobal%2Fckan-cloud-docker+repo%3AViderumGlobal%2Fckan-cloud-helm+repo%3AViderumGlobal%2Fckan-cloud-cluster&type=Issues)

## Suggested development flow

You want to make some changes to the helm charts? Great!

Please follow this suggested flow:

* Changes to Docker images should be done in ViderumGlobal/ckan-cloud-docker repo
  * Test changes to the Docker images using the `ckan-cloud-docker` docker compose environment
* Use the [Minikube environment](QUICKSTART_MINIKUBE.md) to test and modify the Helm templates
* Finally, test on a [Production environment](QUICKSTART_PRODUCTION.md)

## CI/CD

* Helm chart repository is hosted on the same GitHub branch as the helm charts
* The repository is updated when a new release is published on GitHub

## Updating the Helm charts repo for development

```
BRANCH_NAME=github-branch-name

SEMANTIC_VERSION=v0.0.0-$BRANCH_NAME

cd charts_repository &&\
helm package ../ckan --version "${SEMANTIC_VERSION}" &&\
helm package ../efs --version "${SEMANTIC_VERSION}" &&\
helm package ../elk --version "${SEMANTIC_VERSION}" &&\
helm package ../traefik --version "${SEMANTIC_VERSION}" &&\
helm package ../provisioning --version "${SEMANTIC_VERSION}" &&\
helm repo index --url https://raw.githubusercontent.com/ViderumGlobal/ckan-cloud-helm/${BRANCH_NAME}/charts_repository/ . &&\
cd ..
```

Then you can test locally or push to GitHub to publish to the repo
