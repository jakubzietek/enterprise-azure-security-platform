data "azurerm_resource_group" "dev" {
  name = "rg-ecsp-dev"
}

data "azurerm_client_config" "current" {

}

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-ecsp-app-dev"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    purpose     = "application-workload"
    managed_by  = "terraform"
  }
}