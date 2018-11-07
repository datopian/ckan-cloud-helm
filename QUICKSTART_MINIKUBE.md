# Using multi-tenant CKAN Helm chart on Minikube for local development and testing

## Install

* [Install Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [Install Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
  * Following should work on recent Linux distributions:

```
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 &&\
sudo install minikube-linux-amd64 /usr/local/bin/minikube &&\
rm minikube-linux-amd64
```

* [Install Helm client](https://docs.helm.sh/using_helm/#installing-helm)
  * Following should work on recent Linux distributions:

```
HELM_VERSION=v2.11.0

curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh &&\
     chmod 700 get_helm.sh &&\
     ./get_helm.sh --version "${HELM_VERSION}" &&\
     helm version --client && rm ./get_helm.sh
```

## Get the code

Clone from Git or download the source zip.

All the following commands and scripts should run from current working directory: `datagov-ckan-multi/multi-tenant-helm`

## Start a Minikube cluster

```
export KUBERNETES_VERSION=v1.10.0
```

(Optional) to ensure a clean minikube cluster:

```
minikube delete; rm -rf ~/.minikube
```

Start the cluster

```
minikube start --kubernetes-version "${KUBERNETES_VERSION}"
```

## Install Helm

Create service account for Helm

```
kubectl --context minikube --namespace kube-system create serviceaccount tiller
```

Give the service account full permissions to manage the cluster

```
kubectl --context minikube create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
```

Initialize Helm

```
helm --kube-context=minikube init --service-account tiller --history-max 2 --upgrade --wait
```

Ensure helm version on client and server

```
helm --kube-context=minikube version
```

Restrict Helm to interaction only via the Helm CLI ([source](https://engineering.bitnami.com/articles/helm-security.html))

```
kubectl --context minikube -n kube-system delete service tiller-deploy &&\
kubectl --context minikube -n kube-system patch deployment tiller-deploy --patch '
spec:
  template:
    spec:
      containers:
        - name: tiller
          ports: []
          command: ["/tiller"]
          args: ["--listen=localhost:44134"]
'
```

## Create CKAN namespace and RBAC

```
export CKAN_NAMESPACE="test7"

kubectl --context minikube create ns "${CKAN_NAMESPACE}" &&\
kubectl --context minikube --namespace "${CKAN_NAMESPACE}" \
    create serviceaccount "ckan-${CKAN_NAMESPACE}-operator" &&\
kubectl --context minikube --namespace "${CKAN_NAMESPACE}" \
    create role "ckan-${CKAN_NAMESPACE}-operator-role" --verb list,get,create \
                                                       --resource secrets,pods,pods/exec,pods/portforward &&\
kubectl --context minikube --namespace "${CKAN_NAMESPACE}" \
    create rolebinding "ckan-${CKAN_NAMESPACE}-operator-rolebinding" --role "ckan-${CKAN_NAMESPACE}-operator-role" \
                                                                     --serviceaccount "${CKAN_NAMESPACE}:ckan-${CKAN_NAMESPACE}-operator"
```

## Define shortcut functions

```
cca_kubectl() {
  [ -z "${CKAN_NAMESPACE}" ] && echo missing CKAN_NAMESPACE env var && return 1
  echo context = minikube, CKAN_NAMESPACE = $CKAN_NAMESPACE >/dev/stderr
  kubectl --context minikube --namespace "${CKAN_NAMESPACE}" "$@"
}

cca_pod_name() {
  cca_kubectl get pods -l "app=${1}" -o 'jsonpath={.items[0].metadata.name}'
}

cca_helm() {
  [ -z "${CKAN_NAMESPACE}" ] && echo missing CKAN_NAMESPACE env var && return 1
  echo context = minikube, CKAN_NAMESPACE = $CKAN_NAMESPACE  >/dev/stderr
  helm --kube-context minikube "$@"
}

cca_helm_upgrade() {
  cca_helm upgrade --namespace $CKAN_NAMESPACE "ckan-multi-${CKAN_NAMESPACE}" ckan --dry-run "$@" &&\
  cca_helm upgrade --namespace $CKAN_NAMESPACE "ckan-multi-${CKAN_NAMESPACE}" ckan "$@"
}
```

## Deploy

First install should be with a single replica, additional values for running on Minikube:

```
cca_helm_upgrade --install --set replicas=1 --set ckanJobsPortForward=true --set nginxReplicas=1
```

Wait for Pods to be in Running state:

```
cca_kubectl get pods
```

Describe a pod

```
cca_kubectl describe pod $(cca_pod_name db)
```

Follow logs

```
cca_kubectl logs -f $(cca_pod_name ckan)
```

## Login to CKAN

Create an admin user

```
cca_kubectl exec -it $(cca_pod_name ckan) -- bash -c "ckan-paster --plugin=ckan sysadmin -c /etc/ckan/production.ini \
    add admin password=12345678 email=admin@localhost"
```

Start port forward to the nginx pod

```
cca_kubectl port-forward $(cca_pod_name nginx) 8080:80
```

Login to CKAN at http://localhost:8080 with username `admin` password `12345678`
