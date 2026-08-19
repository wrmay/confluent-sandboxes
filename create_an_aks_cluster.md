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



Now you need to enable aks access via your bastion host.  First you'll 
need to obtain the full resource id of your bastion host ...

```
export $BASTION_HOST_ID=$(az network bastion show --name bastion-secure-gateway --resource-group rmay-private-aks --query id --output tsv)
```
> __Note:__ if you used a different resource name then _bastion-secure-gateway_, 
be sure to change the command to match!



