output "github_ci_client_id" {
  description = "Client ID of the Github CI managed identity"
  value       = azurerm_user_assigned_identity.github_ci.client_id

}


output "github_ci_principal_id" {
  description = "Service principal object ID of the Github CI managed identity"
  value       = azurerm_user_assigned_identity.github_ci.principal_id

}


output "tenant_id" {
  description = "Microsoft Entra tenant ID"

  value = azurerm_user_assigned_identity.github_ci.tenant_id

}