# Terraform

Terraform configuration for the Azure security platform.

The configuration is split into separate roots so backend infrastructure, CI identity and application resources can be managed independently.

## Layout

```text
terraform/
├── bootstrap/
│   ├── backend.tf
│   ├── main.tf
│   ├── provider.tf
│   └── versions.tf
│
├── platform/
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── versions.tf
│
└── environments/
    └── dev/
        ├── app.tf
        ├── backend.tf
        ├── dns.tf
        ├── keyvault.tf
        ├── main.tf
        ├── monitoring.tf
        ├── network.tf
        ├── outputs.tf
        ├── policy.tf
        ├── provider.tf
        ├── rbac.tf
        ├── sql.tf
        ├── storage.tf
        ├── variables.tf
        └── versions.tf
```

## Terraform roots

### `bootstrap`

Creates the infrastructure used to store Terraform state.

The backend Storage Account uses:

- Entra ID authentication
- Shared Key disabled
- anonymous Blob access disabled
- HTTPS only
- TLS 1.2 minimum
- Blob versioning
- 7-day Blob and container soft delete

Its public endpoint is intentionally retained so GitHub-hosted runners and local administration can reach the backend. Access to state is controlled with Entra ID and Azure RBAC.

### `platform`

Creates resources that must survive normal DEV rebuilds:

- GitHub Actions managed identity
- GitHub OIDC federated credential
- CI RBAC assignments
- identity resource group
- DEV deployment resource group

The CI identity has:

```text
Contributor
└── rg-ecsp-dev

Storage Blob Data Contributor
└── Terraform state container
```

It does not have `Owner` or permission to manage Azure RBAC.

### `environments/dev`

Contains the application environment:

- Linux App Service
- user-assigned managed identity
- VNet and NSGs
- Private Endpoints and Private DNS
- Storage
- Key Vault
- Azure SQL
- Azure Policy assignments
- Log Analytics and diagnostic settings

The DEV root references the resource group created by the platform root rather than owning it. Destroying the workload therefore does not remove the deployment boundary required to recreate it.

## State separation

The project uses separate state files:

```text
bootstrap.tfstate
identity.tfstate
dev.tfstate
```

This keeps different infrastructure lifecycles independent.

For example, the DEV application can be destroyed without removing either the Terraform backend or the GitHub deployment identity.

State files are not stored in Git.

## Authentication

Local administrative Terraform operations use the signed-in Azure CLI identity.

GitHub Actions uses workload identity federation:

```text
GitHub Actions
      ↓
GitHub OIDC token
      ↓
Microsoft Entra ID
      ↓
id-ecsp-github-ci
      ↓
Azure RBAC
```

No Azure client secret is required for CI.

The application uses a separate managed identity for access to Storage, Key Vault and Azure SQL.

## CI

GitHub Actions validates all three Terraform roots:

```text
terraform/bootstrap
terraform/platform
terraform/environments/dev
```

Pull requests run:

```bash
terraform fmt -check
terraform init -backend=false
terraform validate
tflint
checkov
```

Checkov is pinned in the workflow to keep security scanning reproducible.

Pushes to `main` run an authenticated Terraform plan for DEV using OIDC.

Applying DEV is a manual `workflow_dispatch` action.

## Security scanning

Checkov findings are handled individually.

Where a control can reasonably be implemented in DEV, it is implemented. Findings that are not applicable or represent intentional DEV trade-offs are suppressed beside the affected resource with an explanation.

Examples include:

- production HA requirements on low-cost DEV SKUs
- Key Vault purge protection in a disposable environment
- Storage LRS in DEV
- public App Service ingress retained for external testing

The CI security gate was validated with an intentionally insecure Internet-accessible SSH rule. Terraform validation passed, while Checkov blocked the change before deployment.

## Local workflow

For a Terraform root:

```bash
terraform fmt
terraform init
terraform validate
terraform plan
```

DEV also requires the Entra SQL administrator variables:

```bash
export TF_VAR_sql_entra_admin_login="$(az ad signed-in-user show --query userPrincipalName -o tsv)"
export TF_VAR_sql_entra_admin_object_id="$(az ad signed-in-user show --query id -o tsv)"
```

Before destructive operations:

```bash
terraform plan -destroy
```

The DEV environment is designed to be disposable. The bootstrap and platform roots should be treated separately because they contain infrastructure required to recreate DEV.
