resource "azurerm_resource_group" "dev" {
  name     = "rg-${local.project_name}-${local.environment}"
  location = var.location

  tags = local.common_tags

}