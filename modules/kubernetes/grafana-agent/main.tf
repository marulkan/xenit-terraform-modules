/**
 * # Azure AD Kubernetes API Proxy
 * Adds [`grafana-agent`](https://grafana.com/docs/agent/latest/) (the operator) to a Kubernetes clusters.
 *
 * ## Using the module (from aks-core)
 *
 * ### Azure KeyVault
 *
 * ```shell
 * METRICS_USERNAME="usr"
 * METRICS_PASSWORD="pw"
 * LOGS_USERNAME="usr"
 * LOGS_PASSWORD="pw"
 * TRACES_USERNAME="usr"
 * TRACES_PASSWORD="pw"
 * 
 * JSON_FMT='{"metrics_username":"%s","metrics_password":"%s","logs_username":"%s","logs_password":"%s","traces_username":"%s","traces_password":"%s"}'
 * KV_SECRET=$(printf "${JSON_FMT}" "${METRICS_USERNAME}" "${METRICS_PASSWORD}" "${LOGS_USERNAME}" "${LOGS_PASSWORD}" "${TRACES_USERNAME}" "${TRACES_PASSWORD}")
 * az keyvault secret set --vault-name [keyvault name] --name grafana-agent-credentials --value "${KV_SECRET}"
 * ```
 *
 * ### Terraform example
 *
 * ```terraform
 * data "azurerm_key_vault_secret" "grafana_agent_credentials" {
 *   key_vault_id = data.azurerm_key_vault.core.id
 *   name         = "grafana-agent-credentials"
 * }
 *
 * module "aks_core" {
 *   source = "github.com/xenitab/terraform-modules//modules/kubernetes/aks-core?ref=[ref]"
 *
 *   [...]
 *
 *   grafana_agent_enabled = true
 *   grafana_agent_config = {
 *     remote_write_urls = {
 *       metrics = "https://prometheus-foobar.grafana.net/api/prom/push"
 *       logs    = "https://logs-foobar.grafana.net/api/prom/push"
 *       traces  = "tempo-eu-west-0.grafana.net:443"
 *     }
 *     credentials = {
 *       metrics_username = jsondecode(data.azurerm_key_vault_secret.grafana_agent_credentials.value).metrics_username
 *       metrics_password = jsondecode(data.azurerm_key_vault_secret.grafana_agent_credentials.value).metrics_password
 *       logs_username    = jsondecode(data.azurerm_key_vault_secret.grafana_agent_credentials.value).logs_username
 *       logs_password    = jsondecode(data.azurerm_key_vault_secret.grafana_agent_credentials.value).logs_password
 *       traces_username  = jsondecode(data.azurerm_key_vault_secret.grafana_agent_credentials.value).traces_username
 *       traces_password  = jsondecode(data.azurerm_key_vault_secret.grafana_agent_credentials.value).traces_password
 *     }
 *   }
 * }
 * ```
 *
*/

terraform {
  required_version = "0.15.3"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.6.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.3.0"
    }
  }
}

resource "kubernetes_namespace" "this" {
  metadata {
    labels = {
      name                = "grafana-agent"
      "xkf.xenit.io/kind" = "platform"
    }
    name = "grafana-agent"
  }
}

resource "kubernetes_secret" "this" {
  metadata {
    name      = "grafana-agent-credentials"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    metrics_username = var.credentials.metrics_username
    metrics_password = var.credentials.metrics_password
    logs_username    = var.credentials.logs_username
    logs_password    = var.credentials.logs_password
    traces_username  = var.credentials.traces_username
    traces_password  = var.credentials.traces_password
  }
}

locals {
  values = templatefile("${path.module}/templates/values.yaml.tpl", {
    credentials_secret_name  = kubernetes_secret.this.metadata[0].name
    remote_write_metrics_url = var.remote_write_urls.metrics
    remote_write_logs_url    = var.remote_write_urls.logs
    remote_write_traces_url  = var.remote_write_urls.traces
    environment              = var.environment
    cluster_name             = var.cluster_name
  })
}

resource "helm_release" "grafana_agent_operator" {
  repository  = "https://grafana.github.io/helm-charts"
  chart       = "grafana-agent-operator"
  name        = "grafana-agent-operator"
  namespace   = kubernetes_namespace.this.metadata[0].name
  version     = "0.1.4"
  max_history = 3

  set {
    name  = "kubeletService.namespace"
    value = kubernetes_namespace.this.metadata[0].name
  }
}

resource "helm_release" "grafana_agent_extras" {
  depends_on = [helm_release.grafana_agent_operator]

  chart       = "${path.module}/charts/grafana-agent-extras"
  name        = "grafana-agent-extras"
  namespace   = kubernetes_namespace.this.metadata[0].name
  max_history = 3
  values      = [local.values]
}
