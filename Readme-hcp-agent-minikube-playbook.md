# TF-02 Playbook: HCP Terraform Agent + Minikube

## 1. Purpose

This playbook explains how to run Terraform remotely through an HCP Terraform Agent while the Terraform Kubernetes provider connects to a Minikube cluster running on the agent host.

The setup is designed for learning without AWS infrastructure or AWS-related costs.

The completed workflow provides:

- HCP Terraform cloud backend for remote state.
- HCP Terraform CLI-driven workspace.
- HCP Terraform Agent execution.
- Minikube running locally with the Docker driver.
- Terraform Kubernetes provider running inside the agent.
- Kubernetes resources managed in Minikube.
- Make targets for repeatable setup, testing, planning, applying, and verification.

## 2. Architecture

```text
Developer WSL terminal
        |
        | terraform init / plan / apply
        v
HCP Terraform workspace
        |
        | assigns run to agent pool
        v
HCP Terraform Agent container
        |
        | Kubernetes provider + embedded kubeconfig
        v
Minikube Docker container
        |
        v
Kubernetes API server
```

The important distinction is:

- HCP Terraform stores state and coordinates runs.
- The HCP Agent executes Terraform.
- Minikube is reachable from the agent host/network.
- The Kubernetes provider operates from the agent container, not from the developer's shell.

## 3. Repository layout

A suitable layout is:

```text
terraform-hcp-remote-state-using-hcp-agent/
├── Makefile
├── Makefile_HCP_TR
├── platform-infra/
│   ├── environments/
│   │   └── dev/
│   │       ├── backend.tf
│   │       ├── main.tf
│   │       ├── outputs.tf
│   │       ├── terraform.tfvars
│   │       └── variables.tf
│   └── modules/
│       ├── network/
│       └── cluster/
└── .gitignore
```

For a CLI-driven HCP Terraform workspace, the root module must be uploaded correctly. Relative module paths such as `../../modules/network` must exist in the configuration sent to HCP Terraform. If the workspace receives only the `dev` directory, keep the modules inside the uploaded configuration or use a VCS working directory configured against the repository layout.

## 4. HCP Terraform configuration

### 4.1 Create the organization

Create or use an HCP Terraform organization, for example:

```text
hcrmapp-platform-lab
```

### 4.2 Create the workspace

Create a workspace with:

```text
Workspace type: CLI-driven
Workspace name: tf02-hcp-remote-state-dev-hcp-agent
Execution mode: Agent
Agent pool: hcp-agent-minikube-wsl-pool
```

The workspace must use the same organization and workspace name configured in `backend.tf`.

### 4.3 Create the agent pool and token

Create an agent pool named:

```text
hcp-agent-minikube-wsl-pool
```

Create an agent token for that pool. Do not commit the token to Git.

## 5. Terraform backend

File:

```text
platform-infra/environments/dev/backend.tf
```

Example:

```hcl
terraform {
  required_version = "1.15.8"

  cloud {
    organization = "hcrmapp-platform-lab"

    workspaces {
      name = "tf02-hcp-remote-state-dev-hcp-agent"
    }
  }
}
```

This changes the state location from a local `terraform.tfstate` file to the HCP Terraform workspace.

## 6. Terraform provider configuration

File:

```text
platform-infra/environments/dev/main.tf
```

Example:

```hcl
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_namespace" "imported" {
  metadata {
    name = "import-lab"
  }
}
```

Inside the agent container, `~` resolves to the agent user's home directory. The agent must therefore have a readable file at:

```text
/home/tfc-agent/.kube/config
```

## 7. Kubernetes resources and import demonstration

To demonstrate import:

1. Create the namespace outside Terraform:

   ```bash
   kubectl create namespace import-lab
   ```

2. Confirm it exists:

   ```bash
   kubectl get namespace import-lab
   ```

3. Import it into Terraform only if it is not already in state:

   ```bash
   terraform import kubernetes_namespace.imported import-lab
   ```

Do not import the same address twice. If Terraform reports that the resource is already managed, inspect state first:

```bash
terraform state list
```

If the address is already present, the import has already been completed.

## 8. Minikube setup

Start Minikube with the Docker driver:

```bash
minikube start --driver=docker
```

Verify Minikube from WSL:

```bash
minikube status
kubectl config current-context
kubectl get nodes
```

The current context should be:

```text
minikube
```

The node should be `Ready`.

## 9. Agent-compatible kubeconfig

### 9.1 Why a normal kubeconfig fails

A Minikube kubeconfig often references host files such as:

```text
/home/hcrmapp/.minikube/profiles/minikube/client.crt
/home/hcrmapp/.minikube/profiles/minikube/client.key
/home/hcrmapp/.minikube/ca.crt
```

