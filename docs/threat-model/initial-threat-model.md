## 1. Scope and assumptions

This document is an initial, architecture-driven STRIDE threat model for FinTechCo’s internet-facing Azure application platform.

It identifies material threats to customer financial data, identities, infrastructure configuration, Terraform state, CI/CD workflows and security telemetry. It records planned controls and validation actions; it does not claim that a control is implemented until validation evidence exists.

### In scope

- Public application ingress and the Internet-to-application trust boundary.
- App Service connectivity to Azure SQL, Storage Account and Key Vault.
- Private Endpoints, Private DNS and public-network-access controls.
- Azure management plane, Entra ID and Azure RBAC.
- GitHub Actions authentication to Azure using OIDC/workload federation.
- Terraform source, remote state and infrastructure changes.
- Security logging, configuration changes and outbound network traffic.

### Lab and production assumptions

- The student lab uses one Azure for Students subscription with logical resource-group separation.
- Production architecture uses separate subscriptions, hub-and-spoke networking, Application Gateway WAF and centralized Azure Firewall egress.
- SQL, Storage and Key Vault are designed with public network access disabled and private access through Private Endpoints.
- The lab may use direct HTTPS to App Service and must document production differences rather than represent unavailable or cost-prohibitive controls as implemented.
- This is a design baseline: controls are initially marked as `Planned`, then become `Implemented` and `Validated` only after evidence is collected.

## 2. Architecture and data-flow summary

### Primary application and data flow

The production-reference architecture uses the following request path:

Internet customer  
→ HTTPS  
→ Application Gateway with WAF  
→ HTTPS  
→ Azure App Service  
→ VNet Integration  
→ Private Endpoints with Private DNS  
→ Azure SQL / Azure Storage / Azure Key Vault

The Azure for Students lab may use direct HTTPS access to Azure App Service during normal development to avoid permanent Application Gateway WAF cost. WAF controls are therefore documented as a production reference or validated temporarily during a GAME DAY.

### Additional security-relevant flows

- Administrators → Microsoft Entra ID → Azure RBAC → Azure control plane.
- GitHub Actions → OIDC workload federation → Azure control plane → Terraform plan/apply.
- Terraform CLI or CI workflow → remote Terraform state in Azure Storage.
- Azure services and control-plane events → Diagnostic Settings → Log Analytics → selected detections and response automation.
- Production workloads → centralized egress controls through Azure Firewall. The student lab documents this design but does not keep Azure Firewall running permanently.

### Data-service access model

Azure SQL, Azure Storage, and Azure Key Vault are designed with public network access disabled. Azure App Service accesses these services through its managed identity and private network paths, rather than embedded credentials or public endpoints.

## 3. Trust boundaries

A trust boundary exists where a user, service, network, or automation process with one level of trust interacts with a component at another trust level. Threats are evaluated at these boundaries.

| ID | Trust boundary | Security-relevant crossing | Planned protection |
|---|---|---|---|
| TB-1 | Internet customer → public application ingress | Untrusted internet traffic reaches the application. | HTTPS; production Application Gateway WAF; application-level input validation; request logging. The DEV lab may use direct HTTPS to App Service. |
| TB-2 | App Service → private data services | Application workload accesses Azure SQL, Storage, and Key Vault. | VNet Integration; Private Endpoints; Private DNS; public network access disabled; managed identity; least-privilege data-plane RBAC. |
| TB-3 | Human administrator → Azure control plane | Administrators configure resources, policies, networking, and RBAC. | Microsoft Entra ID; least-privilege Azure RBAC; MFA; PIM and Conditional Access where licensing permits; Azure Activity Log monitoring. |
| TB-4 | GitHub Actions → Azure control plane | CI/CD workflow authenticates and changes Azure infrastructure through Terraform. | GitHub OIDC workload federation; no stored Azure client secret; restricted federation subject and repository; separate plan/apply permissions; production approval before apply. |
| TB-5 | Terraform client or CI → remote state backend | Terraform reads and writes state that may expose sensitive resource metadata. | Private or restricted Azure Storage backend; encryption; least-privilege state access; state files excluded from Git; versioning and recovery controls where available. |
| TB-6 | Azure resources → telemetry and detection platform | Resource, identity, and control-plane events are forwarded for investigation and detection. | Diagnostic Settings; Log Analytics; selected Sentinel detections where enabled; alerting on logging or security-control changes. |
| TB-7 | Application workload → external destinations | The workload may initiate outbound connections outside the private application/data path. | Production centralized egress through Azure Firewall; restrictive network controls and logging. The student lab documents this production control rather than keeping Azure Firewall running permanently. |

