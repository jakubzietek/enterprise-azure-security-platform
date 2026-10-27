resource "azurerm_mssql_server" "app" {
  # checkov:skip=CKV_AZURE_23:SQL auditing is implemented with centralized telemetry in M6.
  # checkov:skip=CKV_AZURE_24:SQL audit retention is configured with centralized telemetry in M6.
  name                = "sql-ecsp-dev-jz"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  version = "12.0"

  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username              = var.sql_entra_admin_login
    object_id                   = var.sql_entra_admin_object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true
  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_mssql_database" "app" {
  name      = "sqldb-ecsp-dev"
  server_id = azurerm_mssql_server.app.id

  sku_name             = "Basic"
  max_size_gb          = 2
  storage_account_type = "Local"

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-ecsp-sql-dev"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  subnet_id = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-ecsp-sql-dev"
    private_connection_resource_id = azurerm_mssql_server.app.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false

  }

  private_dns_zone_group {
    name = "pdzg-ecsp-sql-dev"

    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]


  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}