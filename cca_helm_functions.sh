cca_kubectl() {
  [ -z "${CKAN_NAMESPACE}" ] && echo missing CKAN_NAMESPACE env var && return 1
  echo kubeconfig = /etc/ckan-cloud/.kube-config, CKAN_NAMESPACE = $CKAN_NAMESPACE >/dev/stderr
  kubectl --kubeconfig /etc/ckan-cloud/.kube-config --namespace "${CKAN_NAMESPACE}" "$@"
}

cca_pod_name() {
  cca_kubectl get pods -l "app=${1}" -o 'jsonpath={.items[0].metadata.name}'
}

cca_helm() {
  echo kubeconfig = /etc/ckan-cloud/.kube-config  >/dev/stderr
  ! [ -e ./ckan/Chart.yaml ] && cd ../multi-tenant-helm
  helm --kubeconfig /etc/ckan-cloud/.kube-config "$@"
}

cca_helm_upgrade() {
  [ -z "${CKAN_NAMESPACE}" ] && echo missing CKAN_NAMESPACE env var && return 1
  cca_helm upgrade --namespace $CKAN_NAMESPACE "ckan-multi-${CKAN_NAMESPACE}" ckan --dry-run "$@" &&\
  cca_helm upgrade --namespace $CKAN_NAMESPACE "ckan-multi-${CKAN_NAMESPACE}" ckan "$@"
}
