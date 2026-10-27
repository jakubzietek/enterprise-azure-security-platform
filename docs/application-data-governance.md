# Application, Data and Governance

## Overview

The application runs on Azure App Service and accesses Azure Storage, Key Vault and Azure SQL using a user-assigned managed identity.

The design focuses on:

- private access to PaaS data services,
- credential-free application authentication,
- least-privilege authorization,
- preventive governance through Azure Policy.

## Architecture

App Service uses VNet Integration for outbound connectivity.

Storage, Key Vault and Azure SQL are accessed through Private Endpoints with Private DNS:

- `privatelink.blob.core.windows.net`
- `privatelink.vaultcore.azure.net`
- `privatelink.database.windows.net`

Public network access is disabled for all three data services.

The application continues to use the standard Azure service FQDNs, which resolve to private IP addresses from inside the VNet.

## Managed Identity and Access Control

The App Service uses the user-assigned managed identity:

```text
id-ecsp-app-dev
```

No Storage keys, SAS tokens, Key Vault credentials or SQL passwords are stored in the application.

Access is scoped as follows:

- Storage: `Storage Blob Data Contributor` at container scope
- Key Vault: `Key Vault Secrets User`
- Azure SQL: database principal with `SELECT` and `INSERT` on the required table only

## Validation

### Storage

The application successfully uploaded and downloaded a validation blob using managed identity authentication.

A negative test attempted to enumerate containers at Storage Account scope and returned:

```text
403 Forbidden
```

This confirmed that the identity could access the required container without broader account-level permissions.

### Key Vault

The application successfully retrieved a validation secret using its managed identity over the private endpoint.

The validation response exposed secret metadata only and did not return the secret value.

### Azure SQL

The application authenticated to Azure SQL using managed identity, inserted a validation row and read it back successfully.

A negative authorization test attempted a `DELETE` operation. Azure SQL rejected the request because the identity had only `SELECT` and `INSERT` permissions.

## Azure Policy

Four policy controls are assigned at the DEV resource-group scope:

- require the `environment` tag,
- deny Storage Accounts with public network access,
- deny Key Vaults with public network access,
- require HTTPS-only App Service applications.

A deployment without the required `environment` tag was intentionally attempted and blocked by Azure Policy. The same deployment succeeded after the compliant tag was added.

This provides a governance layer above the Terraform configuration and helps prevent insecure configuration drift.

## Environment-specific Decisions

The environment is intentionally cost-conscious and disposable.

Key differences from a production deployment include:

- Key Vault purge protection disabled to allow lab teardown,
- Azure SQL Basic tier,
- LRS Storage redundancy,
- public App Service ingress retained for testing.

A production design would use stronger recovery, availability and ingress controls based on workload requirements.

## CI Validation

Terraform changes are validated through GitHub Actions using:

- `terraform fmt`
- `terraform validate`
- TFLint
- Checkov
- authenticated `terraform plan`

Checkov exceptions are documented where controls are intentionally outside the current lab scope or are implemented in the centralized telemetry layer.
