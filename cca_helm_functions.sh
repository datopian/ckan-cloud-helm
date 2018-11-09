cca_kubectl() {
  [ -z "${CKAN_NAMESPACE}" ] && echo missing CKAN_NAMESPACE env var && return 1
  echo $CCA_HELM_FUNCTIONS_KUBECTL_ARGS CKAN_NAMESPACE = $CKAN_NAMESPACE >/dev/stderr
  kubectl $CCA_HELM_FUNCTIONS_KUBECTL_ARGS --namespace "${CKAN_NAMESPACE}" "$@"
}

cca_pod_name() {
  cca_kubectl get pods -l "app=${1}" -o 'jsonpath={.items[0].metadata.name}'
}

cca_helm() {
  echo $CCA_HELM_FUNCTIONS_HELM_ARGS >/dev/stderr
  helm $CCA_HELM_FUNCTIONS_HELM_ARGS "$@"
}

cca_helm_upgrade() {
  [ -z "${CKAN_NAMESPACE}" ] && echo missing CKAN_NAMESPACE env var && return 1
  cca_helm upgrade --namespace $CKAN_NAMESPACE "ckan-cloud-${CKAN_NAMESPACE}" $CKAN_CHART --dry-run "$@" &&\
  cca_helm upgrade --namespace $CKAN_NAMESPACE "ckan-cloud-${CKAN_NAMESPACE}" $CKAN_CHART "$@"
}
