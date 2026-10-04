output "resource_group_name" {
  description = "Name of the DEV resource group"
  value       = azurerm_resource_group.dev.name
}

output "resource_group_id" {
  description = "Resource ID of the DEV resource group"
  value       = azurerm_resource_group.dev.id

}