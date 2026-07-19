output "resource_group_name" {
  description = "Nome do Resource Group criado"
  value       = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  description = "Login server do ACR (usado nas tags das imagens Docker)"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  description = "Nome do ACR"
  value       = azurerm_container_registry.acr.name
}

output "aks_cluster_name" {
  description = "Nome do cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}