## 4. Key assets and security objectives

The following assets are prioritized based on the impact of compromise to FinTechCo, its customers, and the platform’s ability to operate securely.

| ID | Asset | Why it matters | Primary security objectives |
|---|---|---|---|
| A-01 | Customer financial records in Azure SQL | Contains the application’s most sensitive customer data. Unauthorized disclosure or modification would have high business and security impact. | Confidentiality, Integrity, Availability |
| A-02 | Azure Storage objects | May contain customer documents, application data, exports, or Terraform state artifacts. | Confidentiality, Integrity, Availability |
| A-03 | Key Vault secrets, keys, and certificates | Protects sensitive application configuration and cryptographic material. Compromise can enable broader access to the platform. | Confidentiality, Integrity |
| A-04 | Terraform remote state | May expose resource metadata, identifiers, outputs, and potentially sensitive values. Tampering can affect deployed infrastructure. | Confidentiality, Integrity, Availability |
| A-05 | Privileged Microsoft Entra ID and Azure identities | Can change Azure configuration, RBAC assignments, networking, policies, and security controls. | Integrity, Availability, Accountability |
| A-06 | GitHub Actions OIDC identity and repository workflows | Represents the automated deployment path to Azure. Compromise could allow unauthorized infrastructure changes. | Integrity, Accountability |
| A-07 | Application code and App Service managed identity | The application processes customer requests and accesses private data services. Compromise could enable data access or malicious actions. | Confidentiality, Integrity, Availability |
| A-08 | Security telemetry, detections, and response automation | Required to detect, investigate, and respond to security-relevant activity. Loss or tampering reduces visibility and accountability. | Integrity, Availability, Accountability |

### Priority security objectives

The platform is designed to:

- Keep customer financial records, Storage data, Key Vault material, and Terraform state confidential.
- Prevent unauthorized changes to data, infrastructure, identities, CI/CD workflows, and security controls.
- Maintain availability of the customer-facing application and critical security telemetry.
- Ensure privileged and automated actions are attributable through identity and logging controls.
- Limit the blast radius of a compromised identity, workload, workflow, or network path.

## 5. Threat register

Risk ratings in this initial model are qualitative and will be reassessed after implementation and validation evidence is collected.

### TM-01 — CI/CD identity spoofing or OIDC trust misconfiguration

- **STRIDE:** Spoofing, Elevation of Privilege
- **Trust boundary:** TB-4 — GitHub Actions → Azure control plane
- **Affected assets:** A-04 Terraform remote state, A-05 privileged Azure identities, A-06 GitHub Actions OIDC identity and workflows, and all deployed Azure resources.
- **Initial risk:** High

#### Threat scenario

An attacker impersonates the CI/CD deployment identity by exploiting a stored Azure credential or an overly broad GitHub OIDC federation rule. For example, an Azure federated credential could accept tokens from an unapproved repository, branch, GitHub environment, or workflow context.

If successful, the attacker could run Terraform with Azure permissions, modify infrastructure, weaken security controls, access Terraform state, or create additional privileged access.

#### Planned preventive controls

- Use GitHub Actions OIDC workload federation instead of a stored Azure client secret.
- Restrict federated credential claims to the approved GitHub repository, branch or environment, and audience.
- Use separate plan and apply permissions with least-privilege Azure RBAC.
- Protect the default branch and require pull-request review for Terraform and workflow changes.
- Require approval before production apply operations.

#### Planned detection and evidence

