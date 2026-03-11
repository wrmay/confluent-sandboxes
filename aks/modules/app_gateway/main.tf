variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "public_frontend" {
  type = bool
}

variable "sku_name" {
  type = string
}

variable "capacity" {
  type = number
}

variable "ssl_certificate_name" {
  type        = string
  default     = "c3-cert"
}

variable "ssl_pfx_path" {
  type        = string
  description = "Path to PFX file for AppGW SSL cert"
}

variable "ssl_pfx_password" {
  type        = string
  description = "Password for PFX cert"
  sensitive   = true
}

# Placeholder backend FQDN; later set this to the internal DNS name used by C3
variable "backend_fqdn" {
  type        = string
  description = "Backend FQDN for Control Center internal LB (HTTPS)"
  default     = "c3.internal.example"
}

resource "azurerm_public_ip" "this" {
  count               = var.public_frontend ? 1 : 0
  name                = "${var.name_prefix}-appgw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "this" {
  name                = "${var.name_prefix}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.sku_name
    tier     = var.sku_name
    capacity = var.capacity
  }
  
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "appgw-ipcfg"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  dynamic "frontend_ip_configuration" {
    for_each = var.public_frontend ? [1] : []
    content {
      name                 = "public-frontend-ip"
      public_ip_address_id = azurerm_public_ip.this[0].id
    }
  }

  ssl_certificate {
    name     = var.ssl_certificate_name
    data     = filebase64(var.ssl_pfx_path)
    password = var.ssl_pfx_password
  }

  backend_address_pool {
    name  = "c3-backend-pool"
    fqdns = [var.backend_fqdn]
  }

  backend_http_settings {
    name                           = "https-settings"
    protocol                       = "Https"
    port                           = 9021
    pick_host_name_from_backend_address = true
    request_timeout                = 60
    cookie_based_affinity          = "Enabled"
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend-ip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = var.ssl_certificate_name
  }

  request_routing_rule {
    name                       = "c3-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "c3-backend-pool"
    backend_http_settings_name = "https-settings"
    priority                   = 1
  }
}

output "id" {
  value = azurerm_application_gateway.this.id
}