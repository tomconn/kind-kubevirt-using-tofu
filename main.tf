provider "kind" {
  # Provider block still needed, even if not creating cluster resource directly
}

# Use null_resource to manage the kind cluster lifecycle via CLI commands
resource "null_resource" "kind_cluster_manager" {
  triggers = {
    cluster_name = var.cluster_name
    node_image   = var.kind_node_image
    config_sha1  = filesha1("${path.module}/kind-config.yaml")
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOT
      echo "Creating Kind cluster '${self.triggers.cluster_name}' with config '${path.module}/kind-config.yaml'..."
      if ! command -v jq &> /dev/null; then
        echo "jq is not installed. Please install jq to proceed."
        exit 1
      fi
      if ! command -v curl &> /dev/null; then
        echo "curl is not installed. Please install curl to proceed."
        exit 1
      fi
      kind create cluster \
        --name "${self.triggers.cluster_name}" \
        --image "${self.triggers.node_image}" \
        --config "${path.module}/kind-config.yaml" \
        --wait 5m && \
      echo "Kind cluster created. Saving kubeconfig..." && \
      kind get kubeconfig --name "${self.triggers.cluster_name}" > "${path.module}/kubeconfig-${self.triggers.cluster_name}.yaml" && \
      echo "Kubeconfig saved to ${path.module}/kubeconfig-${self.triggers.cluster_name}.yaml"
    EOT
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "echo 'Deleting Kind cluster ${self.triggers.cluster_name}...' && kind delete cluster --name ${self.triggers.cluster_name}"
    interpreter = ["bash", "-c"]
    on_failure  = continue # Allow destroy to proceed even if cluster is already gone
  }
}