- Retain GitHub Actions workflow logs for deployment activity.
- Monitor Azure Activity Log for role assignments, federated credential changes, and security-sensitive resource changes.
- Record the federated credential configuration and RBAC assignments as repository evidence.

#### Validation actions

1. Prove that the approved GitHub Actions workflow authenticates to Azure without a stored client secret.
2. Attempt OIDC authentication from an unapproved branch, repository, or subject and confirm that Azure rejects it.
3. Review the federated credential claims and confirm that they match only the intended deployment context.
4. Confirm that the plan identity cannot perform apply-level actions.

#### Residual-risk target

Medium. A compromised approved GitHub repository or approved workflow context could still affect the deployment path; protected branches, review, least privilege, and auditability reduce the likelihood and blast radius.

#### Status

Planned. This threat will be implemented and validated during **M3 — Identity + OIDC** and **M6 — Telemetry, Detection + DevSecOps**.

### TM-02 — Malicious Terraform, workflow, or dependency change

- **STRIDE:** Tampering, Elevation of Privilege
- **Trust boundaries:** TB-4, TB-5
- **Affected assets:** A-04 Terraform state, A-05 privileged identities, A-06 GitHub workflows, and deployed Azure resources.
- **Initial risk:** High

#### Threat scenario

An attacker, or a contributor whose account has been compromised, modifies Terraform code, a GitHub Actions workflow, or a referenced dependency. The change could enable public access, weaken RBAC, disable diagnostics, exfiltrate state, or execute an unauthorized deployment.

#### Planned preventive controls

- Protected default branch and pull-request review for Terraform and workflow changes.
- GitHub Actions checks for `terraform fmt`, `terraform validate`, TFLint, and Checkov.
- Pin or review third-party GitHub Actions and Terraform provider versions.
- Separate plan and apply permissions; require approval before production apply.

#### Planned detection and evidence

- Pull-request history, code review records, CI results, and Terraform plan output.
- Azure Activity Log monitoring for security-sensitive configuration changes.

#### Validation actions

1. Introduce an intentionally insecure Terraform change in a test branch.
2. Confirm that Checkov or an equivalent security gate blocks or flags the change.
3. Confirm that an unreviewed change cannot reach the protected deployment path.

#### Residual-risk target

Medium. A trusted maintainer account could still approve a malicious change; review, branch protection, CI gates, and least privilege reduce the likelihood and blast radius.

#### Status

Planned. Primary implementation and validation: **M2** and **M6**.

---

### TM-03 — Loss of auditability through disabled or incomplete logging

- **STRIDE:** Repudiation, Tampering
- **Trust boundaries:** TB-3, TB-6
- **Affected assets:** A-05 privileged identities, A-08 security telemetry and detections.
- **Initial risk:** High

#### Threat scenario

An attacker or privileged user disables diagnostic settings, reduces logging scope, changes retention, or alters security detections before or during malicious activity. This prevents reliable investigation and weakens accountability.

#### Planned preventive controls

- Diagnostic Settings for selected control-plane and security-relevant resource events.
- Centralized Log Analytics workspace.
- Least-privilege RBAC for diagnostics, logging, and detection configuration.
- Azure Policy to audit or enforce required diagnostics where practical.

#### Planned detection and evidence

- Azure Activity Log monitoring for diagnostic-setting, policy, and security-control changes.
- A KQL detection for disabled or modified logging after telemetry is enabled.

#### Validation actions

1. Make a reversible diagnostic-setting or security-control change in a test environment.
2. Confirm that the change is recorded in Azure Activity Logs.
3. Confirm that the detection/query identifies the change.
4. Restore the expected configuration and retain the evidence.

#### Residual-risk target

Medium. Highly privileged administrators may still alter telemetry; centralized monitoring and alerts improve accountability and response time.

#### Status

Planned. Primary implementation and validation: **M5**, **M6**, and **M7**.

---

### TM-04 — Public exposure of Azure SQL, Storage, or Key Vault

