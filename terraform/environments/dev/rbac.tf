resource "azurerm_role_assignment" "app_blob_data_contributor" {
  scope                = azurerm_storage_container.app_data.id
  role_definition_name = "Storage Blob Data Contributor"

  principal_id   = azurerm_user_assigned_identity.app.principal_id
  principal_type = "ServicePrincipal"

}

resource "azurerm_role_assignment" "app_key_vault_secrets_user" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"

  principal_id   = azurerm_user_assigned_identity.app.principal_id
  principal_type = "ServicePrincipal"

}