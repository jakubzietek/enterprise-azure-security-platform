resource "azurerm_virtual_network" "dev" {
  name                = "vnet-ecsp-dev"
  location            = data.azurerm_resource_group.dev.location
  resource_group_name = data.azurerm_resource_group.dev.name

  address_space = ["10.20.0.0/16"]

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_subnet" "app_integration" {
  name                 = "snet-app-integration"
  resource_group_name  = data.azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.20.1.0/24"]

  delegation {
    name = "app-service-delegation"

    service_delegation {
      name = "Microsoft.Web/serverFarms"

      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }

  }

}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = data.azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.20.2.0/24"]

  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"

}

resource "azurerm_network_security_group" "app_integration" {
  name                = "nsg-snet-app-integration"
  location            = data.azurerm_resource_group.dev.location
  resource_group_name = data.azurerm_resource_group.dev.name

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }

}

resource "azurerm_network_security_rule" "app_to_private_endpoints" {
  name                       = "Allow-App-To-PrivateEndpoints"
  priority                   = 100
  direction                  = "Outbound"
  access                     = "Allow"
  protocol                   = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = "*"
  destination_address_prefix = "10.20.2.0/24"

  resource_group_name         = data.azurerm_resource_group.dev.name
  network_security_group_name = azurerm_network_security_group.app_integration.name

}

resource "azurerm_network_security_rule" "app_deny_other_vnet" {
  name                       = "Deny-App-To-Other-VNet"
  priority                   = 4000
  direction                  = "Outbound"
  access                     = "Deny"
  protocol                   = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = "*"
  destination_address_prefix = "VirtualNetwork"

  resource_group_name         = data.azurerm_resource_group.dev.name
  network_security_group_name = azurerm_network_security_group.app_integration.name

}

resource "azurerm_subnet_network_security_group_association" "app_integration" {
  subnet_id                 = azurerm_subnet.app_integration.id
  network_security_group_id = azurerm_network_security_group.app_integration.id

}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-snet-private-endpoints"
  location            = data.azurerm_resource_group.dev.location
  resource_group_name = data.azurerm_resource_group.dev.name

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }
}

resource "azurerm_network_security_rule" "private_endpoints_from_app" {
  name                       = "Allow-From-App-Integration"
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = "10.20.1.0/24"
  destination_address_prefix = "*"

  resource_group_name         = data.azurerm_resource_group.dev.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

resource "azurerm_network_security_rule" "private_endpoints_deny_other_vnet" {
  name                       = "Deny-Other-VNet"
  priority                   = 4000
  direction                  = "Inbound"
  access                     = "Deny"
  protocol                   = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = "VirtualNetwork"
  destination_address_prefix = "*"

  resource_group_name         = data.azurerm_resource_group.dev.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}