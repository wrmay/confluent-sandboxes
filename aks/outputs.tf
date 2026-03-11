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

output "aad_tenant_id" {
  value = module.azuread_apps.tenant_id
}

output "kafka_mds_client_id" {
  value = module.azuread_apps.kafka_mds_client_id
}

output "kafka_mds_client_secret" {
  value     = module.azuread_apps.kafka_mds_client_secret
  sensitive = true
}

output "kafka_mds_audience" {
  value = module.azuread_apps.kafka_mds_audience
}

output "c3_oidc_client_id" {
  value = module.azuread_apps.c3_oidc_client_id
}

output "c3_oidc_client_secret" {
  value     = module.azuread_apps.c3_oidc_client_secret
  sensitive = true
}

output "aad_issuer" {
  value = module.azuread_apps.issuer
}

output "aad_jwks_uri" {
  value = module.azuread_apps.jwks_uri
}

output "aad_token_endpoint" {
  value = module.azuread_apps.token_endpoint
}

output "aad_authorize_endpoint" {
  value = module.azuread_apps.authorize_endpoint
}