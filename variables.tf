variable "cluster_name" {
  description = "Name for the Kind cluster."
  type        = string
  default     = "kubevirt-arm64-cluster" # Changed name for clarity
}

variable "kind_node_image" {
  description = "Kind node image to use (e.g., kindest/node:v1.27.3)."
  type        = string
  default     = "kindest/node:v1.27.3"
}

variable "kubevirt_version" {
  description = "KubeVirt version to install."
  type        = string
  default     = "latest"
}

variable "kubevirt_vm_name" {
  description = "Name for the sample KubeVirt VirtualMachine." # Changed from VMI to VM
  type        = string
  default     = "testvm-fedora-arm64"
}

variable "kubevirt_vm_image" {
  description = "ARM64 Container disk image for the sample KubeVirt VM."
  type        = string
  # This image has multi-arch support including arm64
  default     = "quay.io/kubevirt/fedora-cloud-container-disk-demo:latest"
  # Alternative if above doesn't work well, or for Ubuntu:
  # default     = "quay.io/kubevirt/ubuntu-cloud-container-disk-demo:latest"
}