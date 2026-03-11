variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_cidr" {
  type = string
}

variable "name_prefix" {
  type = string
}

locals {
  # Subnet layout:
  # - AKS: /20 (plenty of IPs)
  # - AppGW: /24
  # - CC Private Link: /24
  snet_aks_cidr            = cidrsubnet(var.vnet_cidr, 4, 0)   # 10.9.0.0/20
  snet_appgw_cidr          = cidrsubnet(var.vnet_cidr, 8, 16)  # 10.9.16.0/24
  snet_cc_privatelink_cidr = cidrsubnet(var.vnet_cidr, 8, 17)  # 10.9.17.0/24
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
}

# --- NSGs ---

resource "azurerm_network_security_group" "aks" {
  name                = "${var.name_prefix}-nsg-aks"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow from VirtualNetwork and AzureLoadBalancer; deny others is implicit
  security_rule {
    name                       = "Allow_VNet_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_AzureLoadBalancer_Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_All_Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }
}


resource "azurerm_network_security_group" "cc_privatelink" {
  name                = "${var.name_prefix}-nsg-cc-privatelink"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow VNet traffic in/out; Private Endpoints will tighten this as needed
  security_rule {
    name                       = "Allow_VNet_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_VNet_Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

# --- Subnets ---

resource "azurerm_subnet" "aks" {
  name                 = "${var.name_prefix}-snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.snet_aks_cidr]
}

resource "azurerm_subnet" "appgw" {
  name                 = "${var.name_prefix}-snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.snet_appgw_cidr]
}

resource "azurerm_subnet" "cc_privatelink" {
  name                 = "${var.name_prefix}-snet-cc-privatelink"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.snet_cc_privatelink_cidr]
}

# --- NSG associations ---

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "cc_privatelink" {
  subnet_id                 = azurerm_subnet.cc_privatelink.id
  network_security_group_id = azurerm_network_security_group.cc_privatelink.id
}

# --- Outputs ---

output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "subnet_aks_id" {
  value = azurerm_subnet.aks.id
}

output "subnet_appgw_id" {
  value = azurerm_subnet.appgw.id
}

output "subnet_cc_privatelink_id" {
  value = azurerm_subnet.cc_privatelink.id
}
