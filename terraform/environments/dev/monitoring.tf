resource "azurerm_log_analytics_workspace" "security" {
  name                = "law-ecsp-dev"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  sku               = "PerGB2018"
  retention_in_days = 30
  daily_quota_gb    = 0.1

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "ds-ecsp-keyvault"
  target_resource_id         = azurerm_key_vault.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id

  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AuditEvent"
  }

}

resource "azurerm_mssql_server_extended_auditing_policy" "app" {
  server_id = azurerm_mssql_server.app.id

  log_monitoring_enabled = true


}

resource "azurerm_monitor_diagnostic_setting" "sql_audit" {
  name = "ds-ecsp-sql-audit"

  target_resource_id = "${azurerm_mssql_server.app.id}/databases/master"

  log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

}

resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name = "ds-ecsp-storage-blob"

  target_resource_id = "${azurerm_storage_account.app.id}/blobServices/default"

  log_analytics_workspace_id     = azurerm_log_analytics_workspace.security.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

}

resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "ds-ecsp-app-service"
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id

  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AppServiceHTTPLogs"
  }
}