- **STRIDE:** Information Disclosure, Tampering
- **Trust boundary:** TB-2
- **Affected assets:** A-01 customer financial records, A-02 Storage objects, A-03 Key Vault material.
- **Initial risk:** High

#### Threat scenario

A misconfiguration enables public network access to Azure SQL, Storage, or Key Vault. An attacker could then attempt access from the internet, exploit weak authorization, or enumerate exposed service endpoints.

#### Planned preventive controls

- Disable public network access for Azure SQL, Storage, and Key Vault.
- Use Private Endpoints and Private DNS for private service access.
- Use Azure Policy to deny or audit insecure public-access configurations.
- Apply least-privilege data-plane RBAC and managed identity access.

#### Planned detection and evidence

- Terraform configuration and Azure Policy definitions stored in Git.
- Azure Activity Log and policy-compliance results.
- Optional detection for a security-sensitive public-access configuration change.

#### Validation actions

1. Attempt to deploy or configure a public-access setting in a test environment.
2. Confirm that Azure Policy blocks or flags the configuration.
3. Confirm that public connectivity fails after private networking is implemented.
4. Confirm that App Service reaches the required service through private DNS and the Private Endpoint.

#### Residual-risk target

Low to Medium. Private access reduces external exposure substantially, but RBAC, DNS, and application authorization must also remain correctly configured.

#### Status

Planned. Primary implementation and validation: **M4** and **M5**.

---

### TM-05 — Terraform state or secret leakage

- **STRIDE:** Information Disclosure, Tampering
- **Trust boundary:** TB-5
- **Affected assets:** A-03 Key Vault material, A-04 Terraform state, A-05 privileged identities.
- **Initial risk:** High

#### Threat scenario

Terraform state is committed to Git, stored locally without protection, exposed through an overly permissive Storage backend, or contains sensitive values that can be read by an unauthorized identity.

#### Planned preventive controls

- Use an Azure Storage remote backend for Terraform state.
- Restrict state-backend access with least-privilege Azure RBAC.
- Exclude `*.tfstate`, `*.tfstate.*`, local override files, and secrets from Git.
- Avoid placing secrets in Terraform variables, outputs, or state where possible.
- Enable encryption and recovery/versioning controls where available.

#### Planned detection and evidence

- Repository `.gitignore` and secret-scanning results.
- Azure RBAC assignment evidence for the state backend.
- State-backend configuration documented without exposing sensitive values.

#### Validation actions

1. Confirm that Terraform state is stored remotely and not committed to Git.
2. Attempt state access using an unauthorized identity and confirm denial.
3. Review Terraform outputs and state handling to confirm secrets are not unnecessarily exposed.
4. Test a safe recovery/versioning scenario if the selected backend configuration supports it.

#### Residual-risk target

Medium. State remains sensitive by design; access control, reduced secret content, and monitoring limit exposure.

#### Status

Planned. Primary implementation and validation: **M2**.

---

### TM-06 — Excessive Azure RBAC permissions or privilege escalation

- **STRIDE:** Elevation of Privilege, Tampering
- **Trust boundary:** TB-3
- **Affected assets:** A-01 through A-08, especially A-05 privileged identities.
- **Initial risk:** High

#### Threat scenario

A human administrator, managed identity, or CI/CD identity receives unnecessary Owner, Contributor, or data-plane permissions. A compromise or mistake then has a larger blast radius than required.

#### Planned preventive controls

- Least-privilege RBAC at the narrowest practical scope.
- Separate administrator, workload, and CI/CD identities.
- Managed identity for App Service access to data services.
- No permanent broad permissions without documented justification.
- PIM and Conditional Access documented as production controls where licensing permits.

#### Planned detection and evidence

- Terraform-managed RBAC assignments.
- Azure Activity Log monitoring for role-assignment changes.
- A later KQL detection or query for new privileged role assignments.

#### Validation actions

1. Confirm that App Service can perform only its required action against SQL, Storage, or Key Vault.
2. Attempt a selected unauthorized action and confirm denial.
3. Review RBAC assignments for broad roles and document any exception.
4. Generate a controlled role-assignment change and confirm it is visible in telemetry.

