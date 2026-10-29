# Threat Model

**Project:** FinTechCo Azure Enterprise Cloud Security Platform  
**Method:** STRIDE  
**Environment:** Azure DEV / portfolio implementation  
**Last updated:** 2026-10-29

## 1. Scope

This threat model covers the main security boundaries of the implemented Azure environment:

- public access to the App Service;
- App Service access to Storage, Key Vault and Azure SQL;
- workload managed identity and Azure RBAC;
- GitHub Actions authentication to Azure;
- Terraform state and infrastructure changes;
- Azure control-plane activity;
- security telemetry and detection.

The environment is intentionally smaller than the production reference architecture. Controls such as Application Gateway WAF, centralized Azure Firewall egress, production HA and Microsoft Sentinel are not deployed permanently in DEV.

## 2. Trust boundaries

| ID | Boundary | Current protection |
|---|---|---|
| TB-1 | Internet → App Service | HTTPS-only; public DEV endpoint; application/data permissions limit blast radius |
| TB-2 | App Service → data services | VNet Integration, Private Endpoints, Private DNS, managed identity, least privilege |
| TB-3 | Human administrator → Azure | Entra ID authentication and Azure RBAC |
| TB-4 | GitHub Actions → Azure | OIDC workload federation, restricted federated subject, dedicated CI identity |
| TB-5 | Terraform → remote state | Azure Storage backend, Entra ID, RBAC, Shared Key disabled |
| TB-6 | Azure resources → Log Analytics | Diagnostic Settings and selected security telemetry |
| TB-7 | Workload → external destinations | Normal App Service outbound connectivity; centralized egress filtering is not implemented in DEV |

## 3. Key assets

| ID | Asset | Main concern |
|---|---|---|
| A-01 | Azure SQL data | Unauthorized read or modification |
| A-02 | Storage data | Unauthorized read, write or enumeration |
| A-03 | Key Vault secrets | Credential or secret disclosure |
| A-04 | Terraform state | Infrastructure disclosure or tampering |
| A-05 | Azure identities and RBAC | Privilege escalation |
| A-06 | GitHub Actions deployment identity | Unauthorized infrastructure deployment |
| A-07 | App Service and workload identity | Compromise of application access |
| A-08 | Security telemetry | Loss of visibility or auditability |

Risk ratings are qualitative and reflect the current DEV implementation.

---

## 4. Threat register

### TM-01 — CI/CD identity spoofing or OIDC trust misconfiguration

**STRIDE:** Spoofing, Elevation of Privilege  
**Initial risk:** High  
**Residual risk:** Medium  
**Status:** Partially validated

An overly broad federated credential or compromised deployment context could allow an attacker to authenticate as the GitHub Actions identity.

Current controls:

- GitHub Actions uses OIDC instead of an Azure client secret.
- The federated credential is restricted to this repository and `main`.
- CI uses a dedicated managed identity.
- The identity has `Contributor` only on the DEV resource group plus Blob access to Terraform state.
- It does not have `Owner` or RBAC administration permissions.

The legitimate GitHub workflow has been validated against Azure.

The remaining risk is primarily compromise of an already trusted GitHub context. Branch protection is not currently enforced on `main` and should be treated as an additional repository hardening control.

---

### TM-02 — Malicious Terraform or workflow change

**STRIDE:** Tampering, Elevation of Privilege  
**Initial risk:** High  
**Residual risk:** Medium  
**Status:** Validated

A malicious infrastructure change could expose resources, weaken authorization or remove security controls.

Current controls:

- `terraform fmt`
- `terraform validate`
- TFLint
- Checkov
- pinned Checkov version
- Terraform plan before deployment
- manual DEV apply
- OIDC-based Azure authentication

The security gate was explicitly tested with a Terraform NSG rule allowing SSH from the Internet.

Terraform validation accepted the configuration, while Checkov detected `CKV_AZURE_10` and failed the pull-request pipeline. Removing the insecure rule returned the pipeline to green.

The CI security gate therefore prevents this class of known insecure Terraform from reaching deployment through the tested workflow.

---

### TM-03 — Loss of security visibility

**STRIDE:** Repudiation, Tampering  
**Initial risk:** High  
**Residual risk:** Medium  
**Status:** Partially validated

An attacker or privileged operator could reduce auditability by changing logging, diagnostic settings or other security controls.

Current telemetry includes:

- Azure Activity Log
- Key Vault audit events
- Azure SQL security auditing
- Storage Blob operations
- App Service HTTP logs

Events are centralized in Log Analytics.

Azure control-plane activity provides visibility into security-sensitive configuration changes, but DEV does not implement a complete detection set for every possible telemetry-disablement scenario.

Production would add stronger monitoring of changes to logging configuration and alerting infrastructure.

---

### TM-04 — Public exposure of Storage, Key Vault or Azure SQL

**STRIDE:** Information Disclosure, Tampering  
**Initial risk:** High  
**Residual risk:** Low–Medium  
**Status:** Validated

A configuration error could expose sensitive PaaS services through their public endpoints.

Current controls:

- public network access disabled;
- Private Endpoints;
- Private DNS;
- App Service VNet Integration;
- managed identity;
- least-privilege authorization;
- Azure Policy guardrails for Storage and Key Vault public access.

Private connectivity has been validated from the application.

The DNS dependency was also tested by removing a Private DNS VNet link. The service then resolved through the public path and the intended private connection failed. Restoring the link restored private connectivity.

---

### TM-05 — Terraform state or secret leakage

