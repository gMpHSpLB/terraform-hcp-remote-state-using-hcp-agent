// -----------------------------------------------------------------------------
// main.tf (dev environment root module)
// -----------------------------------------------------------------------------
// Purpose:
//   Entrypoint for the dev environment. This file defines WHAT infra we want:
//   - required Terraform & provider versions
//   - provider configurations (e.g., AWS region, kubeconfig)
//   - root-level resources, if any
//   - module calls (modules/network, modules/cluster, etc.)
//
// Role in the plan:
//   - Terraform parses main.tf to discover providers, resources, and modules.
//   - References inside main.tf (e.g., module.network.vpc_id) are used to build
//     the dependency graph (DAG) that decides execution order.
//   - Combined with variable values (from variables.tf + terraform.tfvars) and
//     state (from backend.tf), Terraform computes the diff for "terraform plan".
//
// Mental model:
//   Think of main.tf as the "platform wiring" layer: it stitches together
//   reusable modules under platform-infra/modules/* into a concrete dev stack.
//
# TODO: define terraform { required_providers ... }, provider "..." { ... },
#       and module "network"/"cluster" blocks that wire modules together.
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "/home/tfc-agent/.kube/config"
  config_context = "minikube"
}

module "network" {
  source   = "./modules/network"
  env_name = var.env_name
  vpc_cidr = var.vpc_cidr
}

module "cluster" {
  source             = "./modules/cluster"
  env_name           = var.env_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  node_count         = var.node_count
}

resource "kubernetes_namespace" "imported" {
  metadata {
    name = "import-lab"
  }
}