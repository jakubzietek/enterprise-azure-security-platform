resource "azurerm_resource_group" "identity" {
  name     = "rg-ecsp-identity"
  location = "Poland Central"

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "platform"
    managed_by  = "terraform"
  }

}

resource "azurerm_user_assigned_identity" "github_ci" {

  name                = "id-ecsp-github-ci"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "platform"
    purpose     = "github-ci"
    managed_by  = "terraform"
  }

}

resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "fic-ecsp-github-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_ci.id

  issuer   = "https://token.actions.githubusercontent.com"
  audience = ["api://AzureADTokenExchange"]

  subject = "repo:jakubzietek@258780055/enterprise-azure-security-platform@1392572356:ref:refs/heads/main"

}

resource "azurerm_resource_group" "dev_scope" {
  name     = "rg-ecsp-dev"
  location = "Poland Central"

  tags = {
    project     = "enterprise-cloud-security-platform"
    environment = "dev"
    managed_by  = "terraform"
  }
}

data "azurerm_storage_account" "tfstate" {
  name                = "stecsptfstate"
  resource_group_name = "rg-ecsp-tfstate"
}

data "azurerm_storage_container" "tfstate" {

  name               = "tfstate"
  storage_account_id = data.azurerm_storage_account.tfstate.id
}


resource "azurerm_role_assignment" "github_ci_dev_contributor" {
  scope                = azurerm_resource_group.dev_scope.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id

}

resource "azurerm_role_assignment" "github_ci_state_blob" {
  scope                = data.azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id

}