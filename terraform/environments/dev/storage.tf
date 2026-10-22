resource "azurerm_storage_account" "app" {
  name                = "stecspappdevjz"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  public_network_access = "Disabled"

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }


}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-ecsp-storage-blob-dev"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  subnet_id = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-ecsp-storage-blob-dev"
    private_connection_resource_id = azurerm_storage_account.app.id


    subresource_names = ["blob"]

    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "pdzg-ecsp-storage-blob-dev"

    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }
}