// -----------------------------------------------------------------------------
// modules/network/outputs.tf
// -----------------------------------------------------------------------------
// Purpose:
//   Export key attributes of the network created by this module, such as:
//   - vpc_id
//   - private_subnet_ids
//   - public_subnet_ids
//
// Role in the plan:
//   - Root modules can reference these outputs via:
//       module.network.vpc_id
//       module.network.private_subnet_ids
//   - Terraform includes these outputs in the overall dependency graph so that
//     other modules (e.g., modules/cluster) can depend on the network's results.
//
// Root vs child module:
//   - Outputs here DO NOT define a backend; they simply expose values from resources
//     managed by the root module that called this child module.
//
// Mental model:
//   modules/network/outputs.tf defines the "contract" of the network module: what
//   identifiers and lists downstream modules can rely on (e.g., cluster needs vpc_id
//   and private_subnet_ids).
//
// Example shape:
// output "vpc_id" {
//   description = "ID of the VPC created by this module"
//   value       = aws_vpc.main.id
// }
//
// output "private_subnet_ids" {
//   description = "IDs of private subnets created by this module"
//   value       = aws_subnet.private[*].id
// }
#
# TODO: declare outputs (even if the module uses random_pet/local_file at first).
output "vpc_id" {
  description = "Simulated VPC ID."
  value       = random_id.vpc_id.hex
}

output "vpc_name" {
  description = "Simulated VPC name."
  value       = random_pet.vpc_name.id
}

output "private_subnet_ids" {
  description = "Simulated subnet IDs for downstream modules."
  value = [
    "${random_id.vpc_id.hex}-subnet-a",
    "${random_id.vpc_id.hex}-subnet-b"
  ]
}