# Identity and CI Authentication

The project separates human administration, CI deployment, and application workload access.

## Identities

| Identity | Purpose | Authentication |
|---|---|---|
| Human operator | Bootstrap and administrative operations | Azure CLI / Entra ID |
| `id-ecsp-github-ci` | Terraform plan and DEV deployment from GitHub Actions | GitHub OIDC federation |
| `id-ecsp-app-dev` | DEV application workload identity | Azure Managed Identity |

The identities are intentionally separate so that compromise of one identity does not automatically provide the permissions of another.

## GitHub OIDC flow

```text
GitHub Actions
      |
      | requests OIDC token
      v
GitHub OIDC issuer
      |
      | signed token
      v
Microsoft Entra ID
      |
      | validates issuer, subject and audience
      v
id-ecsp-github-ci
      |
      +--> Storage Blob Data Contributor
      |      Terraform state container
      |
      +--> Contributor
             rg-ecsp-dev
```

The federated credential trusts:

```text
Issuer:
https://token.actions.githubusercontent.com

Audience:
api://AzureADTokenExchange

Subject:
repo:jakubzietek@258780055/enterprise-azure-security-platform@1392572356:ref:refs/heads/main
```

This restricts the Azure trust relationship to the configured GitHub repository and `main` branch.

## CI permissions

`id-ecsp-github-ci` has two Azure RBAC assignments:

| Scope | Role | Purpose |
|---|---|---|
| `rg-ecsp-dev` | Contributor | Manage DEV infrastructure |
| `tfstate` Blob container | Storage Blob Data Contributor | Read and update Terraform state |

The CI identity is not granted `Owner` or RBAC administration permissions.

Role assignments remain part of the platform/bootstrap boundary rather than the DEV deployment lifecycle.

## Terraform ownership

Terraform state is separated by lifecycle:

```text
bootstrap.tfstate
└── Terraform backend infrastructure

identity.tfstate
├── CI managed identity
├── GitHub federated credential
├── CI RBAC assignments
├── identity Resource Group
└── DEV deployment Resource Group

dev.tfstate
└── DEV workload resources
```

The DEV root references `rg-ecsp-dev` rather than owning it. This prevents destroying DEV workload state from also removing the scope that GitHub requires to recreate the environment.

## GitHub Actions behavior

Pull requests run static validation only:

```text
terraform fmt
terraform validate
TFLint
Checkov
```

Pushes to `main` additionally authenticate to Azure through OIDC and run an authenticated Terraform plan.

DEV deployment is manually triggered with `workflow_dispatch`. The workflow creates a saved Terraform plan and applies that plan after successful OIDC authentication.

No Azure client secret is stored in the repository or GitHub Actions.

## Validation

The following paths have been validated:

- GitHub Actions successfully authenticates to Azure through OIDC.
- GitHub Actions can initialize the Entra-authenticated remote backend.
- GitHub Actions can read DEV Terraform state.
- An authenticated Terraform plan completes successfully.
- A manually triggered Terraform apply successfully deploys DEV infrastructure using the CI identity.

A denied-access test is used to verify that the CI identity cannot access resources outside its assigned DEV scope.
