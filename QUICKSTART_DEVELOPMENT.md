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

All the following commands and scripts should run from `ckan-cloud-helm` project directory

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

## (optional) Deploy the centralized infrastructure

The centralized infra is deployed on `ckan-cloud` namespace

```
kubectl --context minikube create ns ckan-cloud &&\
helm upgrade --namespace ckan-cloud "ckan-cloud-infra" ckan --install \
     --set centralizedInfraOnly=true
```

## Create an instance namespace and service account permissions

```
export CKAN_NAMESPACE="test27"

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
export CCA_HELM_FUNCTIONS_KUBECTL_ARGS="--context minikube"
export CCA_HELM_FUNCTIONS_HELM_ARGS="--kube-context minikube"
export CKAN_CHART=ckan
source cca_helm_functions.sh
```

## Deploy

If using the centralized infrastructure - create the solr cloud collection with the default ckan config

```
SOLRCLOUD_POD_NAME=$(kubectl --context minikube -n ckan-cloud get pods -l "app=solr" -o 'jsonpath={.items[0].metadata.name}')
kubectl --context minikube -n ckan-cloud exec $SOLRCLOUD_POD_NAME -- \
    bin/solr create_collection -c ${CKAN_NAMESPACE} -d ckan_default -n ckan_default
```

This will install the ckan helm chart for initial deployment on the centralized self-hosted infrastructure

```
cca_helm_upgrade --install --set replicas=1 --set nginxReplicas=1 --set disableJobs=true --set useCentralizedInfra=true --set noProbes=true
```

If you haven't deployed the centralized infra - remove the useCentralizedInfra option

To deploy a local image - connect to the minikube docker: `eval $(minikube docker-env)`, build images from `ckan-cloud-docker` and deploy with e.g. `--set ckanOperatorImage=viderum/ckan-cloud-docker:cca-operator-latest`

Wait for pods to be in Running state:

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

Once all pods are running, deploy again for full deployment using centralized infra (remove `centralizedInfra=true` for self-hosted local infra.)

```
cca_helm_upgrade --install --set useCentralizedInfra=true
```

## Login to CKAN

ensure all pods are running

```
cca_kubectl get pods
```

Create an admin user

```
cca_kubectl exec -it $(cca_pod_name ckan) -- bash -c "ckan-paster --plugin=ckan sysadmin -c /etc/ckan/production.ini \
    add admin password=12345678 email=admin@localhost"
```

Start port forward to the nginx pod

```
cca_kubectl port-forward $(cca_pod_name nginx) 8080
```

Add a hosts entry mapping domain `nginx` to `127.0.0.1`:

```
127.0.0.1 nginx
```

Login to CKAN at http://nginx:8080 with username `admin` password `12345678`
