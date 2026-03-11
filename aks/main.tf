module "resource_group" {
  source               = "./modules/resource_group"
  resource_name_prefix = var.resource_name_prefix
  location             = var.location
}

module "networking" {
  source              = "./modules/networking"
  resource_group_name = module.resource_group.name
  location            = var.location
  vnet_cidr           = var.vnet_cidr
  name_prefix         = var.resource_name_prefix
}

module "acr" {
  source              = "./modules/acr"
  resource_group_name = module.resource_group.name
  location            = var.location
  name_prefix         = var.resource_name_prefix
}

module "aks" {
  source              = "./modules/aks"
  resource_group_name = module.resource_group.name
  location            = var.location
  name_prefix         = var.resource_name_prefix
  subnet_id           = module.networking.subnet_aks_id
  node_count          = var.aks_node_count
  vm_size             = var.aks_vm_size
  acr_id              = module.acr.id
}

module "app_gateway" {
  source              = "./modules/app_gateway"
  count               = var.enable_app_gateway ? 1 : 0
  resource_group_name = module.resource_group.name
  location            = var.location
  name_prefix         = var.resource_name_prefix
  subnet_id           = module.networking.subnet_appgw_id
  public_frontend     = var.app_gateway_public
  sku_name            = var.app_gateway_sku
  capacity            = var.app_gateway_capacity
  ssl_pfx_path     = var.app_gateway_ssl_pfx_path
  ssl_pfx_password = var.app_gateway_ssl_pfx_password
}

module "azuread_apps" {
  source              = "./modules/azuread_apps"
  name_prefix         = var.resource_name_prefix
  c3_frontend_hostname = "c3.lab.local"   # the hostname you chose for your application gateway cert.
}