output "resource_group_name" {
  description = "Name of the DEV resource group."
  value       = data.azurerm_resource_group.dev.name
}

output "resource_group_id" {
  description = "Resource ID of the DEV resource group."
  value       = data.azurerm_resource_group.dev.id
}

output "app_identity_client_id" {
  description = "Client ID of the DEV application managed identity."
  value       = azurerm_user_assigned_identity.app.client_id
}

output "app_identity_principal_id" {
  description = "Principal ID of the DEV application managed identity."
  value       = azurerm_user_assigned_identity.app.principal_id
}