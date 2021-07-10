/**
  * # Ingress Healthz (ingress-healthz)
  *
  * This module is used to deploy a very simple NGINX server meant to check the health of cluster ingress.
  * It is meant to simulate an application that expects traffic through the ingress controller with
  * automatic DNS creation and certificate creation, without depending on the stability of a dynamic application.
  */

terraform {
  required_version = "0.15.3"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.3.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.2.0"
    }
  }
}

resource "kubernetes_namespace" "this" {
  metadata {
    labels = {
      name                = "ingress-healthz"
      "xkf.xenit.io/kind" = "platform"
    }
    name = "ingress-healthz"
  }
}

resource "kubernetes_network_policy" "deny_default" {
  metadata {
    name      = "deny-default"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {}
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        pod_selector {}
      }
    }

    egress {
      to {
        namespace_selector {}
        pod_selector {
          match_labels = {
            k8s-app = "kube-dns"
          }
        }
      }

      ports {
        port     = 53
        protocol = "UDP"
      }
    }

    egress {
      to {
        pod_selector {}
      }
    }
  }
}

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: ingress-healthz
      app.kubernetes.io/name: nginx
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
          podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
              app.kubernetes.io/component: controller
      ports:
        - port: 8080

resource "kubernetes_network_policy" "allow_ingress" {
  metadata {
    name      = "allow-ingress"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app.kubernetes.io/instance = ingress-healthz
        app.kubernetes.io/name = nginx
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = ingress-nginx
          }
        }
        pod_selector {
          match_labels = {
            app.kubernetes.io/name = ingress-nginx
            app.kubernetes.io/component = controller
          }
        }
      }
      ports {
        port = "8080"
        protocol = "TCP"
      }
    }
  }
}

resource "helm_release" "ingress_healthz" {
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  name       = "ingress-healthz"
  namespace  = kubernetes_namespace.this.metadata[0].name
  version    = "9.3.6"
  values = [templatefile("${path.module}/templates/values.yaml.tpl", {
    environment     = var.environment
    dns_zone        = var.dns_zone
    linkerd_enabled = var.linkerd_enabled
  })]
}
