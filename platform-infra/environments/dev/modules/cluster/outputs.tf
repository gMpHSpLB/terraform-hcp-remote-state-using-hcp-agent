// -----------------------------------------------------------------------------
// modules/cluster/outputs.tf
// -----------------------------------------------------------------------------
// Purpose:
//   Export key attributes of the cluster managed by this module, such as:
//   - cluster_name
//   - cluster_id or endpoint
//   - kubeconfig_path (real or fake)
//
// Role in the plan:
//   - Root modules can reference these outputs via:
//       module.cluster.cluster_name
//   - Outputs participate in the dependency graph as "readers" of resource
//     attributes; they don't create infra, but they depend on it.
//
// Root vs child module:
//   - These outputs are part of the child module's contract. The root module can
//     surface them again in its own outputs.tf or use them directly in other
//     root-level logic.
//
// Mental model:
//   modules/cluster/outputs.tf defines the "cluster contract": what identifiers
//   and endpoints other components can rely on (GitOps bootstrap, monitoring, etc.).
//
// Example shape (stub):
// output "cluster_name" {
//   description = "Logical name of the cluster"
//   value       = random_pet.cluster_name.id
// }
//
// output "cluster_manifest_path" {
//   description = "Path to the local file describing the cluster"
//   value       = local_file.cluster_manifest.filename
// }
#
# TODO: declare outputs that your platform will care about for clusters.
output "cluster_name" {
  description = "Simulated cluster name."
  value       = random_pet.cluster_name.id
}

output "cluster_manifest_path" {
  description = "Path to the generated cluster manifest file."
  value       = local_file.cluster_manifest.filename
}