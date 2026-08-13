# Project : Terraform Remote State + HCP Agent with Minikube
This project demonstrates migrating from local Terraform state to HCP Terraform remote state, 
and using HCP Terraform Agents to run Terraform against a local Minikube Kubernetes cluster on WSL2. 
It includes Makefile-driven workflows, CLI-driven runs, remote state, and agent execution with Kubernetes provider.

### A.  Repository layout
	├── Makefile
	├── Makefile_HCP_Agent_Setup
	├── Makefile_HCP_TR
	├── Makefile_Setup
	├── README.md
	└── platform-infra
	    ├── docs
	    │   ├── PLAYBOOK.md
	    └── environments
	        ├── dev
	        │   ├── backend.tf
	        │   ├── import-lab
	        │   │   └── existing.txt
	        │   ├── import_lab.tf
	        │   ├── main.tf
	        │   ├── modules
	        │   │   ├── argocd-bootstrap
	        │   │   ├── cluster
	        │   │   │   ├── README.md
	        │   │   │   ├── cluster-dev.txt
	        │   │   │   ├── main.tf
	        │   │   │   ├── outputs.tf
	        │   │   │   └── variables.tf
	        │   │   ├── governance
	        │   │   └── network
	        │   │       ├── README.md
	        │   │       ├── main.tf
	        │   │       ├── network-dev.txt
	        │   │       ├── outputs.tf
	        │   │       └── variables.tf
	        │   ├── outputs.tf
	        │   ├── terraform.tfvars
	        │   └── variables.tf
	        ├── prod
	        │   ├── backend.tf
	        │   ├── main.tf
	        │   ├── outputs.tf
	        │   ├── terraform.tfvars
	        │   └── variables.tf
	        └── staging
	            ├── backend.tf
	            ├── main.tf
	            ├── outputs.tf
	            ├── terraform.tfvars
	            └── variables.tf

### B. Repository structure
- platform-infra/environments/dev/
	- backend.tf (cloud backend pointing to HCP workspace)
	- main.tf (terraform block, Kubernetes provider, resources)
	- terraform.tfvars (env-specific inputs)
- platform-infra/modules/ (if you keep modules for other labs)
- Makefile_TR_Workflow, Makefile_HCP_TR (workflow targets)

In the README, show a small tree and explain which directory is the root module for this project.

### C. Terraform fundamentals you used
- terraform fmt, init, validate, plan, apply wired via Make targets.
- Variable usage and terraform.tfvars.
- Resource addresses, outputs, and state understanding (you already walked through these concepts earlier).

### D. Remote state with HCP Terraform (TF‑01)
How you moved from local backend to HCP Terraform:
	- terraform { cloud { organization = "..."; workspaces { name = "..." } } } in backend.tf.
	- terraform login + tf-login-cloud Make target.
	- tf-init migrating state to HCP Terraform.

Advantages you explicitly leveraged:
	- Centralized remote state and locking.
	- No S3/DynamoDB costs (important for you).
	- Run history and state browsing in the UI.

### E. HCP Terraform Agent + Minikube (TF‑02)
- Agent pool: hcp-agent-minikube-wsl-pool.
- Agent container: hashicorp/tfc-agent:1.30.1 running on WSL2, with:
	- TFC_AGENT_TOKEN and TFC_AGENT_NAME.
	- KUBECONFIG and mounted kubeconfig/certs.
- Workspace: CLI-driven, Execution Mode = Agent, using that pool.

Terraform config:
	- provider "kubernetes" using Minikube context.
	- Simple resource like kubernetes_namespace "imported" (e.g. import-lab).

Networking and kubeconfig troubleshooting you solved:
	- SL2 + Docker driver quirks (node IP not directly reachable).
	- Kubeconfig referencing certs under .minikube with absolute paths.
	- Container mount strategy for kubeconfig and .minikube certs, or using --embed-certs.

### F. Makefile-driven workflows
- Standardize the workflow across environments.
- Make it easy for someone else to run init/plan/apply with remote state and agents.
- Employers like seeing Makefiles for reproducible workflows.

### G. “What I learned” section
- Differences between local vs remote state.
- How HCP Terraform’s CLI-driven workflow bridges local development and remote execution.
- How agent execution works and why it’s useful for private networks.
- Gotchas with Minikube on WSL2 (networking, kubeconfig paths).

