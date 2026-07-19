variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
  default     = "rg-cloudgames"
}

variable "location" {
  description = "Região do Azure"
  type        = string
  default     = "brazilsouth"
}

variable "acr_name" {
  description = "Nome do Azure Container Registry (deve ser único globalmente, apenas letras e números)"
  type        = string
  default     = "acrcloudgames"
}

variable "aks_cluster_name" {
  description = "Nome do cluster AKS"
  type        = string
  default     = "aks-cloudgames"
}

variable "node_count" {
  description = "Número de nós do node pool padrão"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "Tamanho das VMs dos nós"
  type        = string
  default     = "Standard_D2s_v6"
}
