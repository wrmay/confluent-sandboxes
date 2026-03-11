########################################
# Variables
########################################

variable "name_prefix" {
  type        = string
  description = "Prefix for Entra app display names and identifier URIs"
}

variable "c3_frontend_hostname" {
  type        = string
  description = "Hostname used by Control Center at App Gateway (e.g. c3.lab.local)"
}

########################################
# Tenant / current principal info
########################################

data "azuread_client_config" "current" {}

########################################
# App A: Kafka + MDS OAuth
########################################

resource "azuread_application" "kafka_mds" {
  display_name     = "${var.name_prefix}-cp-kafka-mds"
  sign_in_audience = "AzureADMyOrg"          # single-tenant
  owners           = [data.azuread_client_config.current.object_id]

  # This becomes your audience: api://<prefix>-cp-kafka-mds
  identifier_uris = [
    "api://${var.name_prefix}-cp-kafka-mds"
  ]

  api {
    # Ensure access tokens are v2
    requested_access_token_version = 2
  }
}

resource "azuread_application_password" "kafka_mds" {
  application_object_id = azuread_application.kafka_mds.id
  display_name          = "cp-kafka-mds-secret"
  end_date_relative     = "8760h" # 1 year
}

########################################
# App B: Control Center OIDC SSO
########################################

resource "azuread_application" "c3_oidc" {
  display_name     = "${var.name_prefix}-cp-controlcenter-oidc"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]

  web {
    redirect_uris = [
      "https://${var.c3_frontend_hostname}/api/metadata/security/1.0/oidc/authorization-code/callback"
    ]

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }
}

resource "azuread_application_password" "c3_oidc" {
  application_object_id = azuread_application.c3_oidc.id
  display_name          = "cp-controlcenter-oidc-secret"
  end_date_relative     = "8760h" # 1 year
}

########################################
# Derived endpoints / outputs
########################################

locals {
  tenant_id     = data.azuread_client_config.current.tenant_id
  issuer        = "https://login.microsoftonline.com/${local.tenant_id}/v2.0"
  jwks_uri      = "https://login.microsoftonline.com/${local.tenant_id}/discovery/v2.0/keys"
  token_uri_v2  = "https://login.microsoftonline.com/${local.tenant_id}/oauth2/v2.0/token"
  auth_uri_v2   = "https://login.microsoftonline.com/${local.tenant_id}/oauth2/v2.0/authorize"
}

output "tenant_id" {
  value = local.tenant_id
}

# Kafka/MDS (App A)
output "kafka_mds_client_id" {
  value       = azuread_application.kafka_mds.client_id
  description = "Client ID for cp-kafka-mds"
}

output "kafka_mds_client_secret" {
  value       = azuread_application_password.kafka_mds.value
  sensitive   = true
  description = "Client secret for cp-kafka-mds"
}

output "kafka_mds_audience" {
  value       = tolist(azuread_application.kafka_mds.identifier_uris)[0]
  description = "Audience (identifier URI) for Kafka/MDS OAuth"
}

# Control Center OIDC (App B)
output "c3_oidc_client_id" {
  value       = azuread_application.c3_oidc.client_id
  description = "Client ID for cp-controlcenter-oidc"
}

output "c3_oidc_client_secret" {
  value       = azuread_application_password.c3_oidc.value
  sensitive   = true
  description = "Client secret for cp-controlcenter-oidc"
}

# Shared endpoints
output "issuer" {
  value       = local.issuer
  description = "OIDC issuer URL"
}

output "jwks_uri" {
  value       = local.jwks_uri
  description = "JWKS URI"
}

output "token_endpoint" {
  value       = local.token_uri_v2
  description = "OAuth2 v2.0 token endpoint"
}

output "authorize_endpoint" {
  value       = local.auth_uri_v2
  description = "OAuth2 v2.0 authorization endpoint (for C3 SSO)"
}