# Using Kind Cluster to setup KubeVirt with OpenTofu

This project uses OpenTofu to provision a local Kind Kubernetes cluster. It leverages Rancher Desktop configured with the **`moby` (Docker)** container engine. This will setup a **KubeVirt** environment to PoC the capability of VM management under K8S.

The setup utilizes OpenTofu's `null_resource` with `local-exec` provisioners to execute `kind` CLI commands for reliable cluster creation and `virtctl init` for VM support.

## Prerequisites

Ensure the following tools are installed on your macOS system **and accessible in your terminal's `PATH`**:

1.  **Homebrew:** (Recommended package manager for macOS)
    If not installed, run:
    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```
    Ensure your shell environment is configured for Homebrew (run `brew doctor` for guidance).

2.  **OpenTofu:** (Infrastructure as Code Tool)
    ```bash
    brew install opentofu
    tofu --version
    ```

3.  **Rancher Desktop:** (Container Management Application)
    *   Download and install from the [Rancher Desktop website](https://rancherdesktop.io/).
    *   Configure using the **`moby` engine** (see **Rancher Desktop Configuration** section below).

4.  **Kind:** (Kubernetes IN Docker)
    *   The `kind` CLI is **required** as it's called directly by the OpenTofu configuration.
    ```bash
    brew install kind
    kind version
    which kind # Should output a path like /opt/homebrew/bin/kind or /usr/local/bin/kind
    ```

5.  **kubectl:** (Kubernetes Command-Line Tool)
    ```bash
    brew install kubectl
    kubectl version --client
    which kubectl
    ```

6.  **clusterctl:** (Cluster API Command-Line Tool)
    *   `clusterctl` is **required** as it's called directly by the OpenTofu configuration and used for workload cluster management.
    ```bash
    brew install clusterctl
    clusterctl version
    which clusterctl # Should output a path like /opt/homebrew/bin/clusterctl
    ```

7.  **KubeVirt:** (K8S VM support)
    *   `virtctl` is **required** as it's called directly by the OpenTofu configuration, via provisioners.

## Rancher Desktop Configuration

This setup requires using the **`moby`** container engine in Rancher Desktop for reliable `kind` operation.

1.  **Open Rancher Desktop Preferences.**
2.  Go to **"Container Engine"**.
3.  **Select `dockerd (moby)`** as the container runtime.
4.  **Apply & Restart:** Apply the changes and let Rancher Desktop restart its backend.

This ensures a standard Docker socket (`/var/run/docker.sock`) is natively available, which `kind` requires.

*(Note: While using `containerd` as the Rancher Desktop engine is possible, it relies on a Docker socket compatibility layer provided by Rancher Desktop that can sometimes be problematic. If you encounter `docker ps ... exit status 1` errors when using `containerd` mode, switching to the `moby` engine is the recommended solution for this guide.)*

**Verify the Docker connection:**
```bash
docker ps                     # Should run without error (list headers or containers)
```
