# ADR-002: Separate the student lab from the production reference design

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

The project needs to demonstrate an enterprise security architecture without representing cost-prohibitive services as permanently deployed in an Azure for Students lab.

The implementation is limited to one subscription, finite Azure credits, and short-lived resources.

## Decision

The lab will use one Azure subscription with logical resource-group separation. It will implement controls that can be validated within the budget: Terraform, managed identities, RBAC, GitHub OIDC, private application data access, policy, and telemetry.

The production reference design will use separate subscriptions, hub-and-spoke networking, Application Gateway with WAF, and centralized Azure Firewall egress.

Direct HTTPS access to App Service is accepted for the lab. Application Gateway WAF and Azure Firewall will not be represented as continuously deployed lab controls.

## Consequences

- Repository documentation must distinguish implemented controls from planned controls and production-reference controls.
- WAF or Firewall may be deployed temporarily for a documented GAME DAY, then removed.
- The lab remains technically credible without paying to run enterprise components continuously.