**STRIDE:** Information Disclosure, Tampering  
**Initial risk:** High  
**Residual risk:** Low–Medium  
**Status:** Validated

Terraform state contains infrastructure metadata and must be treated as sensitive.

Current controls:

- remote Azure Blob backend;
- Entra ID authentication;
- Shared Key disabled;
- least-privilege Blob RBAC;
- state excluded from Git;
- Terraform variable files and common secret formats excluded from Git;
- backend Blob versioning and retention;
- no long-lived Azure CI credential.

The repository and Git history were scanned before public release and no secrets were detected.

The backend retains a public network endpoint so GitHub-hosted runners can reach it. Authorization remains enforced through Entra ID and Azure RBAC.

---

### TM-06 — Excessive Azure permissions

**STRIDE:** Elevation of Privilege, Tampering  
**Initial risk:** High  
**Residual risk:** Medium  
**Status:** Validated

Excessive permissions would increase the impact of a compromised application or CI identity.

The project separates:

- human administration;
- GitHub CI deployment;
- application workload access.

Application permissions are limited to:

- Blob access on the required container;
- Key Vault secret reads;
- SQL `SELECT` and `INSERT` on the required table.

Negative tests confirmed that the application identity cannot:

- enumerate Storage containers;
- write Key Vault secrets;
- execute SQL `DELETE`.

Azure RBAC assignment changes are also visible through an associated KQL detection.

The CI identity still has `Contributor` over the DEV resource group, which is a deliberate deployment capability and remains a meaningful privilege boundary.

---

### TM-07 — Key Vault secret compromise

**STRIDE:** Information Disclosure, Elevation of Privilege  
**Initial risk:** High  
**Residual risk:** Low–Medium  
**Status:** Validated

A compromised or overprivileged workload identity could retrieve or modify protected secret material.

Current controls:

- public network access disabled;
- Private Endpoint and Private DNS;
- managed identity authentication;
- `Key Vault Secrets User` authorization;
- audit logging;
- no secret values stored in application configuration or Terraform outputs.

The application can read the required secret but a controlled `SecretSet` attempt returns `403 Forbidden`.

The denied write is visible in `AZKVAuditLogs` and is covered by a KQL detection.

Purge protection is intentionally disabled in disposable DEV and would be enabled in production.

---

### TM-08 — Web application compromise or unauthorized use

**STRIDE:** Tampering, Information Disclosure, Elevation of Privilege  
**Initial risk:** High  
**Residual risk:** Medium–High  
**Status:** Accepted DEV limitation

The application is intentionally reachable from the Internet so the environment can be validated externally.

The current sample application does not implement App Service Authentication and is not protected by a WAF.

Some validation endpoints trigger operations against the data tier, so public application access is a real security boundary rather than a scanner false positive.

Blast radius is reduced through:

- HTTPS-only access;
- managed identity instead of embedded credentials;
- private data services;
- least-privilege Storage, Key Vault and SQL permissions;
- parameterized SQL operations;
- synthetic test data only.

A production application would add authenticated access, application authorization and WAF-controlled ingress.

The current application should therefore not be treated as a production-ready internet-facing service.

---

### TM-09 — Workload identity abuse

**STRIDE:** Spoofing, Elevation of Privilege, Information Disclosure  
**Initial risk:** High  
**Residual risk:** Medium  
**Status:** Partially validated

If the App Service were compromised, an attacker could operate with the permissions assigned to its managed identity.

The primary blast-radius controls are:

- separate workload identity;
- no embedded Azure credentials;
- container-scoped Storage access;
- read-only Key Vault secret access;
- restricted SQL permissions;
- private network paths to data services.

Negative authorization tests confirm that the identity cannot perform selected higher-privilege operations.

The project does not claim that managed identity prevents workload compromise. Its purpose here is to remove stored credentials and limit what a compromised workload could do.

---

### TM-10 — Unrestricted outbound network access

**STRIDE:** Information Disclosure  
**Initial risk:** Medium  
**Residual risk:** Medium  
**Status:** Accepted DEV limitation

A compromised application could initiate outbound connections to an external destination.

The DEV environment does not deploy Azure Firewall or another centralized egress filtering service.

This is intentional because maintaining a production-style egress stack would add significant cost without materially improving the other security controls being demonstrated.

A production implementation would evaluate:

- centralized egress routing;
- Azure Firewall or equivalent controls;
- destination restrictions;
- network telemetry;
- detection of suspicious outbound traffic.

The lack of centralized egress enforcement remains an explicit limitation of the DEV environment.

---

## 5. Current security posture

The strongest validated control paths are:

```text
GitHub change
→ Terraform validation
→ TFLint
→ Checkov
→ insecure configuration blocked
```

```text
App Service
→ managed identity
→ Private Endpoint
→ Storage / Key Vault / Azure SQL
→ least-privilege authorization
```

```text
Security-relevant Azure event
→ diagnostic telemetry
→ Log Analytics
→ KQL investigation / detection
```

The project deliberately does not claim production parity.

The major remaining differences are:

- public and unauthenticated App Service ingress;
- no WAF;
- no centralized outbound firewall;
- DEV-grade availability and recovery settings;
- shorter telemetry retention;
- no Microsoft Sentinel deployment;
- no enforced GitHub branch protection.

## 6. Review criteria

A control is described as **Validated** only where its expected behavior was tested.

**Partially validated** means the main control exists but not every threat path was exercised.

**Accepted DEV limitation** means the exposure is intentionally retained because addressing it would add disproportionate cost or scope to the portfolio environment.

The threat model should be updated when the architecture or security boundaries materially change.