#### Residual-risk target

Medium. Privileged access remains necessary for administration, but scope separation and monitoring reduce impact.

#### Status

Planned. Primary implementation and validation: **M3**, **M5**, and **M6**.

---

### TM-07 — Key Vault secret, key, or certificate compromise

- **STRIDE:** Spoofing, Information Disclosure, Elevation of Privilege
- **Trust boundary:** TB-2
- **Affected assets:** A-03 Key Vault material, A-07 application runtime identity.
- **Initial risk:** High

#### Threat scenario

An attacker obtains a secret, key, or certificate from Key Vault through excessive permissions, public exposure, a compromised workload identity, or weak operational controls. The material could then be used to impersonate the application or access dependent services.

#### Planned preventive controls

- Key Vault public network access disabled and private access through a Private Endpoint.
- Managed identity instead of embedded application credentials.
- Least-privilege Key Vault RBAC.
- Soft delete, purge protection, and logging where available.
- No Key Vault secret values committed to Git or exposed in Terraform outputs.

#### Planned detection and evidence

- Key Vault diagnostic logs where enabled.
- RBAC configuration and managed-identity assignment evidence.
- Detection/query for unusual or unauthorized secret access where telemetry supports it.

#### Validation actions

1. Confirm that the App Service managed identity can access only the required Key Vault material.
2. Attempt Key Vault access using an unauthorized identity and confirm denial.
3. Confirm that public network access is disabled after implementation.
4. Review logs for the allowed and denied access tests where available.

#### Residual-risk target

Medium. A compromised approved workload identity may still access permitted material; least privilege and monitoring limit impact.

#### Status

Planned. Primary implementation and validation: **M3**, **M4**, **M5**, and **M6**.

---

### TM-08 — Web application attack or broken authorization affecting customer data

- **STRIDE:** Tampering, Information Disclosure, Elevation of Privilege
- **Trust boundaries:** TB-1, TB-2
- **Affected assets:** A-01 customer financial records, A-02 Storage objects, A-07 application code and runtime identity.
- **Initial risk:** High

#### Threat scenario

An attacker sends malicious requests to the internet-facing application, such as injection-style payloads or requests targeting broken authorization. Successful exploitation could access or alter customer data through the application.

#### Planned preventive controls

- HTTPS-only ingress.
- Production Application Gateway WAF; direct App Service HTTPS in the low-cost DEV lab.
- Input validation and parameterized database access in the sample workload.
- Application-level authorization checks.
- Least-privilege managed-identity and database permissions.

#### Planned detection and evidence

- Application logs and selected Azure diagnostics.
- WAF logs only when WAF is deployed temporarily for GAME DAY validation.
- Documented security test results for denied or blocked requests.

#### Validation actions

1. Run safe, non-destructive malformed or injection-style requests against the sample application.
2. Confirm that the application rejects the request and does not expose data.
3. If WAF is deployed for a temporary GAME DAY, confirm that the request is blocked and logged.
4. Confirm that the application identity cannot bypass database permissions.

#### Residual-risk target

Medium. The project demonstrates baseline protections, not a complete application-security program.

#### Status

Planned. Primary implementation and validation: **M5** and **M7**.

---

### TM-09 — App Service workload identity abuse or server-side request forgery

- **STRIDE:** Spoofing, Elevation of Privilege, Information Disclosure
- **Trust boundaries:** TB-1, TB-2, TB-7
- **Affected assets:** A-01 customer financial records, A-02 Storage objects, A-03 Key Vault material, A-07 application runtime identity.
- **Initial risk:** High

#### Threat scenario

An attacker compromises the application or exploits a server-side request forgery weakness. The attacker then attempts to use the App Service managed identity or private network path to access Azure SQL, Storage, Key Vault, or external destinations.

#### Planned preventive controls

- Least-privilege managed-identity RBAC.
- Private Endpoints and private DNS for sensitive PaaS services.
- No embedded credentials in the application.
- Network segmentation and restricted outbound paths in the production design.
- Input validation and safe handling of user-controlled URLs in the sample workload.

