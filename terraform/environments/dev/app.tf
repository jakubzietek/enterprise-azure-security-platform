resource "azurerm_service_plan" "app" {
  name                = "asp-ecsp-dev"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  os_type  = "Linux"
  sku_name = "B1"

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_linux_web_app" "app" {
  name                = "app-ecsp-dev-jz"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location
  service_plan_id     = azurerm_service_plan.app.id

  https_only = true

  virtual_network_subnet_id = azurerm_subnet.app_integration.id

  identity {
    type = "UserAssigned"

    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  site_config {

  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }
}