resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.dev.name

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.dev.name

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.dev.name

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                 = "link-vnet-ecsp-dev-blob"
  private_dns_zone_id  = azurerm_private_dns_zone.blob.id
  virtual_network_id   = azurerm_virtual_network.dev.id
  registration_enabled = false



}


resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                 = "link-vnet-ecsp-dev-sql"
  private_dns_zone_id  = azurerm_private_dns_zone.sql.id
  virtual_network_id   = azurerm_virtual_network.dev.id
  registration_enabled = false



}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                 = "link-vnet-ecsp-dev-keyvault"
  private_dns_zone_id  = azurerm_private_dns_zone.key_vault.id
  virtual_network_id   = azurerm_virtual_network.dev.id
  registration_enabled = false



}