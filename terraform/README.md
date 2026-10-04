# Terraform

Terraform configuration for the Azure Enterprise Cloud Security Platform.

The layout separates backend infrastructure from workload environments so application resources can be rebuilt without affecting the infrastructure that stores Terraform state.

## Structure

```text
terraform/
├── bootstrap/
│   ├── backend.tf
│   ├── main.tf
│   ├── provider.tf
│   └── versions.tf
│
├── environments/
│   └── dev/
│       ├── backend.tf
│       ├── locals.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── provider.tf
│       ├── variables.tf
│       └── versions.tf
│
└── modules/
```

`modules/` is currently empty and will be populated only when reusable infrastructure patterns emerge.

## Remote state

Terraform state is stored in Azure Blob Storage.

The backend currently uses separate state files:

```text
tfstate/
├── bootstrap.tfstate
└── dev.tfstate
```

`bootstrap.tfstate` manages the backend infrastructure itself.

`dev.tfstate` manages the DEV environment.

This allows the DEV environment to be destroyed and recreated independently of the Terraform backend.

## Backend security

The state Storage Account is configured with:

- Microsoft Entra ID authentication
- Azure RBAC for Blob access
- Shared Key authentication disabled
- anonymous Blob access disabled
- HTTPS-only access
- TLS 1.2 minimum
- Blob versioning
- 7-day Blob soft delete
- 7-day container soft delete

The Storage Account retains a public network endpoint in the lab.

This is an intentional exception to the private-PaaS pattern used for application data services. It keeps the backend compatible with local development and future GitHub-hosted runners while state access remains protected by Entra ID and Azure RBAC.

A production implementation could instead use a Private Endpoint with a private or self-hosted runner.

## Bootstrap

The backend was initially created using local Terraform state.

After the Azure Storage backend was available, the bootstrap state was migrated using:

```bash
terraform init -migrate-state
```

Local state files were removed after confirming that Terraform could read the remote state and produce a clean plan.

## Providers

The project currently uses:

- `hashicorp/azurerm` for standard Azure resources
- `Azure/azapi` for the Terraform state Storage Account and related ARM resources

Provider versions are constrained in Terraform configuration and resolved versions are stored in `.terraform.lock.hcl`.

The lock files are committed to the repository.

## AzAPI Storage Account

The state Storage Account was initially created with `azurerm_storage_account`.

Azure successfully created the account, but the AzureRM provider returned:

```text
Provider produced inconsistent result after apply
```

The resource existed in Azure but was not recorded in Terraform state.

An AzureRM import also failed while reconciling the Shared-Key-disabled Storage Account.

The resource was verified independently with Azure CLI, then management was switched to `azapi_resource` and the existing Storage Account was imported.

Azure's existing `blobServices/default` resource was also imported before applying the required versioning and retention settings.

This allowed the original security requirement to remain unchanged:

```text
Shared Key authentication = disabled
```

The incident is documented because it is a useful example of reconciling live Azure resources with Terraform state without unnecessarily recreating infrastructure.

## DEV environment

The DEV root currently establishes the environment pattern with:

```text
rg-ecsp-dev
```

It uses:

- its own remote state
- variables for configurable values
- locals for naming and common tags
- outputs for useful resource information

Additional application, identity and networking resources will be added in later stages.

## CI validation

Terraform configuration is validated through GitHub Actions.

The current workflow runs against both:

```text
terraform/bootstrap
terraform/environments/dev
```

and performs:

```text
terraform fmt -check
terraform init -backend=false
terraform validate
TFLint
Checkov
```

`terraform init -backend=false` is used because the current CI workflow performs static validation only and does not authenticate to Azure.

Azure authentication for GitHub Actions will be added separately using OIDC.

## State locking and rebuild validation

Remote state locking was tested using concurrent Terraform operations.

A second Terraform process was unable to acquire the DEV state lock while another operation was holding it.

The DEV environment was also destroyed and recreated successfully from Terraform configuration.

Destroying DEV did not affect the backend or `bootstrap.tfstate`.

## Repository safeguards

Terraform runtime and local state files are excluded from Git.

Relevant exclusions include:

```gitignore
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfplan

*.tfvars
*.tfvars.json
!*.example.tfvars

.terraformrc
terraform.rc
```

`.terraform.lock.hcl` is intentionally committed.

## Local workflow

Typical workflow:

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

Destructive changes should be reviewed first with:

```bash
terraform plan -destroy
```
