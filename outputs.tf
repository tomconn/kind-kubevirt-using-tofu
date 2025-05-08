output "kind_cluster_name" {
  description = "Name of the created Kind cluster."
  value       = kind_cluster.this.name
}

output "kind_cluster_kubeconfig" {
  description = "Kubeconfig content for the Kind cluster (sensitive)."
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}

# If the provider also outputs a kubeconfig_path when `kubeconfig_output_path` is set in the resource:
# output "kind_cluster_kubeconfig_path" {
#   description = "Path to the kubeconfig file for the Kind cluster (if generated to file)."
#   value       = kind_cluster.this.kubeconfig_path # This attribute might not exist if not writing to file
# }

output "kubevirt_status_command" {
  description = "Command to check Kubevirt pod status."
  value       = "kubectl --kubeconfig <(echo '${kind_cluster.this.kubeconfig}') get pods -n kubevirt"
}

output "vm_status_command" {
  description = "Command to check VM/VMI status."
  value       = "kubectl --kubeconfig <(echo '${kind_cluster.this.kubeconfig}') get vm,vmi -n ${var.vm_namespace}"
}

output "apache_vm_access_url" {
  description = "URL to access the Apache server in the VM (via NodePort)."
  value       = "http://localhost:${var.apache_node_port}" # On Mac/Windows with Docker Desktop/Rancher Desktop
}

output "vm_console_command" {
  description = "Command to access the VM console using virtctl."
  value       = "virtctl --kubeconfig <(echo '${kind_cluster.this.kubeconfig}') console ${var.vm_name} -n ${var.vm_namespace}"
}

output "vm_login_info" {
  description = "Login for the VM if using password auth via cloud-init."
  value       = "User: fedora, Password: fedora (Change this or use SSH keys!)"
}