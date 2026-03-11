output "resource_group_name" {
  value = module.resource_group.name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "subnet_aks_id" {
  value = module.networking.subnet_aks_id
}

output "subnet_appgw_id" {
  value = module.networking.subnet_appgw_id
}

output "subnet_cc_privatelink_id" {
  value = module.networking.subnet_cc_privatelink_id
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "acr_name" {
  value = module.acr.name
}

output "app_gateway_id" {
  value       = module.app_gateway[*].id
  description = "ID of App Gateway (if enabled)"
}
