resource "azurerm_service_plan" "app" {
  # checkov:skip=CKV_AZURE_211:B1 is intentionally used for the cost-contained disposable DEV environment; production would use a production-grade App Service SKU.
  # checkov:skip=CKV_AZURE_225:Zone redundancy is intentionally omitted in disposable DEV to avoid production-grade availability cost.
  # checkov:skip=CKV_AZURE_212:Multiple instances are intentionally omitted in disposable DEV; production would use redundant instances for failover.
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
  # checkov:skip=CKV_AZURE_88:The validation application is stateless and has no persistent Azure Files requirement.
  # checkov:skip=CKV_AZURE_222:Public ingress is intentionally retained in DEV for external validation; backend data services remain private and production ingress would be restricted.
  # checkov:skip=CKV_AZURE_17:Mutual TLS is not part of the DEV application access model; client certificate authentication would be enabled only where required by the production threat model.
  # checkov:skip=CKV_AZURE_65:Detailed error messages are intentionally not enabled in DEV; selected operational telemetry is centralized in Log Analytics.
  # checkov:skip=CKV_AZURE_66:Failed request tracing is intentionally omitted to limit diagnostic noise and cost; selected HTTP telemetry is centralized in Log Analytics.
  # checkov:skip=CKV_AZURE_13:Authentication is intentionally omitted from the disposable DEV validation app; endpoints operate on synthetic test data and production ingress would require authenticated access.
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
    http2_enabled                     = true
    ftps_state                        = "Disabled"
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5
    application_stack {
      python_version = "3.12"
    }

  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }
}