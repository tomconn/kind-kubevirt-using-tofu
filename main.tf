terraform {
  required_providers {
    kind = {
      source  = "registry.opentofu.org/tehcyx/kind"
      version = "0.8.0"
    }
    kubernetes = { # Still needed if we add k8s resources later
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    # cloudinit and others can be commented out if not used by this test
  }
}

resource "kind_cluster" "this" {
  name           = var.cluster_name
  node_image     = var.kind_node_image
  wait_for_ready = true
  # kubeconfig_output_path is still causing issues for this provider,
  # so we rely on its computed kubeconfig_path output (temp file)
}

provider "kubernetes" { # Keep for potential future use, or if Helm provider needs it defined
  config_path = kind_cluster.this.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = kind_cluster.this.kubeconfig_path
  }
}

resource "helm_release" "test_apache" {
  depends_on = [kind_cluster.this]

  name       = "my-apache-test"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "apache"
  namespace  = "default"
  version    = "11.0.6"  # Or your verified current version

  # Values to make it simpler for Kind
  set {
    name  = "persistence.enabled"
    value = "false" # Disable PVCs
  }
  set {
    name  = "service.type"
    value = "NodePort"
  }
  set {
    name  = "service.nodePorts.http" # Path to set the http nodePort for Bitnami Apache
    value = var.apache_node_port # Example, pick an unused port
  }
  set {
     name = "replicaCount"
     value = "1"
  }

  # Increase timeout if startup is just slow, but 5 min should be enough for Apache
  timeout = 300 #
  wait    = true
  # atomic = true # Add this so if it fails, Helm tries to roll back the failed release.
}

output "kind_cluster_name_out" {
  value = kind_cluster.this.name
}

output "kind_kubeconfig_path_out" {
  value = kind_cluster.this.kubeconfig_path
}

output "apache_test_status" {
  value = helm_release.test_apache.status
}