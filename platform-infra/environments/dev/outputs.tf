// -----------------------------------------------------------------------------
// outputs.tf (dev environment exported values)
// -----------------------------------------------------------------------------
// Purpose:
//   Define which values from the dev environment should be exposed after
//   "terraform apply", such as:
//   - IDs (vpc_id, subnet_ids)
//   - names (cluster_name)
//   - endpoints (ALB DNS, API URLs)
//
// Role in the plan:
//   - Outputs depend on resources/modules defined in main.tf.
//   - Terraform includes these dependencies in the graph, but outputs themselves
//     do not create infra; they just read attributes from objects Terraform manages.
//   - After "terraform apply", you can run "terraform output" to see these values
//     or use them in other tooling.
//
// Mental model:
// –   outputs.tf defines the "contract" of the dev environment: the key pieces of
//   information that other teams, scripts, or modules will rely on.
//
// Example shape (to be implemented):
// output "vpc_id" {
//   description = "ID of the dev VPC"
//   value       = module.network.vpc_id
// }
//
// output "cluster_name" {
//   description = "Name of the dev cluster"
//   value       = module.cluster.cluster_name
// }
#
# TODO: declare outputs that reflect what your dev platform exports.
output "vpc_id" {
  value       = module.network.vpc_id
  description = "Simulated VPC ID."
}

output "cluster_name" {
  value       = module.cluster.cluster_name
  description = "Simulated cluster name."
}