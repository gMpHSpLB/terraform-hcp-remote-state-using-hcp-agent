# Repository root structure:

## Key ideas:
That layout directly supports your exercise:
    - modules/network and modules/cluster exist as child modules.
    - environments/dev is the root module that wires them together.
    - You run Terraform only from environments/<env>, never from inside modules/ (to avoid stray 
      state).

```console
terraform-platform-fundamentals/
├── Makefile                   # Terraform platform playbook: init/plan/apply/destroy per env
├── README.md                  # Repo-level description: what TF-01 covers, how to run labs
├── .terraform-version         # Optional: pin Terraform version for tfenv/asdf/etc.
└── platform-infra/
    ├── environments/
    │   ├── dev/
    │   │   ├── main.tf        # Root module: calls modules/network + modules/cluster
    │   │   ├── variables.tf   # Input variables for dev root
    │   │   ├── terraform.tfvars  # Dev-specific, non-secret values
    │   │   ├── backend.tf     # backend "s3" {} or local backend for now
    │   │   └── outputs.tf     # Root outputs (e.g., vpc_id, cluster_name)
    │   ├── staging/
    │   │   └── ...            # Same structure as dev (can stay stubbed)
    │   └── prod/
    │       └── ...            # Same structure as dev (can stay stubbed)
    ├── modules/
    │   ├── network/
    │   │   ├── main.tf        # “Fake” or real network module
    │   │   ├── variables.tf   # CIDRs, tags, etc.
    │   │   ├── outputs.tf     # vpc_id, private_subnet_ids, etc.
    │   │   └── README.md      # Explain intent & how to use
    │   ├── cluster/
    │   │   ├── main.tf        # Stub: random_pet + local_file pretending to be a cluster
    │   │   ├── variables.tf   # Accept vpc_id, private_subnet_ids (even if not used yet)
    │   │   ├── outputs.tf     # e.g., cluster_name, kubeconfig_path (fake for now)
    │   │   └── README.md
    │   ├── argocd-bootstrap/  # Placeholder for TF-03 (can be empty now)
    │   └── governance/        # Placeholder for TF-06 (can be empty now)
    └── docs/
        ├── layout.md          # Explain “directories per environment” vs workspaces
        └── tf01-notes.md      # Notes on HCL, providers, state and how they map here
```

# What each dev file is, what it contains, and how it contributes to a plan
Your current tree:

    platform-infra/environments/dev
    ├── backend.tf
    ├── main.tf
    ├── outputs.tf
    ├── terraform.tfvars
    └── variables.tf

Think of dev/ as a root module that owns:
    - How Terraform talks to state (backend.tf).
    - What infra shape is desired (main.tf).
    - Which inputs parameterize that shape (variables.tf + terraform.tfvars).
    - What outputs you care about (outputs.tf).

    Together, these files tell Terraform what to plan and apply.

## Component diagram (conceptual) for these files
    You can think of dev as this conceptual diagram:
      - backend.tf → “Where is my state?” (remote/local backend).
      - main.tf → “What infrastructure do I want?” (providers, modules, resources).
      - variables.tf + terraform.tfvars → “What parameters does this environment use?” (region, 
        CIDR, names).
      - outputs.tf → “What identifiers and endpoints should be exported?” (for humans/other 
        systems).

                   ┌─────────────────────────────┐
                   │  backend.tf                 │
                   │  (state backend config)     │
                   │  terraform { backend "..." }│
                   └──────────────┬──────────────┘
                                  │
                                  │  1. terraform init
                                  ▼
      ┌───────────────────────────────────────────────────────────┐
      │                   Terraform Core                         │
      │  - Reads config (main.tf, variables.tf, outputs.tf)      │
      │  - Reads values (terraform.tfvars)                       │
      │  - Reads state from backend (S3/local)                   │
      │  - Builds dependency graph & computes plan               │
      └───────────────┬──────────────────────────────────────────┘
                      │
                      │ uses
                      ▼
         ┌──────────────────────────────┐
         │  main.tf                     │
         │  root module entrypoint      │
         │  - providers                 │
         │  - resources                 │
         │  - module "network"/"cluster"│
         └──────────────┬───────────────┘
                        │ references
                        ▼
             ┌───────────────────────┐
             │  variables.tf         │
             │  input variable defs  │
             │  (types, descriptions)│
             └──────────┬────────────┘
                        │ values from
                        ▼
            ┌────────────────────────┐
            │  terraform.tfvars      │
            │  concrete values for   │
            │  dev (region, CIDRs...)│
            └────────────────────────┘

                      ▲
                      │ depends on resources/modules
                      │ (values computed after plan/apply)
                      │
         ┌──────────────────────────────┐
         │  outputs.tf                  │
         │  exported values for dev     │
         │  (vpc_id, cluster_name, etc.)│
         └──────────────────────────────┘