## Overview

This repository contains Terraform configurations and helper scripts to automate the creation and management of:

- Azure resources: AKS (Azure Kubernetes Service), ACR (Azure Container Registry)
- Azure AD Application & Service Principal for GitHub Actions
- GitHub repositories and workflows for building & deploying containerized applications to AKS

By simply supplying your AKS/ACR details and GitHub organization information, Terraform will:

1. Create or import GitHub repositories
2. Generate and assign Azure AD service principal with Contributor rights on AKS resource group
3. Store necessary secrets (`AZURE_CREDENTIALS`, `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`) in each GitHub repo
4. Add Kubernetes deployment manifests and GitHub Actions workflows for CI/CD to AKS

---

## Prerequisites

- Terraform v1.2+ installed and on `PATH`
- Azure CLI logged in to the subscription
- Permissions to create resources in the target resource groups
- GitHub personal access token (with `repo` and `admin:repo_hook` scopes) set in `GITHUB_TOKEN` env var or in provider block
- Bash shell (for `bootstrap.sh` and `update.sh`)

---

## Repository Structure

```
.
├── main.tf           # Terraform configuration
├── variables.tf      # Input variable definitions
├── outputs.tf        # Terraform outputs
├── templates/        # Templated workflow & deployment YAML files
│   ├── workflow.yaml.tftpl
│   └── deployment.yaml.tftpl
├── bootstrap.sh      # Helper script to initialize & apply Terraform for first-time setup
└── update.sh         # Helper script to update existing setup
```

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/ante-neh/terraform-infrastructure-config.git
cd terraform-infrastructure-config
```

### 2. Bootstrap (first-time run)

Use `bootstrap.sh` to generate `terraform.tfvars` and apply all resources:

```bash
./bootstrap.sh <aks-name> <aks-resource-group> <acr-name> <acr-resource-group> <repo1,repo2,...> <github-owner> [--reset]
```

- `<aks-name>`: AKS cluster filter name
- `<aks-resource-group>`: Resource group where AKS exists
- `<acr-name>`: ACR instance name
- `<acr-resource-group>`: Resource group of ACR
- `<repo1,repo2,...>`: Comma-separated list of GitHub repo names (new or to manage)
- `<github-owner>`: GitHub org or username
- `--reset` (optional): Regenerate Service Principal credentials

This script will:

1. Write variables to `terraform.tfvars`
2. Run `terraform init` and `terraform apply -auto-approve`
3. Output `✅ Bootstrap complete`

### 3. Managing Existing Repositories

To manage an already existing GitHub repository with Terraform:

1. Ensure the repository is listed in `repo_names` within `terraform.tfvars`.

2. Import the repository into Terraform state:

   ```bash
   terraform import github_repository.repo["<repo-name>"] <github-owner>/<repo-name>
   ```

3. Run `terraform apply` to configure workflows and secrets for the imported repo.

### 4. Update (subsequent runs)

Use `update.sh` to update configuration or add/remove repositories:

```bash
./update.sh <aks-name> <aks-resource-group> <acr-name> <acr-resource-group> <repo1,repo2,...> <github-owner> [--reset]
```

This will regenerate `terraform.tfvars` and apply changes.

Use `update.sh` to update configuration or add/remove repositories:

```bash
./update.sh <aks-name> <aks-resource-group> <acr-name> <acr-resource-group> <repo1,repo2,...> <github-owner> [--reset]
```

This will regenerate `terraform.tfvars` and apply changes.

---

## Terraform Variables

| Name                 | Description                                  | Type           | Default   | Required |
| -------------------- | -------------------------------------------- | -------------- | --------- | -------- |
| `aks_name_filter`    | AKS cluster name filter                      | `string`       | n/a       | Yes      |
| `aks_resource_group` | AKS resource group name                      | `string`       | n/a       | Yes      |
| `acr_name`           | ACR name                                     | `string`       | n/a       | Yes      |
| `acr_resource_group` | ACR resource group name                      | `string`       | n/a       | Yes      |
| `github_owner`       | GitHub organization or username              | `string`       | n/a       | Yes      |
| `repo_names`         | List of GitHub repositories to create/manage | `list(string)` | `[]`      | No       |
| `reset_sp`           | Whether to reset service principal           | `bool`         | `false`   | No       |
| `k8s_namespace`      | Kubernetes namespace                         | `string`       | `default` | No       |
| `container_port`     | Container port for app                       | `number`       | `8080`    | No       |
| `environment_vars`   | Deployment environment variables             | `map(string)`  | `{}`      | No       |
| `secrets`            | List of secret objects for k8s               | `list(object)` | `[]`      | No       |

---

## Key Resources Provisioned

- **Azure AD Application & SP**: `azuread_application.gh_actions`, `azuread_service_principal.gh_actions`, `azuread_service_principal_password.gh_actions`
- **Role Assignment**: Contributor role on AKS RG for the SP (`azurerm_role_assignment.sp_role`)
- **Azure Data Sources**: fetch current tenant/subscription, AKS cluster, RG, ACR
- **GitHub Repositories**: `github_repository.repo` (create) & `github_repository.existing_repos` (import)
- **GitHub Actions Secrets**: `AZURE_CREDENTIALS`, `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`
- **Workflow & Deployment files**: `.github/workflows/deploy.yaml`, `deployment.yaml` via `github_repository_file`

---

## Outputs

After successful apply, Terraform outputs:

- `service_principal_details` (sensitive)
- `configured_repos` (list of repository names)
- `acr_details` (sensitive credentials for ACR login)

---

## CI/CD Workflow

The generated GitHub Actions workflow (`.github/workflows/deploy.yaml`) performs:

1. Checkout code
2. Build & push Docker image to ACR
3. Azure login using the SP credentials
4. Configure AKS context
5. Apply Kubernetes deployment manifest
6. Verify deployment and pods status

---

## Cleanup

To destroy all created resources:

```bash
terraform destroy -auto-approve
```

Note: GitHub repos created remain; delete manually if desired.

---

