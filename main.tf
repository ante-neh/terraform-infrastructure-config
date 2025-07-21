terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}


provider "azurerm" {
  features {}
}

provider "azuread" {}

provider "github" {
  owner = var.github_owner
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}


data "azurerm_client_config" "current" {}


data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name_filter
  resource_group_name = data.azurerm_resource_group.aks.name
}

data "azurerm_resource_group" "aks" {
  name = var.aks_resource_group
}


data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}


locals {
  sp_basename = "gh-actions-sp"
  sp_version  = var.reset_sp ? "v${formatdate("YYYYMMDDhhmmss", timestamp())}" : "v1"
  sp_name     = "${local.sp_basename}-${var.aks_name_filter}-${local.sp_version}"
  full_repos  = [for repo in var.repo_names : "${var.github_owner}/${repo}"]
  aks_rg_id   = data.azurerm_resource_group.aks.id
}


resource "azuread_application" "gh_actions" {
  display_name = local.sp_name
}

resource "azuread_service_principal" "gh_actions" {
  client_id = azuread_application.gh_actions.client_id
}

resource "azuread_service_principal_password" "gh_actions" {
  service_principal_id = azuread_service_principal.gh_actions.object_id
}

resource "azurerm_role_assignment" "sp_role" {
  scope                = local.aks_rg_id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gh_actions.object_id
}


resource "github_repository" "repo" {
  for_each   = toset(var.repo_names)
  name       = each.value
  visibility = "private"
  auto_init  = true
}


resource "github_actions_secret" "azure_credentials" {
  for_each = github_repository.repo

  repository  = each.value.name
  secret_name = "AZURE_CREDENTIALS"
  plaintext_value = jsonencode({
    clientId       = azuread_application.gh_actions.client_id
    clientSecret   = azuread_service_principal_password.gh_actions.value
    subscriptionId = data.azurerm_client_config.current.subscription_id
    tenantId       = data.azurerm_client_config.current.tenant_id
  })
}

resource "github_actions_secret" "registry_username" {
  for_each = github_repository.repo

  repository      = each.value.name
  secret_name     = "REGISTRY_USERNAME"
  plaintext_value = data.azurerm_container_registry.acr.admin_username
}

resource "github_actions_secret" "registry_password" {
  for_each = github_repository.repo

  repository      = each.value.name
  secret_name     = "REGISTRY_PASSWORD"
  plaintext_value = data.azurerm_container_registry.acr.admin_password
}


resource "github_repository_file" "workflow" {
  for_each = github_repository.repo

  repository = each.value.name
  branch     = "master"
  file       = ".github/workflows/deploy.yaml"
  content = templatefile("${path.module}/templates/workflow.yaml.tftpl", {
    registry         = data.azurerm_container_registry.acr.login_server
    image_name       = each.value.name
    deployment_name  = "${replace(each.value.name, "_", "-")}-deployment"
    k8s_namespace    = var.k8s_namespace
    aks_cluster_name = var.aks_name_filter
    resource_group   = data.azurerm_resource_group.aks.name
  })
  commit_message      = "Add deployment workflow"
  commit_author       = "Terraform"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}


resource "github_repository_file" "deployment" {
  for_each = github_repository.repo

  repository = each.value.name
  branch     = "master"
  file       = "deployment.yaml"
  content = templatefile("${path.module}/templates/deployment.yaml.tftpl", {
    image_name       = each.value.name
    registry         = data.azurerm_container_registry.acr.login_server
    container_port   = var.container_port
    environment_vars = jsonencode(var.environment_vars)
    secrets          = jsonencode(var.secrets)
    deployment_name  = "${replace(each.value.name, "_", "-")}-deployment"
    VERSION          = "__VERSION_PLACEHOLDER__"
  })
  commit_message      = "Add deployment manifest"
  commit_author       = "Terraform"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}


resource "github_repository" "existing_repos" {
  for_each = toset(var.repo_names)

  name        = each.value
  description = "Imported existing repository"
  auto_init   = false

  lifecycle {
    ignore_changes = all
  }
}