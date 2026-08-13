# Dev Root Module – Files and Their Role in Terraform Plans

## Current layout

```text
platform-infra/environments/dev
├── backend.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars
└── variables.tf
```

Think of `dev/` as a **root module** that owns:

- How Terraform talks to state (`backend.tf`).
- What infra shape is desired (`main.tf`).
- Which inputs parameterize that shape (`variables.tf` + `terraform.tfvars`).
- What outputs you care about (`outputs.tf`).

Together, these files tell Terraform what to **plan** and **apply**.

---

## `backend.tf`

### What it is

A special `terraform { backend "..." { ... } }` configuration that tells Terraform **where to store and read state** for this root module.[59][123]

### Typical contents

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

(or a simple `backend "local" {}` while you’re learning).

### Use case / when used

- Used by `terraform init` to configure **state storage** for this environment.[52][104][114]
- Once configured, all `plan` / `apply` / `destroy` calls for `dev` read/write state from that backend.

### How it helps create a plan

- When you run `make tf-plan TF_ENV=dev`, Terraform loads the **state** from the backend defined here.
- It then compares **desired resources** (from `main.tf`) against this state to compute the **plan diff**.[52][65]
- Without a backend block in the root, you risk Terraform silently using local state somewhere unexpected; that’s why **only root modules** should define backends, not child modules.[122][124]

---

## `main.tf`

### What it is

The **entrypoint** for your root module. It declares:

- Providers (`provider "aws" {}`, `provider "kubernetes" {}`, etc.).[72][80]
- Resources (`resource "..." "..." {}`) directly.[70]
- Module calls (`module "network" { source = "../../modules/network" ... }`).[67][11]

### Typical contents

```hcl
terraform {
  required_version = ">= 1.15.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source     = "../../modules/network"
  cidr_block = var.vpc_cidr
}

module "cluster" {
  source             = "../../modules/cluster"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
}
```

### Use case / when used

- Used on every `terraform plan` / `terraform apply` to know **what infra you want**.
- This is where you wire outputs from `modules/network` into inputs for `modules/cluster` – the **platform wiring**.

### How it helps create a plan

- `main.tf` defines the **nodes** of the dependency graph: modules, resources, data sources, providers.[68][79][121]
- Terraform uses references inside `main.tf` (e.g., `module.network.vpc_id`) to build **edges** and then compute the plan (create / change / destroy).[71][77]

---

## `variables.tf`

### What it is

Declarations of **input variables** that parameterize this root module: environment‑specific values like region, CIDR, names, toggles.[72][14]

### Typical contents

```hcl
variable "aws_region" {
  type        = string
  description = "AWS region for dev environment"
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the dev VPC"
}
```

### Use case / when used

- Terraform loads variable definitions from `variables.tf` and values from CLI, `-var-file`, or environment.[72][96]
- In this pattern, `terraform.tfvars` provides most values for the dev environment.

### How it helps create a plan

- When you run `terraform plan -var-file=terraform.tfvars`, Terraform evaluates expressions in `main.tf` using these variable values.[72][115]
- Correct variable typing ensures that the plan can be computed **without type errors**.[105][112][109]

---

## `terraform.tfvars`

### What it is

A file that **assigns concrete values** to the variables declared in `variables.tf` for this environment.[96][99]

### Typical contents

```hcl
aws_region = "ap-south-1"
vpc_cidr   = "10.0.0.0/16"
env_name   = "dev"
```

### Use case / when used

- Passed to Terraform via `-var-file=terraform.tfvars` (as in your `tf-plan`, `tf-apply`, `tf-destroy` targets).
- Often environment-specific and **non‑secret**. Secrets usually come from other mechanisms (env vars, Terraform Cloud, Vault, etc.).[96][102]

### How it helps create a plan

- Without values, `plan` would prompt or fail; with `terraform.tfvars`, plan can fully evaluate the configuration in a **reproducible** way.[115]
- Using a file instead of manual `-var` flags makes CI and human usage **consistent**.

---

## `outputs.tf`

### What it is

Declarations of **outputs** exported by this root module: IDs, names, endpoints that downstream tools or humans care about.[72][80][14]

### Typical contents

```hcl
output "vpc_id" {
  description = "ID of the dev VPC"
  value       = module.network.vpc_id
}

output "cluster_name" {
  description = "Name of the dev cluster"
  value       = module.cluster.cluster_name
}
```

### Use case / when used

- After `terraform apply`, you can run `terraform output` to see these values, or they can be consumed by other root modules, scripts, or CI steps.[67][96]
- They document the **“contract”** of your environment: what artifacts exist and how to reference them.

### How it helps create a plan

- Outputs don’t affect resource creation directly, but they are part of the **dependency graph** (they depend on resources/modules).[79][121]
- Terraform includes them in the plan and state so that downstream consumers can rely on them reliably.

---