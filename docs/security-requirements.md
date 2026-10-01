# Security Requirements

This document defines the intended security baseline for the FinTechCo Azure Enterprise Cloud Security Platform. It reflects the architecture and initial threat model; the controls below are planned and will be implemented progressively through later milestones.

## Identity and deployment

- Infrastructure will be deployed with Terraform. Terraform state will be stored remotely and will not be committed to the repository.
- GitHub Actions will authenticate to Azure through OpenID Connect workload federation. Azure client secrets will not be used for CI/CD authentication.
- CI/CD permissions will be limited to the repository, environment, and Azure scope required for deployment.
- Human, workload, and CI identities will follow least privilege. Broad administrative roles will require justification.

## Workload and data protection

- The application will use a managed identity to access Azure SQL, the application Storage account, and Key Vault.
- Application code, Terraform configuration, and GitHub Actions workflows will not contain long-lived credentials.
- Azure SQL, the application Storage account, and Key Vault will be accessed through Private Endpoints and Private DNS. Public network access will be disabled.
- The application will enforce HTTPS, validate input, use parameterized database queries, and authorize access to customer data.

## Governance and monitoring

- Azure Policy will enforce selected guardrails, including restrictions on public access to sensitive application PaaS services.
- Changes to RBAC, Azure Policy, diagnostic settings, and public-access configuration will be logged in Log Analytics.
- Detection content will be based on the threat model and will cover material identity, configuration, and data-access events.
- Terraform and workflow changes will be reviewed through pull requests and checked with Terraform validation, TFLint, and Checkov.

## Lab boundary

The lab is designed to implement the private application data tier, managed identities, RBAC, Terraform, GitHub OIDC, policy, and telemetry controls. Application Gateway WAF and centralized Azure Firewall egress remain part of the production reference design unless temporarily deployed for a documented validation exercise.

Terraform state is handled separately in ADR-003 because GitHub-hosted Actions require a different access model from the private application data tier.
