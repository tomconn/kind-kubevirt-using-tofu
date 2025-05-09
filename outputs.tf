output "kind_cluster_name" {
  description = "Name of the created Kind cluster."
  value       = null_resource.kind_cluster_manager.triggers.cluster_name
  depends_on  = [null_resource.kind_cluster_manager]
}

output "kind_kubeconfig_path" {
  description = "Path to the generated kubeconfig file for the Kind cluster."
  value       = "${path.module}/kubeconfig-${null_resource.kind_cluster_manager.triggers.cluster_name}.yaml"
  depends_on  = [null_resource.kind_cluster_manager]
}

output "kubevirt_version_installed" {
  description = "Effective KubeVirt version that was attempted to be installed."
  # This relies on the trigger value, which captures the input var.kubevirt_version
  # If var.kubevirt_version is "latest", this will output "latest".
  # For the actual resolved version, one would need to parse the local-exec output,
  # which is more complex and generally not done with null_resource outputs directly.
  value       = null_resource.kubevirt_installation.triggers.kubevirt_version
  depends_on  = [null_resource.kubevirt_installation]
}

output "sample_vm_name" {
  description = "Name of the deployed sample KubeVirt VM."
  value       = var.kubevirt_vm_name
  depends_on  = [null_resource.kubevirt_sample_vm]
}

output "sample_vm_instructions" {
  description = "Instructions to interact with the sample VM."
  value       = "To access the VM console: Ensure virtctl (downloaded during KubeVirt installation) is in your PATH, then run: KUBECONFIG=${path.module}/kubeconfig-${null_resource.kind_cluster_manager.triggers.cluster_name}.yaml virtctl console ${var.kubevirt_vm_name}"
  depends_on  = [null_resource.kubevirt_sample_vm]
}