Those paths do not exist inside the agent container unless `.minikube` is mounted. The private key may also be unreadable because the container user differs from the WSL user.

### 9.2 Generate a container-compatible kubeconfig

Create a dedicated directory:

```bash
mkdir -p "$HOME/tfc-agent-kube"
```

Generate a kubeconfig with certificates embedded:

```bash
kubectl config view \
  --raw \
  --minify \
  --flatten \
  > "$HOME/tfc-agent-kube/config"
```

Find the Minikube container IP:

```bash
docker inspect minikube \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

Assume the result is:

```text
192.168.67.2
```

Update the Kubernetes API endpoint to use the Minikube Docker-network address and internal API port:

```bash
kubectl config set-cluster minikube \
  --kubeconfig="$HOME/tfc-agent-kube/config" \
  --server="https://192.168.67.2:8443"
```

Set permissions for this local lab configuration:

```bash
chmod 755 "$HOME/tfc-agent-kube"
chmod 644 "$HOME/tfc-agent-kube/config"
```

This file contains Kubernetes client authentication material. Do not commit it.

## 10. Docker connectivity test

Test Kubernetes access from a container attached to the Minikube network:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --network minikube \
  -v "$HOME/tfc-agent-kube:/home/tfc-agent/.kube:ro" \
  -e KUBECONFIG=/home/tfc-agent/.kube/config \
  bitnami/kubectl:latest \
  get nodes
```

Expected result:

```text
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   ...   v1.35.4
```

Do not use `127.0.0.1:<published-port>` as the API endpoint from a container. Inside a container, `127.0.0.1` refers to that container itself.

## 11. Start the HCP Terraform Agent

Export the agent token in the terminal where the agent will run:

```bash
export TFC_AGENT_TOKEN="your-agent-pool-token"
```

Start the agent:

```bash
docker run --rm \
  --name hcp-agent-minikube \
  --network minikube \
  -e TFC_AGENT_TOKEN \
  -e TFC_AGENT_NAME=minikube-wsl-agent \
  -e KUBECONFIG=/home/tfc-agent/.kube/config \
  -v "$HOME/tfc-agent-kube:/home/tfc-agent/.kube:ro" \
  hashicorp/tfc-agent:1.30.1
```

Expected log messages:

```text
Agent registered successfully with HCP Terraform
Waiting for next job
```

Keep this terminal open. The agent is a foreground process and must remain running to receive jobs.

## 12. Make targets

The recommended target sequence is:

```bash
make tf-agent-prepare-kubeconfig
make tf-agent-test-minikube
make tf-agent-start
```

Run `tf-agent-start` in one terminal. In another terminal, run the Terraform workflow.

Useful targets:

```bash
# Check required tools and Docker
make tf-agent-check-tools

# Check the HCP agent token
make tf-agent-check-token

# Check Minikube status
make tf-agent-check-minikube

# Display the Minikube Docker IP and ports
make tf-agent-show-minikube-network

# Generate the embedded kubeconfig
make tf-agent-prepare-kubeconfig

# Display the kubeconfig endpoint without printing credentials
make tf-agent-show-kubeconfig

# Test kubectl from a Docker container
make tf-agent-test-minikube

# Start the HCP Terraform agent
make tf-agent-start

# Display agent container status
make tf-agent-status

# Stop the agent container
make tf-agent-stop

# Delete generated kubeconfig files
make tf-agent-clean-kubeconfig
```

A combined preparation workflow can be:

```bash
make tf-agent-workflow
```

Then start the agent:

```bash
make tf-agent-start
```

## 13. Terraform workflow

With the agent running, use a second terminal:

```bash
make tf-init TF_ENV=dev
make tf-fmt TF_ENV=dev
make tf-validate TF_ENV=dev
make tf-plan TF_ENV=dev
make tf-apply TF_ENV=dev
make tf-verify-post-apply TF_ENV=dev
```

Or run the guided workflow:

```bash
make tf-workflow-with-hcp-terraform-as-remote-backend-for-state-init-plan-apply-verify-destroy
```

The expected sequence is:

```text
Terraform CLI
  -> HCP Terraform workspace
  -> HCP Terraform agent
  -> Kubernetes provider
  -> Minikube Kubernetes API
```

After apply, verify from WSL:

```bash
kubectl get namespaces
kubectl get namespace import-lab
```

## 14. Verification configuration

The verification Makefile must match the current Terraform configuration.

If the root module exposes only these outputs:

```text
vpc_id
cluster_name
```

then use:

```make
EXPECTED_OUTPUTS ?= vpc_id cluster_name
```

Do not keep outputs from an older exercise, such as:

```text
environment_name
environment_id_hex
environment_id_base64url
```

unless those outputs are actually defined in the current root module.

