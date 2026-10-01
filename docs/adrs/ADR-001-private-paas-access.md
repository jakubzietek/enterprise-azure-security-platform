# ADR-001: Use private access for application PaaS services

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

The application processes customer financial records and uses Azure SQL, an application Storage account, and Key Vault. Allowing public network access to these services would increase the attack surface and conflict with the intended private data-tier design.

## Decision

Azure SQL, the application Storage account, and Key Vault will use Private Endpoints and Private DNS. Public network access will be disabled.

App Service will use VNet Integration for outbound connectivity to these services and a managed identity for authentication.

## Consequences

- Private DNS resolution and private connectivity must be validated before the application is considered functional.
- Network access does not replace authorization. Data-plane access will still use least-privilege RBAC.
- Private Endpoints have a cost and will be removed when the lab is no longer active.
- The Terraform state Storage account is not part of this decision; its access model is defined in ADR-003.
