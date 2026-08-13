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

### Create an HCP agent pool
In HCP Terraform:
    1. Open your organization.
    2. Go to Settings.
    3. Open Agents.
    4. Create an agent pool:
        text
        Pool name: minikube-wsl-pool
    5. Create an agent token for that pool.
    6. Store the token securely.
        
### Check the agent in HCP Terraform:

text
Organization
└── Settings
    └── Agents
        └── Your agent pool
            └── agent: Online













