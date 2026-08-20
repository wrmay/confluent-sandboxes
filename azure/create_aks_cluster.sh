SCRIPTDIR=`dirname $0`

# NOTE: Before running, set the required environment variables
#       by sourcing .env


# 1. Create the Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# 2. Create the Virtual Network and the Node Subnet
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix 10.240.0.0/16 \
    --subnet-name $NODE_SUBNET_NAME \
    --subnet-prefix 10.240.1.0/24 \
    --location $LOCATION

# 3. Create the strictly required AzureBastionSubnet (Must be /26 or larger)
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name AzureBastionSubnet \
    --address-prefix 10.240.3.0/24

# 4. Provision a Standard Public IP for Bastion
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $BASTION_PUBLIC_IP_NAME \
    --sku Standard \
    --location $LOCATION

# 5. Deploy Azure Bastion using the Standard SKU with Tunneling Enabled
az network bastion create \
    --name $BASTION_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --public-ip-address $BASTION_PUBLIC_IP_NAME \
    --sku Standard \
    --enable-tunneling true \
    --location $LOCATION

# 6. Grab the Node Subnet ID 
SUBNET_ID=$(az network vnet subnet show \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $NODE_SUBNET_NAME \
    --query id \
    --output tsv)

# 7. Deploy the COMPLETELY Private AKS Cluster
# The '--enable-private-cluster' flag hides the API server from the internet
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --node-count $NODE_COUNT \
    --node-vm-size $VM_SIZE \
    --network-plugin azure \
    --vnet-subnet-id $SUBNET_ID \
    --zones 1 2 3 \
    --enable-private-cluster \
    --generate-ssh-keys \
    --location $LOCATION

# 8. Print the command to initiate a tunnel for kuebctl via Bastion 
BASTION_ID=$(az network bastion show --name $BASTION_NAME --resource-group $RESOURCE_GROUP --query id --output tsv)

echo FINISHED 
echo 

echo Run  $SCRIPTDIR/kubesetup.sh to point your local kubectl to the new cluster. 
echo az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME > $SCRIPTDIR/kubesetup.sh 
echo az aks bastion tunnel --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --bastion "$BASTION_ID" >> $SCRIPTDIR/kubesetup.sh  




