variable "cluster_name" {
  description = "Name for the Kind cluster"
  type        = string
  default     = "kubevirt-tofu-demo" # Or "test-kind-cluster" from the minimal example
}

variable "kind_node_image" {
  description = "Kind node image to use (e.g., kindest/node:v1.27.3). Check Kind releases for compatible images."
  type        = string
  default     = "kindest/node:v1.29.0"
}

variable "kubevirt_helm_chart_version" {
  description = "Kubevirt Helm chart version to install (e.g., v1.2.0)"
  type        = string
  default     = "v1.2.0" # Match this with a Kubevirt application release version
}

variable "vm_namespace" {
  description = "Namespace to deploy the VM into"
  type        = string
  default     = "default"
}

variable "vm_name" {
  description = "Name for the Apache VM"
  type        = string
  default     = "fedora-apache-vm"
}

variable "vm_containerdisk_image" {
  description = "Public containerDisk image for the VM (e.g., quay.io/containerdisks/fedora:40)"
  type        = string
  default     = "quay.io/containerdisks/fedora:40" # Using Fedora 40 for this example
}

variable "vm_memory" {
  description = "Memory to allocate to the VM (e.g., 1Gi, 2048Mi)"
  type        = string
  default     = "1Gi"
}

variable "vm_vcpu" {
  description = "Number of vCPUs for the VM"
  type        = number
  default     = 1
}

variable "apache_node_port" {
  description = "NodePort for accessing the Apache server on the VM"
  type        = number
  default     = 30080
  validation {
    condition     = var.apache_node_port >= 30000 && var.apache_node_port <= 32767
    error_message = "NodePort must be between 30000 and 32767."
  }
}