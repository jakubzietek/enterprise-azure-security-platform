# Security Requirements

This document defines the security baseline used for the Azure DEV environment.

The controls are based on the project threat model and are implemented where practical in the current lab. Production-only controls are documented separately where cost or operational complexity would not add useful validation.

## Identity and deployment

- Infrastructure is managed with Terraform.
- Terraform state is stored remotely in Azure Blob Storage and is not committed to Git.
- GitHub Actions authenticates to Azure through OIDC federation rather than a client secret.
- CI permissions are limited to the DEV deployment scope and Terraform state access.
- Human administration, CI deployment and application workload access use separate identities.
- The application uses a managed identity instead of stored Azure credentials.

## Data access

- Azure Storage, Key Vault and Azure SQL are accessed through Private Endpoints and Private DNS.
- Public network access is disabled on those data services.
- Storage Shared Key authentication is disabled.
- Azure SQL uses Entra-only authentication.
- Application permissions follow least privilege.

Current application permissions are limited to:

- Blob access on the required Storage container
- Key Vault secret reads
- SQL `SELECT` and `INSERT` on the required table

Negative tests verify that broader Storage enumeration, Key Vault writes and SQL deletes are denied.

## Application and network

- App Service enforces HTTPS.
- FTP deployment is disabled.
- App Service uses VNet Integration for access to private services.
- Application and Private Endpoint traffic is separated into dedicated subnets.
- NSGs restrict unintended VNet traffic.

The App Service frontend remains publicly reachable in DEV for validation. Production ingress would require additional controls such as authenticated access and WAF-controlled exposure.

## Governance

Azure Policy enforces selected DEV guardrails:

- required `environment` tag
- Storage public network access disabled
- Key Vault public network access disabled
- App Service HTTPS-only

Policy enforcement is treated as an additional platform control rather than relying only on Terraform configuration.

## CI security

Terraform changes are checked through GitHub Actions with:

```text id="fb4myy"
terraform fmt
terraform validate
TFLint
Checkov
```

Checkov is version-pinned in CI.

Security scanner exceptions are documented beside the affected Terraform resource with the reason the control is not applicable or is intentionally different in DEV.

An intentionally insecure SSH rule was used to verify that the CI security gate blocks unsafe Terraform before deployment.

## Logging and detection

Security-relevant telemetry is centralized in Log Analytics.

Collected sources include:

- Azure Activity Log
- Key Vault audit events
- Azure SQL security auditing
- Storage Blob operations
- App Service HTTP logs

KQL detections cover selected identity and authorization events, including denied Key Vault secret writes and Azure RBAC assignment changes.

## DEV boundary

The environment is designed to be disposable and cost-conscious.

The following are intentional DEV trade-offs:

- public App Service ingress
- single-instance B1 App Service plan
- Azure SQL Basic tier
- Storage LRS
- Key Vault purge protection disabled
- shorter Log Analytics retention

These are not intended as production defaults.

Production design would apply stronger availability, recovery, ingress, monitoring and organizational controls based on workload requirements.
