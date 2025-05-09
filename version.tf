# versions.tf
terraform {
  required_version = ">= 1.6.0" # OpenTofu uses Terraform version constraints

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      # Use the latest available version found on the Terraform Registry
      version = "0.0.19" # Or your preferred version
    }
    # We use a null_resource with local-exec for KubeVirt and VM
    # No direct Kubernetes/Helm provider needed for this approach
  }
}