# -----------------------------------------------------------------------------
# terraform.tfvars (dev environment variable values)
# -----------------------------------------------------------------------------
# Purpose:
#   Provide concrete values for variables declared in variables.tf for the dev
#   environment (e.g., region, CIDRs, names).
#
# Role in the plan:
#   - When you run:
#       terraform plan   -var-file=terraform.tfvars
#       terraform apply  -var-file=terraform.tfvars
#     Terraform loads these values and uses them to evaluate expressions in main.tf.
#   - This makes plans reproducible: dev always uses the same set of inputs unless
#     you change this file.
#
# Mental model:
#   terraform.tfvars turns the dev root module from an abstract "shape" into a
#   concrete environment instance. Different environments (dev/staging/prod) have
#   their own tfvars to reflect different sizes, regions, or features.
//
# TODO: assign values, e.g.:
# aws_region = "ap-south-1"
# vpc_cidr   = "10.0.0.0/16"
# env_name   = "dev"
env_name   = "dev"
vpc_cidr   = "10.0.0.0/15"
node_count = 4