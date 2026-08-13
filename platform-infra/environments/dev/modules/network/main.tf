// -----------------------------------------------------------------------------
// modules/network/main.tf
// -----------------------------------------------------------------------------
// Purpose (child module):
//   Implement the "network" building block for the platform:
//   - VPC / main network object (real or fake while learning)
//   - subnets, route tables, tags, etc.
//   This module is REUSABLE across environments (dev, staging, prod).
//
// Root vs child module distinction:
//   - This is a CHILD module: it is NEVER run directly with "terraform plan/apply"
//     from inside modules/network/, and it NEVER defines a backend.
//   - Instead, root modules (environments/dev, staging, prod) CALL this module via:
//       module "network" { source = "../../modules/network" ... }
//
// Role in the plan:
//   - When a root module calls module "network", Terraform instantiates this module
//     with specific input values (from the root's variables/tfvars).
//   - resources + data sources declared in this file become nodes in the global
//     dependency graph; their lifecycle is driven by the root module's plan/apply.
//   - State for these resources is stored in the ROOT backend (e.g., dev/backend.tf),
//     not inside modules/network/.
//
// Mental model:
//   modules/network/main.tf is a self-contained "network component" that can be
//   plugged into any environment. It owns resource definitions, but not backends
//   or environment-specific configuration.
//
# TODO: define resources for the network module (fake or real), e.g.:
# resource "random_pet" "vpc_name" { ... }
# resource "local_file" "vpc_manifest" { ... }
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "random_pet" "vpc_name" {
  prefix = "${var.env_name}-vpc"
  length = 2
}

resource "random_id" "vpc_id" {
  byte_length = 4
}

resource "local_file" "network_manifest" {
  filename = "${path.module}/network-${var.env_name}.txt"
  content  = <<EOF
env_name   = ${var.env_name}
vpc_name   = ${random_pet.vpc_name.id}
vpc_id     = ${random_id.vpc_id.hex}
vpc_cidr   = ${var.vpc_cidr}
EOF
}