# Telemetry, Detection and DevSecOps Controls

## Overview

The platform centralizes security-relevant Azure telemetry in Log Analytics and applies threat-driven KQL detections to validate identity, authorization, and control-plane activity.

Infrastructure changes are also evaluated before deployment through a GitHub Actions pipeline combining Terraform validation, linting, static security analysis, and Azure OIDC authentication.

The design intentionally focuses on **high-value telemetry and preventative controls** rather than enabling every available diagnostic category.

---

## Security Telemetry

A dedicated Log Analytics workspace (`law-ecsp-dev`) receives selected telemetry from the application platform and supporting Azure services.

| Source | Telemetry |
|---|---|
| Azure Activity Log | Administrative, Security and Policy events |
| Azure Key Vault | `AuditEvent` |
| Azure SQL | `SQLSecurityAuditEvents` |
| Azure Storage Blob | Read, write and delete operations |
| Azure App Service | HTTP request logs |

Diagnostic settings for workload resources are managed through Terraform.

Subscription Activity Log forwarding is configured separately because the GitHub Actions deployment identity is intentionally scoped to the DEV resource group rather than granted subscription-level deployment permissions.

### Telemetry design principles

- Collect security-relevant events rather than all available logs.
- Centralize logs in Log Analytics for investigation and detection.
- Preserve least-privilege boundaries for the CI/CD identity.
- Keep ingestion and retention appropriate for a disposable development environment.
- Treat broader retention and additional telemetry as production hardening rather than baseline lab requirements.

---

## Detection Engineering

Custom KQL detections are stored under:

```text
detections/kql/
```

### Denied Key Vault secret write

`keyvault-denied-secret-write.kql`

Detects attempts to create or modify Key Vault secrets that are rejected with HTTP 403.

The application managed identity is intentionally granted permission to **read secrets but not modify them**. A denied `SecretSet` operation therefore provides a useful signal for:

- incorrect application behavior;
- privilege assumptions in automation;
- attempted misuse of the workload identity.

The detection was validated by deliberately attempting a secret write from the application identity and confirming that the operation was denied and visible in `AZKVAuditLogs`.

### Azure RBAC assignment change

`rbac-assignment-change.kql`

Detects successful creation or deletion of Azure RBAC role assignments through the Azure control plane.

Role assignment changes are security-sensitive because they can materially change access to cloud resources.

The query monitors:

```text
MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE
MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/DELETE
```

Validation was performed by temporarily assigning and subsequently removing a low-impact role, then confirming both events in `AzureActivity`.

### SQL security telemetry

Azure SQL auditing is enabled and forwarded to Log Analytics through `SQLSecurityAuditEvents`.

The application database identity was also tested against its intended least-privilege permissions. Allowed `SELECT` and `INSERT` operations succeeded, while an attempted `DELETE` operation was denied.

This provides data-plane evidence that the application's SQL permissions match the intended authorization model.

---

## DevSecOps Security Controls

Terraform changes are evaluated through GitHub Actions before deployment.

The validation pipeline performs:

```text
terraform fmt -check
terraform validate
TFLint
Checkov
```

Checkov is explicitly version-pinned to keep static security analysis reproducible across CI runs.

Security findings are handled as one of three categories:

1. configuration weaknesses that should be fixed;
2. intentional development-environment trade-offs;
3. scanner limitations or controls that do not apply to the workload.

Exceptions are documented directly beside the affected Terraform resource using Checkov suppression comments with a justification. This avoids weakening the entire pipeline while keeping accepted risks visible in code review.

Examples of intentional DEV exceptions include production availability controls such as zone redundancy and multi-instance App Service deployment.

---

## CI/CD Identity

GitHub Actions authenticates to Azure using **OpenID Connect federation** rather than stored Azure client secrets.

The deployment identity is scoped to the permissions required by the Terraform workflow.

The pipeline separates validation from deployment:

- pull requests run static Terraform and security validation;
- pushes to `main` can produce the DEV Terraform plan;
- DEV deployment is explicitly initiated through the workflow dispatch path.

This limits the effect of unreviewed changes and avoids unnecessary long-lived Azure credentials.

---

## Security Gate Validation

The Checkov control was tested using a deliberately insecure Terraform change.

A temporary NSG rule allowed inbound SSH from any source:

```text
Internet → TCP/22 → DEV NSG
```

The configuration remained syntactically valid, so Terraform validation succeeded.

Checkov detected the exposure through:

```text
CKV_AZURE_10
Ensure that SSH access is restricted from the internet
```

and caused the pull-request pipeline to fail.

The insecure resource was then removed and the same pipeline returned to a successful state.

This validated the intended control path:

```text
Terraform change
       ↓
GitHub pull request
       ↓
Terraform validation
       ↓
TFLint
       ↓
Checkov
       ↓
Unsafe change blocked before deployment
```

No intentionally insecure infrastructure was deployed during the test.

---

## Sentinel Decision

Microsoft Sentinel was evaluated but intentionally not deployed.

The objectives of this environment are cloud security engineering, infrastructure controls, telemetry design, and detection development rather than SIEM operations.

Log Analytics and KQL provide sufficient evidence that:

- required telemetry is collected;
- events can be investigated;
- security detections can be developed and validated.

In a production environment, the same detection logic could be operationalized through Sentinel analytics rules, alerting, incident creation, and automated response workflows.

---

## Production Considerations

A production implementation would additionally evaluate:

- private or WAF-controlled application ingress;
- authenticated application access;
- zone-redundant and multi-instance workloads;
- stronger storage and database durability;
- longer security-log retention;
- Defender for Cloud and SQL vulnerability assessment;
- Sentinel analytics rules and incident workflows;
- organization-wide Azure Policy and management-group controls.

The development environment intentionally keeps these controls separate from the baseline where their cost or operational complexity would not materially improve the security engineering objectives of the project.
