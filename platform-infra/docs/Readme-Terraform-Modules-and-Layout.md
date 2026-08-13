# Terraform Modules & Layout

This is a practical, Kubernetes/GitOps‑friendly way to understand modules and repo layout, plus Make targets you can reuse across all tutorials.

---

## 1. Basic Module Anatomy

A **module** is just a directory of `.tf` files.  
Terraform reads *all* `.tf` files in that directory and treats them as one module; filenames are **conventions**, not syntax, but the convention is strong enough that deviating from it will confuse other engineers.

Typical layout:

```text
modules/network/
├── main.tf        # implementation: resource blocks — the actual infrastructure
├── variables.tf   # input contract — what this module needs from its caller
├── outputs.tf     # output contract — what this module returns to its caller
├── versions.tf    # required_providers / required_version (optional)
└── README.md      # human-readable contract: purpose, inputs, outputs, examples
```

### Why split `main.tf`, `variables.tf`, `outputs.tf`?

1. **Interface vs implementation**  
   - `variables.tf` + `outputs.tf` = the module’s **public API**.  
   - A consumer should understand how to use the module by reading those two files without opening `main.tf`.  
   - Mixing everything into one file forces every user to dig through implementation to find the contract.

2. **Diff hygiene in reviews**  
   - If a PR only changes outputs, the diff is cleanly visible in `outputs.tf`.  
   - Reviewers can skim filenames (`variables.tf`, `main.tf`, `outputs.tf`) before content to understand what changed.

---

## 2. Example: `modules/network/variables.tf`

```hcl
variable "environment" {
  type        = string
  description = "Environment name used for naming/tagging (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "az_count" {
  type        = number
  description = "Number of AZs to spread subnets across"
  default     = 3
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to every resource this module creates"
  default     = {}
}
```

Key point: **`validation` blocks** let the module reject bad input at plan time, with a clear error message, before any API call happens.  
This is like validating Helm values early instead of discovering misconfigurations deep inside AWS/K8s errors.

---

## 3. Example: `modules/network/main.tf`

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = merge(var.tags, {
    Name = "${var.environment}-vpc"
  })
}

resource "aws_subnet" "private" {
  count               = var.az_count
  vpc_id              = aws_vpc.this.id
  cidr_block          = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone   = data.aws_availability_zones.available.names[count.index]
  tags = merge(var.tags, {
    Name = "${var.environment}-private-${count.index}"
  })
}
```

This file is pure implementation.  
Callers should only care that:

- If they pass `environment`, `vpc_cidr`, `az_count`, `tags`,  
- They get well‑tagged VPC + subnets back via outputs.

---

## 4. Example: `modules/network/outputs.tf`

```hcl
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "IDs of all private subnets, for consumption by the cluster module"
  value       = aws_subnet.private[*].id
}
```

Rule to internalize:

- **Only output what consumers actually need**, not every attribute.  
- Avoid exposing the whole `aws_vpc.this` object; it couples consumers to the full provider schema.  
- Prefer simple, stable attributes (`vpc_id`, `private_subnet_ids`) as your module’s “return values.”

This is the same interface discipline as function return values in programming languages.

---

## 5. Root vs Child Modules

Definitions:

- **Root module**: the directory where you run `terraform init/plan/apply`.  
  - “Root” is a *role*, not a special syntax.  
  - Any directory of `.tf` files becomes the root module when you `cd` into it and run Terraform there.

- **Child module**: any module invoked via a `module` block from somewhere else.  
  - It is *not* meant to be applied directly with `terraform apply` inside `modules/network/`.  
  - It relies on callers (root modules) for backend configuration, state isolation, environment‑specific inputs.

Example root module for **dev**:

```hcl
# environments/dev/main.tf  ← root module for dev

module "network" {
  source = "../../modules/network"

  environment = "dev"
  vpc_cidr    = "10.20.0.0/16"
  az_count    = 2
  tags        = local.common_tags
}

module "cluster" {
  source = "../../modules/cluster"

  environment         = "dev"
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  node_instance_type  = "t3.medium"  # small/cheap for dev
  min_nodes           = 1
  max_nodes           = 3
  tags                = local.common_tags
}
```

Example root module for **prod** (same child modules, different inputs):

```hcl
# environments/prod/main.tf  ← root module for prod