# terraform-hcp-remote-state-using-hcp-agent
Terraform will no longer run on the standard HCP remote runner. It will run on an HCP agent process hosted on your WSL machine, where Minikube and the kubeconfig are available. HCP agents run on infrastructure that you control and connect to an HCP Terraform agent pool. The HCP plan determines how many agents are available.

    HCP Terraform
        |
        | Agent execution
        v
    Your WSL agent host
        |
        ├── Minikube
        ├── kubectl
        └── ~/.kube/config

The HCP agent must run on the same host that can access Minikube.
For your setup, the recommended arrangement is:

        WSL Ubuntu
        ├── minikube
        ├── kubectl
        ├── ~/.kube/config

#Create an HCP agent pool
In HCP Terraform:
    1. Open your organization.
    2. Go to Settings.
    3. Open Agents.
    4. Create an agent pool:
        text
        Pool name: minikube-wsl-pool
    5. Create an agent token for that pool.
    6. Store the token securely.
        
## Please note I ran below command:
        hcrmapp@LAPTOP-IIOKPKM7:~$ uname -s
            uname -m
            Linux
            x86_64
        hcrmapp@LAPTOP-IIOKPKM7:/$ export TFC_AGENT_TOKEN=yqekw.......................................
        export TFC_AGENT_NAME=agent
        hcrmapp@LAPTOP-IIOKPKM7:/$ docker run --platform=linux/amd64   -e TFC_AGENT_TOKEN   -e TFC_AGENT_NAME   hashicorp/tfc-agent:1.30.1

## 1. Inspect the current agent container
Find the container:
    bash
    docker ps -a --filter ancestor=hashicorp/tfc-agent:1.30.1

You should see something similar to:
    text
    CONTAINER ID   IMAGE                         COMMAND       STATUS
    c13c1472a8f7   hashicorp/tfc-agent:1.30.1   ...           Up ...

The generated container name was:

    text
    sad_neumann
View its logs:
    bash
    docker logs -f sad_neumann

Expected:
    text
    Agent registered successfully with HCP Terraform
    Waiting for next job
    
The -f option follows the logs continuously. Press Ctrl+C to stop viewing logs; it does not necessarily stop the container.




Check the agent in HCP Terraform:

text
Organization
└── Settings
    └── Agents
        └── Your agent pool
            └── agent: Online
2. Stop the current container
The current container has no kubeconfig mount, so stop it:

bash
docker stop sad_neumann
docker rm sad_neumann
3. Check the container user and home directory
Before starting the corrected container, inspect the image:

bash
docker run --rm --entrypoint sh hashicorp/tfc-agent:1.30.1 \
  -c 'id; echo HOME=$HOME; pwd'
This tells you where the agent expects its home directory.

You can also inspect the existing container before deleting it:

bash
docker exec sad_neumann sh -c 'id; echo HOME=$HOME'
If the agent runs as user tfc-agent, its home will commonly be something like:

text
/home/tfc-agent
The kubeconfig must be mounted into the agent user's home directory, not necessarily /root/.kube.

4. Prepare a kubeconfig copy for the container
Do not mount your writable kubeconfig directly. Create a read-only copy:

bash
mkdir -p "$HOME/tfc-agent-kube"
cp "$HOME/.kube/config" "$HOME/tfc-agent-kube/config"
chmod 600 "$HOME/tfc-agent-kube/config"
Inspect the server address:

bash
grep 'server:' "$HOME/tfc-agent-kube/config"
Your current configuration probably contains:

text
server: https://127.0.0.1:54870
That address works from WSL, but may not work from a Docker container unless host networking is available.

5. Test Docker access to Minikube
First try a host-network test:

bash
docker run --rm \
  --network host \
  -v "$HOME/tfc-agent-kube:/home/tfc-agent/.kube:ro" \
  -e KUBECONFIG=/home/tfc-agent/.kube/config \
  hashicorp/tfc-agent:1.30.1 \
  sh -c 'command -v kubectl || true; kubectl get nodes'
If kubectl is not included in the agent image, use a separate Kubernetes test image or test connectivity with a temporary utility container.

The important result is whether the container can reach:

text
https://127.0.0.1:54870
If you receive a successful node listing, the network path works.

If you receive a connection error, the Docker container cannot reach the WSL Minikube API through 127.0.0.1. In that case, containerized agent execution becomes more complicated, and native WSL agent execution is preferable for this lab.

6. Start the agent with kubeconfig mounted
Assuming the agent user is tfc-agent, start it like this:

bash
export TFC_AGENT_TOKEN='your-new-agent-token'
export TFC_AGENT_NAME='minikube-wsl-agent'

