resource "azurerm_key_vault" "app" {
  name                = "kv-ecsp-dev-jz"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name  = "standard"

  rbac_authorization_enabled = true

  public_network_access_enabled = false

  soft_delete_retention_days = 7

  purge_protection_enabled = false

  network_acls {
    bypass         = "None"
    default_action = "Deny"
  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-ecsp-keyvault-dev"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  subnet_id = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-ecsp-keyvault-dev"
    private_connection_resource_id = azurerm_key_vault.app.id

    subresource_names = ["vault"]

    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "pdzg-ecsp-keyvault-dev"

    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }
}