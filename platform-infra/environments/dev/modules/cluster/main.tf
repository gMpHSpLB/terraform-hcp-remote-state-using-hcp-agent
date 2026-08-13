// -----------------------------------------------------------------------------
// modules/cluster/main.tf
// -----------------------------------------------------------------------------
// Purpose (child module):
//   Implement the "cluster" building block for the platform:
//   - While learning, this can be a stub using random_pet + local_file to avoid
//     cloud cost, but shaped like a real cluster module.
//   - Later, this could manage an actual managed Kubernetes cluster.
//
// Inputs (from variables.tf):
//   - vpc_id
//   - private_subnet_ids
//   (and possibly env_name, cluster_name, etc.)
//
// Root vs child module distinction:
//   - This is a CHILD module, called from environments/dev/main.tf (and others).
//   - It does NOT define a backend and must NOT be applied directly from its own
//     directory; state is owned by the calling root module.
//
// Role in the plan:
//   - When the root module calls:
//       module "cluster" { source = "../../modules/cluster" vpc_id = module.network.vpc_id ... }
//     Terraform evaluates resources in this file using the given inputs.
//   - The resulting resources (even if they're fake) are included in the global
//     dependency graph and stored in the root's backend.
//
// Mental model:
//   modules/cluster/main.tf is a "cluster component" that depends on network outputs.
//   It shows how module-chaining works (network -> cluster) without needing real AWS
//   or cloud credentials at TF-01 level.
//
# TODO: implement a stub cluster, e.g.:
# resource "random_pet" "cluster_name" { ... }
# resource "local_file" "cluster_manifest" {
#   content = "Cluster in VPC ${var.vpc_id} with subnets ${join(\",\", var.private_subnet_ids)}"
# }
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

resource "random_pet" "cluster_name" {
  prefix = "${var.env_name}-cluster"
  length = 2
}

resource "local_file" "cluster_manifest" {
  filename = "${path.module}/cluster-${var.env_name}.txt"
  content  = <<EOF
env_name         = ${var.env_name}
cluster_name     = ${random_pet.cluster_name.id}
vpc_id           = ${var.vpc_id}
private_subnet_ids = ${join(", ", var.private_subnet_ids)}
node_count         = ${var.node_count}
EOF
}