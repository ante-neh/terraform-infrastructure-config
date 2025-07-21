output "service_principal_details" {
  value = {
    client_id     = azuread_application.gh_actions.client_id
    client_secret = azuread_service_principal_password.gh_actions.value
    tenant_id     = data.azurerm_client_config.current.tenant_id
    object_id     = azuread_service_principal.gh_actions.object_id
  }
  sensitive = true
}

output "configured_repos" {
  value = [for repo in github_repository.repo : repo.name]
}

output "acr_details" {
  value = {
    server   = data.azurerm_container_registry.acr.login_server
    username = data.azurerm_container_registry.acr.admin_username
  }
  sensitive = true
}