// -----------------------------------------------------------------------------
// variables.tf (dev environment input definitions)
// -----------------------------------------------------------------------------
// Purpose:
//   Declare the input parameters that dev/main.tf expects:
//   - environment-specific values (region, CIDRs, names, flags, etc.)
//   - with types and descriptions for clarity and validation.
//
// Role in the plan:
//   - Terraform uses variable definitions to know what inputs exist and what
//     types/constraints they have.
//   - Actual values come from terraform.tfvars (or CLI/env), but the "shape"
//     of the inputs is defined here.
//   - During "terraform plan", expressions in main.tf are evaluated using these
//     variable values, so type correctness here is critical.
//
// Mental model:
//   variables.tf is the "interface" of the dev root module: it defines what
//   callers (humans, CI) must provide before main.tf can describe a concrete plan.
//
# TODO: declare variables, e.g.:
# variable "aws_region" { type = string, description = "AWS region for dev" }
# variable "vpc_cidr"   { type = string, description = "CIDR block for dev VPC" }
variable "env_name" {
  type        = string
  description = "Environment name."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the simulated dev network."
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 1
}