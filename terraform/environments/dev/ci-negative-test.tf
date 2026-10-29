resource "azurerm_network_security_rule" "ci_negative_test" {
  name                       = "TEMP-Allow-SSH-From-Internet"
  priority                   = 200
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name         = data.azurerm_resource_group.dev.name
  network_security_group_name = azurerm_network_security_group.app_integration.name
}