Inspect the actual remote outputs with:

```bash
cd platform-infra/environments/dev
terraform output
terraform output -json
terraform state list
cd -
```

The expected state list must use exact Terraform addresses, for example:

```make
EXPECTED_STATE ?= \
    module.network.random_pet.vpc_name \
    module.network.random_id.vpc_id \
    module.cluster.random_pet.cluster_name \
    kubernetes_namespace.imported
```

## 15. Avoid `local_file` in remote runs

`local_file` resources write files into the temporary filesystem used by the agent. A later remote run may use a different directory, so Terraform can report:

```text
Drift detected (delete)
```

For TF-02, prefer remote-state outputs and Kubernetes resources. Remove `local_file` resources after the local-backend fundamentals exercise, unless the file is deliberately part of a short-lived demonstration.

If `local_file` resources are removed, also remove the `local` provider if it is no longer needed.

## 16. Troubleshooting

### Error: token is required

Cause: `TFC_AGENT_TOKEN` is not available to the agent container.

Fix:

```bash
export TFC_AGENT_TOKEN="your-agent-pool-token"
make tf-agent-start
```

### Error: unable to read client-key

Cause: the container cannot access host certificate files or the private key permissions are too restrictive.

Fix: generate an embedded kubeconfig:

```bash
kubectl config view --raw --minify --flatten \
  > "$HOME/tfc-agent-kube/config"
```

### Error: `/home/tfc-agent/.kube/config: permission denied`

Cause: the mounted config is mode `600` and the agent user cannot read it.

Fix:

```bash
chmod 755 "$HOME/tfc-agent-kube"
chmod 644 "$HOME/tfc-agent-kube/config"
```

Restart the agent after changing the file.

### Error: module directory does not exist

Cause: HCP Terraform received the environment directory but not the relative module directories.

Fix one of the following:

- Use a VCS workspace with repository root and the correct working directory.
- Include modules inside the uploaded configuration.
- Make the TF-02 root module self-contained.

### Error: resource already managed by Terraform

Cause: an import is being attempted for an address already in state.

Check:

```bash
terraform state list
```

If the address exists, skip the import.

### Error: missing expected output

Cause: the Makefile verifier expects an output not defined in the current Terraform root module.

Check:

```bash
terraform output
```

Then update `EXPECTED_OUTPUTS`.

### Plan repeatedly recreates local files

Cause: remote-agent execution uses temporary filesystems.

Fix: remove `local_file` resources for the remote-agent exercise.

## 17. Security guidance

- Never commit `TFC_AGENT_TOKEN`.
- Never commit `$HOME/tfc-agent-kube`.
- Add the following to `.gitignore`:

  ```gitignore
  tfc-agent-kube/
  ```

- Treat the generated kubeconfig as a credential because it contains client authentication data.
- Use a dedicated Minikube cluster and HCP Terraform workspace for learning.
- Do not use production kubeconfig files in this lab.
- Stop the agent when the exercise is complete.
- Delete the generated kubeconfig when finished:

  ```bash
  make tf-agent-clean-kubeconfig
  ```

## 18. Clean-up

Stop the agent:

```bash
make tf-agent-stop
```

Delete generated credentials:

```bash
make tf-agent-clean-kubeconfig
```

Delete the Kubernetes namespace if desired:

```bash
kubectl delete namespace import-lab
```

Stop Minikube if it is no longer needed:

```bash
minikube stop
```

Delete Minikube completely only if you want to remove the local cluster:

```bash
minikube delete
```

## 19. Learning outcomes

After completing this playbook, a newcomer should understand:

- The difference between local Terraform execution and agent execution.
- How HCP Terraform stores remote state.
- How a CLI-driven workspace sends runs to an agent.
- Why the agent must be able to reach the private target system.
- Why a kubeconfig containing host-specific paths does not work automatically inside a container.
- Why embedded certificate data simplifies container access.
- How Terraform provider configuration is evaluated on the agent host.
- How Terraform state addresses differ from Kubernetes object names.
- Why remote execution changes how local filesystem resources behave.

## 20. Suggested commit message

Recommended commit message:

```text
feat(tf02): add HCP agent Minikube remote execution playbook
```

Alternative with a longer body:

```text
feat(tf02): add HCP agent Minikube remote execution workflow

- configure HCP Terraform cloud backend
- document CLI-driven agent execution
- add embedded Minikube kubeconfig preparation
- add Docker-to-Min ikube connectivity checks
- document Kubernetes provider configuration
- align post-apply verification with current outputs and state
- document troubleshooting and cleanup steps
```

Before committing, run:

```bash
terraform fmt -recursive platform-infra
make tf-agent-test-minikube
make tf-validate TF_ENV=dev
make tf-plan TF_ENV=dev
```
'''