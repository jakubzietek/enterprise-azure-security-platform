data "azurerm_policy_definition" "require_environment_tag" {
  name = "871b6d14-10aa-478d-b590-94f262ecfa99"

}

data "azurerm_policy_definition" "storage_public_network_disabled" {
  name = "b2982f36-99f2-4db5-8eff-283140c09693"

}


data "azurerm_policy_definition" "key_vault_public_network_disabled" {
  name = "405c5871-3e91-4644-8a63-58e19d68ff5b"
}

data "azurerm_policy_definition" "app_service_https_only" {
  name = "a4af4a39-4135-47fb-b175-47fbdf85311d"
}

resource "azurerm_resource_group_policy_assignment" "require_environment_tag" {
  name                 = "require-environment-tag"
  display_name         = "Require environment tag"
  resource_group_id    = data.azurerm_resource_group.dev.id
  policy_definition_id = data.azurerm_policy_definition.require_environment_tag.id

  parameters = jsonencode({
    tagName = {
      value = "environment"
    }
  })

  non_compliance_message {
    content = "Resources in the ECSP DEV environment must include the 'environment' tag."
  }

}

resource "azurerm_resource_group_policy_assignment" "storage_public_network_disabled" {
  name                 = "deny-storage-public-network"
  display_name         = "Deny Storage public network access"
  resource_group_id    = data.azurerm_resource_group.dev.id
  policy_definition_id = data.azurerm_policy_definition.storage_public_network_disabled.id

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })

  non_compliance_message {
    content = "Storage accounts in ECSP DEV must have public network access disabled."
  }
}

resource "azurerm_resource_group_policy_assignment" "key_vault_public_network_disabled" {
  name                 = "deny-keyvault-public-network"
  display_name         = "Deny Key Vault public network access"
  resource_group_id    = data.azurerm_resource_group.dev.id
  policy_definition_id = data.azurerm_policy_definition.key_vault_public_network_disabled.id

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })

  non_compliance_message {
    content = "Key Vaults in ECSP DEV must have public network access disabled."
  }
}

resource "azurerm_resource_group_policy_assignment" "app_service_https_only" {
  name                 = "deny-appservice-http"
  display_name         = "Require HTTPS-only for App Service"
  resource_group_id    = data.azurerm_resource_group.dev.id
  policy_definition_id = data.azurerm_policy_definition.app_service_https_only.id

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })

  non_compliance_message {
    content = "App Service apps in ECSP DEV must enforce HTTPS-only access."
  }
}