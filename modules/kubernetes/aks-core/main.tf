/**
  * # AKS Core
  *
  * This module is used to create AKS clusters.
  */

terraform {
  required_version = "0.14.7"

  required_providers {
    azurerm = {
      version = "2.51.0"
      source  = "hashicorp/azurerm"
    }
    azuread = {
      version = "1.4.0"
      source  = "hashicorp/azuread"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.0.3"
    }
    github = {
      source  = "integrations/github"
      version = "4.5.2"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "0.0.14"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.10.0"
    }
  }
}

locals {
  # Namespace to create service accounts in
  service_accounts_namespace = "service-accounts"
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = "rg-${var.environment}-${var.location_short}-${var.name}"
}
