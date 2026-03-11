variable "resource_name_prefix" {
  type = string
}

variable "location" {
  type = string
}

resource "azurerm_resource_group" "this" {
  name     = "${var.resource_name_prefix}-rg"
  location = var.location
}

output "name" {
  value = azurerm_resource_group.this.name
}