docker run --rm \
  --name hcp-agent-minikube \
  --network host \
  -e TFC_AGENT_TOKEN \
  -e TFC_AGENT_NAME \
  -e KUBECONFIG=/home/tfc-agent/.kube/config \
  -v "$HOME/tfc-agent-kube:/home/tfc-agent/.kube:ro" \
  hashicorp/tfc-agent:1.30.1
Keep this terminal open.

You should see:

text
Agent registered successfully with HCP Terraform
Waiting for next job
The official HCP agent image is also available through Docker.

7. Important limitation with Docker Desktop and WSL
Your Minikube API endpoint is:

text
https://127.0.0.1:54870
In networking terms:

text
WSL host:
127.0.0.1:54870 → Minikube API

Container:
127.0.0.1:54870 → the container itself
Therefore, this only works if the container uses a network mode that can reach the WSL host loopback interface.

If --network host does not work with your Docker Desktop configuration, the Docker-based agent cannot directly use the current Minikube kubeconfig.

8. Alternative: use host.docker.internal
If host networking fails, inspect the Minikube IP:

bash
minikube ip --profile=minikube
For a Docker-driver Minikube cluster, test whether the API server is reachable through the Minikube host address:

bash
curl -k https://$(minikube ip):8443/version
If that works, create a separate container kubeconfig:

bash
cp "$HOME/.kube/config" "$HOME/tfc-agent-kube/config"
Then replace only the server: endpoint in the copy with the reachable Minikube address. Do not alter your original kubeconfig.

However, TLS certificate validation may fail if the Minikube certificate does not contain the replacement hostname or IP. Do not solve this by disabling TLS verification unless this is only a temporary, explicitly documented lab experiment.

For this reason, the simplest reliable approach is usually:

text
Native tfc-agent process inside WSL
rather than:

text
Dockerized tfc-agent process
9. Configure the HCP workspace
In HCP Terraform, configure the workspace used for this demonstration:

text
Execution mode: Agent
Agent pool: your Minikube agent pool
The workspace must use the same agent pool where your container registered.

When you run:

bash
terraform plan
from the CLI, the request goes to HCP Terraform. HCP assigns the run to your online agent, and the agent executes Terraform in its own environment.

10. Verify with a Terraform run
Once the agent is online and has kubeconfig access:

bash
make -f Makefile_HCP_TR tf-init TF_ENV=dev
make -f Makefile_HCP_TR tf-validate TF_ENV=dev
make -f Makefile_HCP_TR tf-plan TF_ENV=dev
Watch the agent terminal. It should show that it received a job.

If the plan works, apply:

bash
make -f Makefile_HCP_TR tf-apply TF_ENV=dev
Then verify from WSL:

bash
kubectl get namespace terraform-agent-demo
Access model summary
You access the agent in three ways:

HCP Terraform UI
Check whether it is:

text
Online
Docker logs
bash
docker logs -f hcp-agent-minikube
Terraform commands
bash
terraform plan
terraform apply
The agent itself does not expose a web interface.






Now we are done with this so lets do below:
TF-02 Minikube Terraform demonstration:
  HCP agent execution
  Minikube running on agent host
  Kubernetes provider configured on agent host



High-level steps for TF-02 Minikube + agent demo
At a high level:

Make sure Minikube is running on the same host as your Docker agent.

Create a new HCP Terraform workspace (CLI‑driven or VCS‑driven).

Set that workspace’s Execution Mode to Agent and attach your agent pool.

Add Terraform files for:

kubernetes provider configured for Minikube.

A simple resource (e.g., kubernetes_namespace).

Either:

Push the code to GitHub and let HCP Terraform pull it (VCS workflow), or

Use CLI‑driven (terraform login + cloud block) and queue runs from the CLI.

Trigger a run in HCP Terraform (queue plan/apply) and watch the agent execute it, creating resources in Minikube.




-----------------------------------------------------------------------------------------

3. Configure Minikube and kubeconfig on the agent host
On your WSL host (where Minikube runs):

Start Minikube (example using Docker driver):

bash
minikube start --driver=docker --memory=4096 --cpus=4
Ensure ~/.kube/config has the Minikube context and works:

bash
kubectl config use-context minikube
kubectl get nodes
Create the kubeconfig directory for the agent:

bash
mkdir -p "$HOME/tfc-agent-kube"
cp ~/.kube/config "$HOME/tfc-agent-kube/config"
This is the -v "$HOME/tfc-agent-kube:/home/tfc-agent/.kube:ro" mount you already used in the Docker command; it ensures the agent container can use the Minikube kubeconfig.



