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

WSL Ubuntu
├── minikube
├── kubectl
├── ~/.kube/config
└── tfc-agent