module "network" {
  source = "../../modules/network"

  environment = "prod"
  vpc_cidr    = "10.30.0.0/16"
  az_count    = 3            # more AZs for prod
  tags        = local.common_tags
}

module "cluster" {
  source = "../../modules/cluster"

  environment         = "prod"
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  node_instance_type  = "m6i.xlarge"  # real capacity for prod
  min_nodes           = 3
  max_nodes           = 20
  tags                = local.common_tags
}
```

Key idea:

- `module.network.vpc_id` is how child modules chain together.  
- Terraform’s DAG ensures **network** applies before **cluster** uses its outputs.  
- You never hardcode VPC IDs between modules; module outputs define the boundary.

---

## 6. Recommended Platform Folder Layout

```text
platform-infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf          # root module: calls modules/network + modules/cluster
│   │   ├── variables.tf
│   │   ├── terraform.tfvars # dev-specific values (non-secret)
│   │   ├── backend.tf       # backend "s3" { key = "dev/terraform.tfstate" ... }
│   │   └── outputs.tf
│   ├── staging/
│   │   └── ... (same structure)
│   └── prod/
│       └── ... (same structure)
│
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── cluster/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── argocd-bootstrap/    # for TF-03
│   └── governance/          # for TF-06
│
├── .terraform-version       # tfenv or version pin (optional)
└── README.md                # repo-level description
```

### Directories vs Workspaces (Short Version)

- **Directories per environment** (dev/staging/prod):
  - Each env has its own backend/state file.
  - Config can differ per environment (e.g., prod has WAF, dev doesn’t).
  - Easier to scope CI/CD and permissions by path.

- **Terraform workspaces**:
  - Same `.tf` for all workspaces; only variables differ.
  - Harder to have environments with different shape.
  - Harder to enforce environment-specific CI/RBAC boundaries.

For a platform curriculum and real‑world clusters, **directories per environment** are the default choice.

---

## 7. Make Targets: Base Commands for All Tutorials

Assume you have this structure:

```text
platform-infra/
  Makefile
  environments/dev/...
  environments/staging/...
  environments/prod/...
```

### Make target: Initialize an environment

```make
TF_ENV ?= dev
TF_DIR := environments/$(TF_ENV)

.PHONY: tf-init
tf-init:
	cd $(TF_DIR) && terraform init
```

Usage:

```bash
make tf-init TF_ENV=dev
make tf-init TF_ENV=prod
```

### Make target: Validate and plan

```make
.PHONY: tf-plan
tf-plan:
	cd $(TF_DIR) && terraform fmt -recursive
	cd $(TF_DIR) && terraform validate
	cd $(TF_DIR) && terraform plan -var-file=terraform.tfvars
```

Usage:

```bash
make tf-plan TF_ENV=dev
make tf-plan TF_ENV=prod
```

### Make target: Apply

```make
.PHONY: tf-apply
tf-apply:
	cd $(TF_DIR) && terraform apply -var-file=terraform.tfvars
```

Usage:

```bash
make tf-apply TF_ENV=dev
make tf-apply TF_ENV=prod
```

### Make target: Destroy

```make
.PHONY: tf-destroy
tf-destroy:
	cd $(TF_DIR) && terraform destroy -var-file=terraform.tfvars
```

Usage:

```bash
make tf-destroy TF_ENV=dev
make tf-destroy TF_ENV=prod
```

These four targets (`tf-init`, `tf-plan`, `tf-apply`, `tf-destroy`) give you a consistent, environment‑scoped CLI interface that you can reuse and extend in TF‑02 onward (e.g., adding `ARGOC_DB_BOOTSTRAP`, policy checks, etc.).

---

## 8. How This Becomes Your Base

- Every tutorial can say:  
  - “Add this to `modules/...`”  
  - “Wire it from `environments/dev/main.tf`”  
  - “Run `make tf-plan TF_ENV=dev` and `make tf-apply TF_ENV=dev`.”

- You keep one **canonical layout** and **canonical Make interface**,  
  and all new topics (managed Kubernetes, ArgoCD bootstrap, quotas/autoscaling, governance) just add modules + env wiring.

---