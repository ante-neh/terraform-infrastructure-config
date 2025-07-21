variable "aks_name_filter" {
  description = "AKS cluster name"
  type        = string
}

variable "aks_resource_group" {
  description = "AKS resource group name"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
}

variable "repo_names" {
  description = "List of GitHub repository names"
  type        = list(string)
  default     = []
}

variable "reset_sp" {
  description = "Reset service principal credentials"
  type        = bool
  default     = false
}

variable "k8s_namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "acr_name" {
  description = "ACR name"
  type        = string
}

variable "acr_resource_group" {
  description = "ACR resource group name"
  type        = string
}

variable "container_port" {
  description = "Container port for applications"
  type        = number
  default     = 8080
}

variable "environment_vars" {
  description = "Environment variables for deployment"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets configuration"
  type = list(object({
    name        = string
    secret_name = string
    key         = string
  }))
  default = []
}