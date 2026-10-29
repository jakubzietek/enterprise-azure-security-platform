resource "azurerm_storage_account" "app" {
  # checkov:skip=CKV_AZURE_3:Secure transfer is explicitly enabled via https_traffic_only_enabled.
  # checkov:skip=CKV_AZURE_35:Public network access is disabled; Storage firewall default action is not used for the private-only data path.
  # checkov:skip=CKV_AZURE_33:Queue service is not used by this workload; service telemetry is implemented in the monitoring milestone.
  # checkov:skip=CKV2_AZURE_1:CMK is outside the current lab baseline; Azure-managed encryption is used.
  # checkov:skip=CKV2_AZURE_18:CMK is outside the current lab baseline; Azure-managed encryption is used.
  # checkov:skip=CKV2_AZURE_8:This account stores application data, not Azure activity logs; the application container is explicitly private.
  # checkov:skip=CKV2_AZURE_38:Blob soft delete is intentionally disabled in disposable DEV; the environment is frequently rebuilt and contains no production data requiring recovery.
  # checkov:skip=CKV_AZURE_206:LRS is intentionally used in disposable DEV to minimize cost; production storage would use an appropriate redundant replication tier.
  # checkov:skip=CKV_AZURE_59:Public network access is explicitly disabled with public_network_access = "Disabled"; this finding is a scanner mismatch with the current AzureRM configuration.

  name                = "stecspappdevjz"
  resource_group_name = data.azurerm_resource_group.dev.name
  location            = data.azurerm_resource_group.dev.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

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

resource "azurerm_storage_container" "app_data" {
  # checkov:skip=CKV2_AZURE_21:Blob data-plane logging is implemented in the M6 telemetry milestone.
  name = "app-data"

  storage_account_id = azurerm_storage_account.app.id

  container_access_type = "private"



}