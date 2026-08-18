# 1. Configuration Variables
RESOURCE_GROUP="rg-private-aks"
LOCATION="eastus"
VNET_NAME="vnet-private-network"
CLUSTER_NAME="private-testing-cluster"
VM_SIZE="Standard_B2s"
JUMPBOX_NAME="vm-aks-jumpbox"
JUMPBOX_SUBNET_NAME="snet-jumpbox"


# Subnet variables (Bastion requires a strictly named subnet)
NODE_SUBNET_NAME="snet-aks-nodes"
BASTION_SUBNET_NAME="AzureBastionSubnet"
BASTION_NAME="bastion-secure-gateway"
BASTION_PUBLIC_IP_NAME="pip-bastion"

# 2. Create the Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# 3. Create the Virtual Network and the Node Subnet
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix 10.0.0.0/8 \
    --subnet-name $NODE_SUBNET_NAME \
    --subnet-prefix 10.240.0.0/16

# 4. Create the strictly required AzureBastionSubnet (Must be /26 or larger)
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $BASTION_SUBNET_NAME \
    --address-prefix 10.1.0.0/26

# 5. Provision a Standard Public IP for Bastion
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $BASTION_PUBLIC_IP_NAME \
    --sku Standard \
    --location $LOCATION

# 6. Deploy Azure Bastion using the Standard SKU with Tunneling Enabled
az network bastion create \
    --name $BASTION_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --public-ip-address $BASTION_PUBLIC_IP_NAME \
    --sku Standard \
    --enable-tunneling true \
    --location $LOCATION

# 7. Grab the Node Subnet ID 
SUBNET_ID=$(az network vnet subnet show \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $NODE_SUBNET_NAME \
    --query id \
    --output tsv)

# 8. Deploy the COMPLETELY Private AKS Cluster
# The '--enable-private-cluster' flag hides the API from the internet
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --node-count 4 \
    --node-vm-size $VM_SIZE \
    --network-plugin azure \
    --vnet-subnet-id $SUBNET_ID \
    --zones 1 2 3 \
    --enable-private-cluster \
    --generate-ssh-keys


# 9. Create a dedicated subnet for the Jump Box inside your VNet
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $JUMPBOX_SUBNET_NAME \
    --address-prefix 10.240.2.0/24

# 10. Define the initialization script to automatically install tools on startup
cat << 'EOF' > cloud-init.txt
#cloud-config
package_update: true
package_upgrade: true
runcmd:
  # Install Azure CLI
  - curl -sL https://aka.ms | bash
  # Install kubectl
  - curl -LO "https://k8s.io(curl -L -s https://k8s.io)/bin/linux/amd64/kubectl"
  - install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
EOF

# 11. Create the Jump Box VM (Standard_B2s matches your node performance)
# Note: It has NO public IP address (--public-ip-address "") for maximum security
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $JUMPBOX_NAME \
    --image Ubuntu2204 \
    --size Standard_B2s \
    --vnet-name $VNET_NAME \
    --subnet $JUMPBOX_SUBNET_NAME \
    --public-ip-address "" \
    --custom-data cloud-init.txt \
    --admin-username azureuser \
    --generate-ssh-keys

# 12. Clean up local initialization file
rm cloud-init.txt
