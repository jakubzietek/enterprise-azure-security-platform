terraform {
  backend "azurerm" {
    storage_account_name = "stecsptfstate"
    container_name       = "tfstate"
    key                  = "identity.tfstate"

    use_azuread_auth = true
    use_cli          = true
  }
}