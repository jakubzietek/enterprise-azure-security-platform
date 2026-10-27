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

  app_settings = {
    AZURE_CLIENT_ID                = azurerm_user_assigned_identity.app.client_id
    STORAGE_ACCOUNT_NAME           = azurerm_storage_account.app.name
    STORAGE_CONTAINER_NAME         = azurerm_storage_container.app_data.name
    KEY_VAULT_URI                  = azurerm_key_vault.app.vault_uri
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    SQL_SERVER_FQDN                = azurerm_mssql_server.app.fully_qualified_domain_name
    SQL_DATABASE_NAME              = azurerm_mssql_database.app.name
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }

  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }
}