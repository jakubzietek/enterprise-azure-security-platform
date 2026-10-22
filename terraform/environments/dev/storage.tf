resource "azurerm_storage_account" "app" {
  # checkov:skip=CKV_AZURE_3:Secure transfer is explicitly enabled via https_traffic_only_enabled.
  # checkov:skip=CKV_AZURE_35:Public network access is disabled; Storage firewall default action is not used for the private-only data path.
  # checkov:skip=CKV_AZURE_33:Queue service is not used by this workload; service telemetry is implemented in the monitoring milestone.
  # checkov:skip=CKV2_AZURE_1:CMK is outside the current lab baseline; Azure-managed encryption is used.
  # checkov:skip=CKV2_AZURE_18:CMK is outside the current lab baseline; Azure-managed encryption is used.
  
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