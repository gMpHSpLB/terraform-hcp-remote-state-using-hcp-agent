// -----------------------------------------------------------------------------
// modules/network/variables.tf
// -----------------------------------------------------------------------------
// Purpose:
//   Declare the inputs that the network module needs from callers (root modules),
//   such as:
//   - CIDR blocks
//   - environment name
//   - tags or labels
//
// Role in the plan:
//   - Root modules pass values into this module via "module \"network\" { ... }".
//   - Terraform uses these variable definitions to type-check and evaluate the
//     module's resources when building the dependency graph.
//
// Root vs child module:
//   - As a CHILD module, these variables define the module's "interface" but do
//     not themselves own any state or backend. State is associated with the root
//     module that calls this module.
//
// Mental model:
//   modules/network/variables.tf is the "API surface" for the network building block:
//   it specifies what inputs must be provided for the module to create a network.
//
// Example shape:
// variable "vpc_cidr" {
//   type        = string
//   description = "CIDR block for the VPC"
// }
//
// variable "env_name" {
//   type        = string
//   description = "Environment name (dev/staging/prod)"
// }
#
# TODO: declare the variables your network module needs.
variable "env_name" {
  type        = string
  description = "Environment name, such as dev, staging, or prod."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the simulated network."
}