4. Create a dedicated workspace for TF-02
In HCP Terraform UI:

Create a new workspace, e.g. tf02-minikube-agent.

For now, pick CLI-driven or VCS-driven, depending on whether you want to wire it to GitHub immediately.

In workspace Settings → General:

Set Execution Mode to Agent.

Choose your agent pool (the one the agent logs show).

Now this workspace will send runs to your Dockerized agent instead of the default cloud executors.

kubectl delete namespace import-lab
-------------------------------------------------------------------------------------------------------------

Create a flattened kubeconfig that embeds the certificates and keys directly:

bash
mkdir -p "$HOME/tfc-agent-kube"

kubectl config view \
  --raw \
  --flatten \
  --minify \
  --context=minikube \
  > "$HOME/tfc-agent-kube/config"

chmod 600 "$HOME/tfc-agent-kube/config"
Verify that the file exists:

bash
ls -l "$HOME/tfc-agent-kube/config"
Inspect the important parts:

bash
grep -E 'server:|certificate-authority:|client-certificate:|client-key:|certificate-authority-data:|client-certificate-data:|client-key-data:' \
  "$HOME/tfc-agent-kube/config"
Ideally, the flattened file contains:

text
certificate-authority-data: ...
client-certificate-data: ...
client-key-data: ...

# -----------------------------------------------------------------------------------------------------------------------------------------------
bash
chmod 644 "$HOME/tfc-agent-kube/config"
ls -l "$HOME/tfc-agent-kube/config"

bash 
docker rm -f hcp-agent-minikube 2>/dev/null || true
docker run --rm   --name hcp-agent-minikube   --network host   -e TFC_AGENT_TOKEN   -e TFC_AGENT_NAME=minikube-wsl-agent   -e KUBECONFIG=/home/tfc-agent/.kube/config   -v "$HOME/tfc-agent-kube:/home/tfc-agent/.kube:ro"   hashicorp/tfc-agent:1.30.1

# -----------------------------------------------------------------------------------------------------------------------------------------------


7. Suggested Make targets
You can automate this preparation:

text
.PHONY: tf-agent-refresh-kubeconfig
tf-agent-refresh-kubeconfig: ## Prepare a kubeconfig for containers attached to Minikube's Docker network.
	@set -eu; \
	if ! docker inspect minikube >/dev/null 2>&1; then \
		printf '%s\n' "Minikube Docker container is not running."; \
		exit 1; \
	fi; \
	mkdir -p "$$HOME/tfc-agent-kube"; \
	cp "$$HOME/.kube/config" "$$HOME/tfc-agent-kube/config"; \
	MINIKUBE_IP="$$(docker inspect minikube --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"; \
	sed -i -E "s#server: https://[^ ]+#server: https://$$MINIKUBE_IP:8443#" "$$HOME/tfc-agent-kube/config"; \
	printf '%s\n' "Agent kubeconfig prepared:"; \
	grep 'server:' "$$HOME/tfc-agent-kube/config"
text
.PHONY: tf-agent-test-minikube
tf-agent-test-minikube: ## Test kubectl access from the Minikube Docker network.
	docker run --rm \
		--network minikube \
		-v "$$HOME/tfc-agent-kube:/home/tfc-agent/.kube:ro" \
		-e KUBECONFIG=/home/tfc-agent/.kube/config \
		bitnami/kubectl:latest \
		get nodes
Run:

bash
make tf-agent-refresh-kubeconfig
make tf-agent-test-minikube
Recommended order
Run these commands in order:

bash
# 1. Confirm Minikube is running
minikube status

# 2. Prepare the container-specific kubeconfig
make tf-agent-refresh-kubeconfig

# 3. Test API connectivity directly
MINIKUBE_IP="$(
  docker inspect minikube \
    --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
)"

docker run --rm \
  --network minikube \
  curlimages/curl:latest \
  -k "https://${MINIKUBE_IP}:8443/version"

# 4. Test kubectl
make tf-agent-test-minikube

# 5. Stop and restart the agent on the Minikube network
# Use the docker run command with --network minikube

# 6. Trigger the HCP Terraform plan/apply
The root cause is therefore:

text
127.0.0.1:55320 = WSL host-published address
192.168.67.2:8443 = Minikube container’s internal Docker-network address
For your HCP agent, use the second address and attach the agent to the minikube Docker network.


