resource "azurerm_resource_group" "tfstate" {
  name     = "rg-ecsp-tfstate"
  location = "Poland Central"

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "bootstrap"
    managed_by  = "terraform"
  }
}

resource "azapi_resource" "tfstate" {
  type      = "Microsoft.Storage/storageAccounts@2026-04-01"
  name      = "stecsptfstate"
  parent_id = azurerm_resource_group.tfstate.id
  location  = azurerm_resource_group.tfstate.location

  body = {
    kind = "StorageV2"

    sku = {
      name = "Standard_LRS"
    }

    properties = {
      accessTier                   = "Hot"
      allowBlobPublicAccess        = false
      allowSharedKeyAccess         = false
      minimumTlsVersion            = "TLS1_2"
      supportsHttpsTrafficOnly     = true
      publicNetworkAccess          = "Enabled"
      defaultToOAuthAuthentication = true

    }
  }

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "bootstrap"
    managed_by  = "terraform"
  }

}

resource "azapi_resource" "blob_service" {
  type      = "Microsoft.Storage/storageAccounts/blobServices@2026-04-01"
  name      = "default"
  parent_id = azapi_resource.tfstate.id

  body = {
    properties = {
      isVersioningEnabled = true

      deleteRetentionPolicy = {
        enabled              = true
        days                 = 7
        allowPermanentDelete = false
      }

      containerDeleteRetentionPolicy = {
        enabled              = true
        days                 = 7
        allowPermanentDelete = false
      }
    }
  }

}

resource "azapi_resource" "tfstate_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2026-04-01"
  name      = "tfstate"
  parent_id = azapi_resource.blob_service.id

  body = {
    properties = {
      publicAccess = "None"
    }
  }
}