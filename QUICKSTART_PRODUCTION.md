# Using multi-tenant CKAN Helm chart for production deployment

## Create cluster resources

The following resources are required, follow the [multi-tenant CKAN cluster management docs](../multi-tenant-cluster/README.md) to create them:

* Kubernetes cluster, accessible via a kubeconfig file
* Helm installed on the cluster
* `cca-storage` storage class - allowing to provision `ReadWriteOnce` persistent disks
* `cca-ckan` storage class - allowing to provision `ReadWriteMany` persistent disks

Verify the requirements:

```
export KUBECONFIG=/etc/ckan-cloud/.kube-config &&\
kubectl get storageclass cca-storage &&\
kubectl get storageclass cca-ckan &&\
helm version &&\
helm list
```

## Get the code

Clone from Git or download the source zip.

All the following commands and scripts should run from current working directory: `datagov-ckan-multi/multi-tenant-helm`

## Define utility functions

```
source cca_helm_functions.sh
```

## Create CKAN namespace and RBAC

```
export CKAN_NAMESPACE="test1"

cca_kubectl create ns "${CKAN_NAMESPACE}" &&\
cca_kubectl create serviceaccount "ckan-${CKAN_NAMESPACE}-operator" &&\
cca_kubectl create role "ckan-${CKAN_NAMESPACE}-operator-role" \
                        --verb list,get,create \
                        --resource secrets,pods,pods/exec,pods/portforward &&\
cca_kubectl create rolebinding "ckan-${CKAN_NAMESPACE}-operator-rolebinding" \
                               --role "ckan-${CKAN_NAMESPACE}-operator-role" \
                               --serviceaccount "${CKAN_NAMESPACE}:ckan-${CKAN_NAMESPACE}-operator"
```

## Deploy

Save the values yaml file:

```
sudo cp aws-values.yaml /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml
```

Initial deployment should be with 1 replica

```
cca_helm_upgrade -if /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml --set replicas=1 --set nginxReplicas=1
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

Once all pods are in Running state, deploy with replicas (2 replicas by default for both ckan and nginx):

```
cca_helm_upgrade --install --values /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml
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

## Expose via load balancer

see [multi-tenant-cluster](../multi-tenant-cluster/README.md) for creating and configuring the load balancer

Configure the load balancer to direct traffic to `http://nginx.<CKAN_NAMESPACE>:8080`

Duplicate and modify `aws-values.yaml` and set the siteUrl to the relevant external domain.

Deploy with the modified values:

```
cca_helm_upgrade --install --values /etc/ckan-cloud/${CKAN_NAMESPACE}_values.yaml
```