#### Planned detection and evidence

- Managed-identity access configuration and RBAC evidence.
- Selected resource-access diagnostics where enabled.
- Production-design documentation for centralized egress logging and control.

#### Validation actions

1. Confirm that the App Service identity can access only explicitly required resources.
2. Attempt a selected unauthorized data-plane action and confirm denial.
3. Confirm that sensitive services cannot be reached through their public endpoints after private networking is implemented.
4. Document the student-lab limitation where centralized Azure Firewall egress is not deployed.

#### Residual-risk target

Medium. A compromised application can act within the permissions granted to its identity; least privilege is the primary blast-radius control.

#### Status

Planned. Primary implementation and validation: **M3**, **M4**, and **M5**.

---

### TM-10 — Unrestricted or malicious outbound network egress

- **STRIDE:** Information Disclosure, Command and Control
- **Trust boundary:** TB-7
- **Affected assets:** A-01 customer financial records, A-02 Storage objects, A-03 Key Vault material, A-07 application runtime identity.
- **Initial risk:** Medium

#### Threat scenario

A compromised workload sends data to an attacker-controlled external destination or establishes command-and-control traffic. Without egress restrictions and logging, this activity may be difficult to prevent or investigate.

#### Planned preventive controls

- Production centralized egress through Azure Firewall.
- Restrictive network controls and outbound logging in the production design.
- Minimize unnecessary application outbound dependencies.
- Keep lab-only egress limitations explicitly documented.

#### Planned detection and evidence

- Azure Firewall and network telemetry when temporarily enabled for a GAME DAY.
- Application and platform logs where available.
- Documented production-versus-lab design difference.

#### Validation actions

1. Document the intended allowed outbound destinations for the application.
2. If cost and time permit a temporary GAME DAY deployment, test an allowed and a blocked outbound path.
3. Capture the resulting logs and destroy temporary paid resources after evidence collection.
4. If Firewall is not deployed, record this as a lab limitation rather than claiming egress enforcement.

#### Residual-risk target

Medium. The Azure for Students lab may not enforce centralized egress continuously; production design addresses this control.

#### Status

Planned. Primary implementation and validation: **M4** and **M7**.

---

## 6. Validation roadmap

| Milestone | Threats addressed | Expected evidence |
|---|---|---|
| M2 — Terraform + Secure State | TM-02, TM-05 | Remote backend, protected state access, `.gitignore`, Terraform validation, CI baseline. |
| M3 — Identity + OIDC | TM-01, TM-06, TM-07, TM-09 | OIDC federation claims, RBAC matrix, managed identity configuration, allowed and denied access tests. |
| M4 — Network + Private Data Path | TM-04, TM-07, TM-09, TM-10 | Private Endpoints, private DNS resolution, public-path failure, permitted private connectivity, documented egress limitation. |
| M5 — Application, Data + Governance | TM-03, TM-04, TM-06, TM-07, TM-08 | App-to-data flow, policy-as-code, non-compliant deployment test, secure application request tests. |
| M6 — Telemetry, Detection + DevSecOps | TM-01, TM-02, TM-03, TM-06 | CI security gates, Azure Activity/diagnostic telemetry, selected KQL detections, generated-event evidence. |
| M7 — Automation + Game Days | TM-03, TM-04, TM-08, TM-10 | Policy-prevention, CI-prevention, and detection/response Game Day reports. |

## 7. Scope limitations and review criteria

This threat model is intentionally focused on the material attack paths of the project. It does not claim complete threat coverage, formal compliance, or production operation.

The Azure for Students lab uses one subscription and documents, rather than recreates permanently, production features such as management groups, multiple subscriptions, hub-and-spoke networking, Application Gateway WAF, centralized Azure Firewall egress, PIM, Conditional Access, extended telemetry retention, and selected Defender or Sentinel capabilities.

A control remains `Planned` until it is implemented. It becomes `Validated` only after its validation action passes and evidence is committed or referenced in the repository.

The threat model will be reviewed after each relevant milestone to update implementation status, validation results, and residual risk.
