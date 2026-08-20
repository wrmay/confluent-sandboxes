# Overview

These instructions are for deploying an AKS cluster to Azure.  The 
setup is secure because access is only allowed via a deployed Azure 
Bastion host.  The following elements into a region of your choice.

- A VPC with a 10.240.0.0/16 address space 
- A private subnet, 10.240.1.0/24 for the AKS nodes
- a subnet for the Bastion host with a public IP 
- An AKS cluster with a configurable number  of nodes and the machine size

> __Note:__ The Azure portal actuall interacts with the K8s API server _directly  from the web browser_ in order to display K8s resources.    Because the AKS cluster is private, those functions of the portal wont work.


# Prerequisites

The Azure CLI, `az`, installed and authenticated.  For example: 
```
brew install az
az login 
```

Also, to enable bastion access to the AKS cluster using your local `kubectl`, you will need the "aks-preview" extension.
```
az extension add --name aks-preview
```

# Instructions

Copy `template.env` to `.env` and modify the environment variables there 
according to your wishes. _At a minimum, be sure to change the resource 
group name!_

From a shell ...
```
source azure/.env 
./azure/create_aks_cluster.sh
```

If all goes well, a script will be written to `azure/kubesetup.sh` containing the commands 
needed to point kubectl at your new AKS cluster and establish a tunnel via the Bastion host.
A new shell will be opened in which you can run kubectl commands.
```
chmod +x azure/kubesetup.sh
./azure/kubesetup.sh 
```

Verify access to your cluster.
```
bash-3.2$ kubectl get nodes
NAME                                STATUS   ROLES    AGE   VERSION
aks-nodepool1-19141003-vmss000000   Ready    <none>   58m   v1.35.6
aks-nodepool1-19141003-vmss000001   Ready    <none>   58m   v1.35.6
aks-nodepool1-19141003-vmss000002   Ready    <none>   58m   v1.35.6
aks-nodepool1-19141003-vmss000003   Ready    <none>   58m   v1.35.6
aks-nodepool1-19141003-vmss000004   Ready    <none>   58m   v1.35.6
```