# Install KubeVirt
resource "null_resource" "kubevirt_installation" {
  depends_on = [null_resource.kind_cluster_manager]

  triggers = {
    cluster_manager_id = null_resource.kind_cluster_manager.id
    cluster_name       = null_resource.kind_cluster_manager.triggers.cluster_name
    kubevirt_version   = var.kubevirt_version
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e # Exit immediately if a command exits with a non-zero status.
      set -x # Print commands and their arguments as they are executed.

      export KUBECONFIG="${path.module}/kubeconfig-${self.triggers.cluster_name}.yaml"
      echo "KUBECONFIG is: $KUBECONFIG"

      echo "Listing CRDs before KubeVirt installation (should be empty or non-kubevirt):"
      kubectl get crds || echo "No CRDs found yet or kubectl failed to list them."

      echo "Waiting for nodes in cluster '${self.triggers.cluster_name}' to be ready..."
      kubectl wait --for=condition=Ready node --all --timeout=3m
      echo "Nodes ready. Proceeding with KubeVirt installation."

      EFFECTIVE_KUBEVIRT_VERSION=""
      if [ "${self.triggers.kubevirt_version}" = "latest" ]; then
        echo "Fetching latest KubeVirt version..."
        # Use -L to follow redirects for curl
        EFFECTIVE_KUBEVIRT_VERSION=$(curl -sL https://api.github.com/repos/kubevirt/kubevirt/releases/latest | jq -r .tag_name)
        if [ -z "$EFFECTIVE_KUBEVIRT_VERSION" ] || [ "$EFFECTIVE_KUBEVIRT_VERSION" = "null" ] || [ "$EFFECTIVE_KUBEVIRT_VERSION" = "" ]; then
          echo "Failed to fetch latest KubeVirt version. Raw curl output:"
          curl -sL https://api.github.com/repos/kubevirt/kubevirt/releases/latest
          echo "Exiting."
          exit 1
        fi
        echo "Fetched latest KubeVirt version: $EFFECTIVE_KUBEVIRT_VERSION"
      else
        EFFECTIVE_KUBEVIRT_VERSION="${self.triggers.kubevirt_version}"
        echo "Using specified KubeVirt version: $EFFECTIVE_KUBEVIRT_VERSION"
      fi

      OPERATOR_URL="https://github.com/kubevirt/kubevirt/releases/download/$EFFECTIVE_KUBEVIRT_VERSION/kubevirt-operator.yaml"
      CR_URL="https://github.com/kubevirt/kubevirt/releases/download/$EFFECTIVE_KUBEVIRT_VERSION/kubevirt-cr.yaml"

      echo "Operator URL: $OPERATOR_URL"
      echo "CR URL: $CR_URL"

      echo "Deploying KubeVirt operator from $OPERATOR_URL ..."
      kubectl apply -f "$OPERATOR_URL"
      echo "KubeVirt operator apply initiated."

      echo "Waiting for KubeVirt Operator deployment (virt-operator) to be ready..."
      kubectl rollout status deployment/virt-operator -n kubevirt --timeout=3m

      echo "Deploying KubeVirt CR (which creates KubeVirt instance for operator to act on) from $CR_URL ..."
      kubectl apply -f "$CR_URL"
      echo "KubeVirt CR apply initiated."

      # The virt-operator will now see the 'kubevirt.kubevirt.io/kubevirt' CR instance
      # and start deploying all other KubeVirt components and their respective CRDs.

      echo "Waiting for KubeVirt components to be deployed and the KubeVirt CR 'kubevirt' to report Available..."
      echo "This step implies that the virt-operator has successfully created other CRDs like virtualmachines.kubevirt.io."
      kubectl -n kubevirt wait --for=condition=Available KubeVirt kubevirt --timeout=6m # Increased timeout slightly just in case
      echo "KubeVirt installation status: KubeVirt resource 'kubevirt' is Available."

      echo "Checking for critical KubeVirt CRDs AFTER KubeVirt CR is Available..."
      kubectl get crd virtualmachines.kubevirt.io || (echo "ERROR: virtualmachines.kubevirt.io CRD not found AFTER KubeVirt CR reported Available!" && exit 1)
      kubectl get crd virtualmachineinstances.kubevirt.io || (echo "ERROR: virtualmachineinstances.kubevirt.io CRD not found AFTER KubeVirt CR reported Available!" && exit 1)
      kubectl get crd kubevirts.kubevirt.io || (echo "ERROR: kubevirts.kubevirt.io CRD somehow missing (should have been created by operator.yaml)!" && exit 1)
      echo "Critical KubeVirt CRDs found as expected."

      echo "Attempting to install virtctl (KubeVirt CLI) for macOS host..."
      VIRTCTL_OS="darwin" # We are running this on macOS
      VIRTCTL_ARCH_SUFFIX=""
      NATIVE_ARCH=$(uname -m) # This will be arm64 on your Mac

      # KubeVirt release assets use 'arm64' for Darwin, and 'amd64' for Darwin x86_64
      if [ "$NATIVE_ARCH" = "arm64" ]; then # uname -m on Apple Silicon Mac returns arm64
        VIRTCTL_ARCH_SUFFIX="arm64"
      elif [ "$NATIVE_ARCH" = "x86_64" ]; then
        VIRTCTL_ARCH_SUFFIX="amd64"
      else
        echo "Warning: Unsupported macOS architecture for virtctl auto-download: $NATIVE_ARCH. Manual download might be needed."
        # Defaulting to arm64 as it's more common for new Macs, but this case should ideally not be hit.
        VIRTCTL_ARCH_SUFFIX="arm64" 
      fi

      echo "Downloading virtctl for $VIRTCTL_OS-$VIRTCTL_ARCH_SUFFIX..."
      curl -L -o virtctl "https://github.com/kubevirt/kubevirt/releases/download/$EFFECTIVE_KUBEVIRT_VERSION/virtctl-$EFFECTIVE_KUBEVIRT_VERSION-$VIRTCTL_OS-$VIRTCTL_ARCH_SUFFIX"
      chmod +x virtctl
      echo "virtctl downloaded to ./virtctl. You might want to move it to your PATH, e.g., sudo mv ./virtctl /usr/local/bin/"
      
      echo "Running ./virtctl version..."
      ./virtctl version # Quick check if virtctl runs and can connect
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Deploy a sample KubeVirt Virtual Machine
resource "null_resource" "kubevirt_sample_vm" {
  depends_on = [null_resource.kubevirt_installation]

  triggers = {
    kubevirt_ready_id = null_resource.kubevirt_installation.id
    cluster_name      = null_resource.kind_cluster_manager.triggers.cluster_name
    vm_name           = var.kubevirt_vm_name
    vm_image          = var.kubevirt_vm_image
    # Add a trigger for the template file itself, so if you change the template, it re-applies
    vm_template_sha1  = filesha1("${path.module}/vm-template.yaml")
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e # Exit immediately if a command exits with a non-zero status.
      set -x # Print commands as they are executed.

      export KUBECONFIG="${path.module}/kubeconfig-${self.triggers.cluster_name}.yaml"
      echo "KUBECONFIG is $KUBECONFIG"
      echo "Deploying sample KubeVirt VM '${self.triggers.vm_name}' using image '${self.triggers.vm_image}' from template '${path.module}/vm-template.yaml'..."

      # Check if kubectl can connect and if KubeVirt API is available
      kubectl version --short || (echo "kubectl cannot connect to cluster. Exiting." && exit 1)
      kubectl api-resources --api-group=kubevirt.io | grep -q virtualmachineinstances || \
        (echo "KubeVirt API group not found or virtualmachineinstances CRD missing. KubeVirt might not be ready. Exiting." && exit 1)

      # Prepare the VM manifest from the template using sed for replacements
      # Note the use of a different delimiter for sed (#) in case vm_image contains slashes.
      # Ensure placeholders in vm-template.yaml are unique and unlikely to clash.
      sed \
        -e "s#__VM_NAME__#${self.triggers.vm_name}#g" \
        -e "s#__VM_IMAGE__#${self.triggers.vm_image}#g" \
        "${path.module}/vm-template.yaml" | kubectl apply -f -

      echo "VirtualMachine object '${self.triggers.vm_name}' apply command executed."
      echo "Waiting for VMI (VirtualMachineInstance) '${self.triggers.vm_name}' to be created by the VM controller..."
      
      TIMEOUT_VMI_CREATION=180 
      COUNTER=0
      while ! kubectl get vmi "${self.triggers.vm_name}" -n default > /dev/null 2>&1; do
        sleep 5
        COUNTER=$((COUNTER+5))
        if [ $COUNTER -ge $TIMEOUT_VMI_CREATION ]; then
          echo "Timeout waiting for VMI object '${self.triggers.vm_name}' to be created."
          echo "Dumping VM spec for debugging:"
          kubectl get vm "${self.triggers.vm_name}" -o yaml
          echo "Dumping VM events for debugging:"
          kubectl get events --field-selector involvedObject.kind=VirtualMachine,involvedObject.name=${self.triggers.vm_name}
          exit 1
        fi
        echo "VMI '${self.triggers.vm_name}' not yet created by controller, waiting... ($COUNTER/$TIMEOUT_VMI_CREATION)"
      done
      echo "VMI object '${self.triggers.vm_name}' created. Now waiting for it to be Ready..."

      kubectl wait --for=condition=Ready vmi/"${self.triggers.vm_name}" --timeout=5m -n default

      echo "Sample KubeVirt ARM64 VM '${self.triggers.vm_name}' is Running."
      echo "To access its console (if ./virtctl is available or virtctl is in your PATH):"
      echo "KUBECONFIG=${path.module}/kubeconfig-${self.triggers.cluster_name}.yaml ./virtctl console ${self.triggers.vm_name}"
    EOT
    interpreter = ["bash", "-c"]
  }
}