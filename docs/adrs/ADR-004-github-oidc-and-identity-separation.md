# ADR-004: Use GitHub OIDC and separate CI and workload identities

- **Status:** Accepted
- **Date:** 2026-10-06

## Context

GitHub Actions needs access to Azure for Terraform plan and deployment operations.

Using a client secret would introduce a long-lived credential that must be stored and rotated. The CI identity also has different responsibilities and lifecycle requirements from the application workload identity.

## Decision

GitHub Actions authenticates to Azure through OpenID Connect federation using the user-assigned managed identity `id-ecsp-github-ci`.

The federated credential trusts the `main` branch of this repository. No Azure client secret is stored in GitHub.

The CI identity receives:

- `Contributor` on `rg-ecsp-dev`;
- `Storage Blob Data Contributor` on the Terraform state container.

The CI identity is not granted `Owner` or a role that allows it to create Azure RBAC assignments.

The DEV application uses a separate managed identity, `id-ecsp-app-dev`. Application data-plane permissions will be added only when the relevant services are deployed.

`rg-ecsp-dev` is owned by the platform Terraform root so that the CI deployment scope persists independently of the DEV workload state.

## Consequences

- GitHub Actions uses short-lived federated credentials instead of a stored Azure secret.
- CI permissions are limited to DEV infrastructure and Terraform state access.
- CI cannot create or modify Azure role assignments with its current permissions.
- Human, CI, and application identities remain separate.
- Pull requests run static Terraform checks without Azure authentication.
- Pushes to `main` can run an authenticated Terraform plan.
- DEV apply is manually triggered through GitHub Actions.
- Application identity permissions will be introduced with the services that require them.
