// -----------------------------------------------------------------------------
// modules/cluster/variables.tf
// -----------------------------------------------------------------------------
// Purpose:
//   Define the inputs required by the cluster module, especially those coming
//   from the network module, such as:
//   - vpc_id              (string)
//   - private_subnet_ids  (list(string))
//   - env_name            (optional: dev/staging/prod)
//
// Role in the plan:
//   - Root modules pass values to these variables via module "cluster" blocks.
//   - Terraform uses these definitions to understand the types and to ensure
//     that references like var.vpc_id are valid when building the graph.
//
// Root vs child module:
//   - As a CHILD module, these variables shape the module's dependency on network,
//     but state and backend are still controlled by the root module.
//
// Mental model:
//   modules/cluster/variables.tf defines the "inputs contract" for a cluster that
//   logically lives inside a VPC and subnets created elsewhere.
//
// Example shape:
// variable "vpc_id" {
//   type        = string
//   description = "ID of the VPC where the cluster will be placed"
// }
//
// variable "private_subnet_ids" {
//   type        = list(string)
//   description = "List of private subnet IDs for the cluster"
// }
#
# TODO: declare vpc_id, private_subnet_ids, and any other inputs your cluster needs.
variable "env_name" {
  type        = string
  description = "Environment name, such as dev, staging, or prod."
}

variable "vpc_id" {
  type        = string
  description = "Upstream VPC ID from the network module."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Upstream private subnet IDs from the network module."
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
}