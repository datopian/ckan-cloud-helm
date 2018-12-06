# Using multi-tenant CKAN Helm chart for production deployment

## Create cluster resources

The following resources are required, follow the [multi-tenant CKAN cluster management docs](https://github.com/ViderumGlobal/ckan-cloud-cluster/blob/master/README.md) to create them:

* Kubernetes cluster, accessible via a kubeconfig file
* Helm installed on the cluster
* `cca-storage` storage class - allowing to provision `ReadWriteOnce` persistent disks
* `cca-ckan` storage class - allowing to provision `ReadWriteMany` persistent disks
* PostgreSQL DB - hosted and managed outside the cluster (e.g. Amazon RDS)
  * Connection details should be provided in a secret named `ckan-infra` on `ckan-cloud` namespace
* Solr Cloud - hosted on `ckan-cloud` namespace, `solr` service

Verify the cluster requirements:

```
export KUBECONFIG=/etc/ckan-cloud/.kube-config &&\
kubectl get nodes &&\
kubectl get storageclass cca-storage &&\
kubectl get storageclass cca-ckan &&\
helm version &&\
helm list
```

Get the centralized DB connection details

```
CENTRAL_DB_URL=$(
kubectl -n ckan-cloud get secret ckan-infra -o json \
    | python -c 'import json,sys,base64; print("postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}".format(**{k:base64.b64decode(v) for k,v in json.load(sys.stdin)["data"].items()}))'
)
```

Try to connect to the DB:

```
psql -d $CENTRAL_DB_URL
```

Verify SOLR Cloud

```
kubectl port-forward -n ckan-cloud deployment/solr 8983
```

Solr Cloud should be available at http://localhost:8983

## Register the CKAN Cloud Helm charts repository

```
helm repo add ckan-cloud https://raw.githubusercontent.com/ViderumGlobal/ckan-cloud-helm/master/charts_repository
```

## Get the code

Clone from Git or download the source zip.

All the following commands and scripts should run from the `ckan-cloud-helm` project directory

## Define shortcut functions

```
export KUBECONFIG=/etc/ckan-cloud/.kube-config
export CCA_HELM_FUNCTIONS_KUBECTL_ARGS=""
export CCA_HELM_FUNCTIONS_HELM_ARGS=""
export CKAN_CHART=ckan-cloud/ckan
source cca_helm_functions.sh
```

For local development set `export CKAN_CHART=ckan` to install from the local chart directory

## Create CKAN namespace and RBAC

```
export CKAN_NAMESPACE="test2"

cca_kubectl create ns "${CKAN_NAMESPACE}" &&\
cca_kubectl create serviceaccount "ckan-${CKAN_NAMESPACE}-operator" &&\
cca_kubectl create role "ckan-${CKAN_NAMESPACE}-operator-role" \
                        --verb list,get,create \
                        --resource secrets,pods,pods/exec,pods/portforward &&\
cca_kubectl create rolebinding "ckan-${CKAN_NAMESPACE}-operator-rolebinding" \
                               --role "ckan-${CKAN_NAMESPACE}-operator-role" \
                               --serviceaccount "${CKAN_NAMESPACE}:ckan-${CKAN_NAMESPACE}-operator"
```

Copy the centralized infra secret

```
kubectl -n ckan-cloud get secret ckan-infra --export -o yaml | kubectl -n $CKAN_NAMESPACE create -f -
```

## Deploy

If using the centralized infrastructure - create the solr cloud collection with the default ckan config

```
SOLRCLOUD_POD_NAME=$(kubectl -n ckan-cloud get pods -l "app=solr" -o 'jsonpath={.items[0].metadata.name}')
kubectl -n ckan-cloud exec $SOLRCLOUD_POD_NAME -- \
    sudo -u solr bin/solr create_collection -c ${CKAN_NAMESPACE} -d ckan_default -n ckan_default
```

Copy the values yaml file:

```
sudo cp aws-values.yaml /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml
```

Initial deployment

```
cca_helm_upgrade -if /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml --set replicas=1 --set nginxReplicas=1 --set disableJobs=true --set noProbes=true
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

Once all pods are in Running state, do a full deployment

```
cca_helm_upgrade -if /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml
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

## Expose via load balancer

Configure the load balancer to direct traffic to `http://nginx.<CKAN_NAMESPACE>:8080`

Modify the instance values and set the siteUrl to the relevant external domain.

Deploy with the modified values:

```
cca_helm_upgrade --install --values /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml
```

## Testing different CKAN helm chart versions

The `CKAN_CHART` environment variable determines which Helm chart version will be installed

Check available chart versions from the repository:

```
helm repo update
helm search ckan-cloud/ckan
```

Deploy a specific version:

```
export CKAN_CHART="ckan-cloud/ckan --version v0.0.2"
cca_helm_upgrade --install --values /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml
```

Deploy from local directory for development:

```
export CKAN_CHART="ckan"
cca_helm_upgrade --install --values /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml
```
