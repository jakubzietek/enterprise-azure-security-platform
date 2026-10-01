# ADR-003: Use Azure Storage and Entra ID for Terraform state

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

Terraform state contains sensitive infrastructure metadata and must not be stored locally or committed to Git.

The project plans to use GitHub-hosted Actions with OpenID Connect. A private-only state backend would require a private execution path, such as a self-hosted runner or private workstation, which adds cost and operational complexity to the lab.

## Decision

Terraform state will be stored in a dedicated Azure Storage account and accessed through Entra ID authentication and Azure RBAC.

The state account will retain its public network endpoint so that GitHub-hosted Actions can reach it. Anonymous blob access and shared-key authentication will be disabled. State access will be limited to the Terraform operator and the GitHub Actions workload identity through the required Storage Blob data-plane role.

Blob versioning and soft delete will be enabled for state recovery.

## Consequences

- The state account is an explicit exception to the private application data-tier pattern in ADR-001.
- A public network endpoint does not make Terraform state public: access still requires an authenticated Entra identity with the required data-plane role.
- GitHub Actions can use short-lived OIDC credentials without storing an Azure client secret.
- A future production implementation should reassess a private-only backend with a self-hosted runner or another approved private execution path.
