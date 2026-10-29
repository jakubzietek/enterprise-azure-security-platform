# Cost and Teardown

The DEV environment is designed to be disposable. Resources that generate ongoing cost can be destroyed without removing the Terraform backend or GitHub deployment identity.

## Main cost drivers

The main billable resources in DEV are:

- Linux App Service B1
- Azure SQL Basic database
- Private Endpoints
- Log Analytics ingestion and retention
- Azure Storage usage

Log Analytics is capped at:

```text
0.1 GB/day
```

to reduce the risk of unexpected telemetry cost.

The environment deliberately uses low-cost DEV choices such as:

- single-instance App Service
- SQL Basic
- Storage LRS
- 30-day Log Analytics retention
- no Application Gateway or Azure Firewall
- no Microsoft Sentinel deployment

These choices are for the lab only and are not intended as production defaults.

## Normal DEV teardown

The DEV workload can be removed independently of the platform and backend.

```bash
cd terraform/environments/dev

export TF_VAR_sql_entra_admin_login="$(az ad signed-in-user show --query userPrincipalName -o tsv)"
export TF_VAR_sql_entra_admin_object_id="$(az ad signed-in-user show --query id -o tsv)"

terraform init
terraform plan -destroy
terraform destroy
```

The destroy plan should always be reviewed before confirmation.

This removes the application workload while retaining:

- Terraform state infrastructure
- GitHub Actions managed identity
- OIDC federation
- DEV deployment resource group boundary

The environment can then be recreated from Terraform.

## Residual-resource check

After teardown:

```bash
az resource list \
  --resource-group rg-ecsp-dev \
  --output table
```

The DEV resource group may remain because it belongs to the separate `platform` Terraform root.

It should contain no workload resources after a successful DEV destroy.

Useful additional checks:

```bash
az group list \
  --query "[?starts_with(name, 'rg-ecsp')].[name,location]" \
  -o table
```

and:

```bash
az resource list \
  --query "[?contains(name, 'ecsp')].[name,type,resourceGroup]" \
  -o table
```

Any resource left outside the intended bootstrap/platform boundary should be investigated before the lab is considered fully stopped.

## Full project teardown

If the entire project is no longer needed, destroy resources in reverse dependency order:

```text
DEV workload
      ↓
platform / CI identity
      ↓
Terraform backend
```

First:

```bash
cd terraform/environments/dev
terraform destroy
```

Then:

```bash
cd ../../platform
terraform destroy
```

The bootstrap layer requires additional care because it contains the Storage Account holding its own Terraform state.

Before deleting the backend, migrate the bootstrap state away from the Storage Account or otherwise preserve the state locally. The backend should only be removed after the DEV and platform roots have already been destroyed.

## Rebuild model

The separation between:

```text
bootstrap
platform
dev
```

is intentional.

Most development cycles only require destroying and recreating `dev`.

The backend and CI identity can remain in place, making repeated security testing faster while avoiding the cost of leaving the application environment running continuously.
