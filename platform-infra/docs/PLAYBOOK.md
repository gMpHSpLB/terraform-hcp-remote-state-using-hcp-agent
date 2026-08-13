# Terraform Fundamentals Playbook

This playbook is designed for newcomers. Follow the sections in order and run each command from the repository root.

---

## 1. Understand the mental model

Terraform manages the relationship between three things:

```text
Configuration
    ↓
State
    ↓
Real infrastructure
```

### Configuration

Terraform configuration is written in `.tf` files.

Examples:

```text
platform-infra/environments/dev/main.tf
platform-infra/modules/network/main.tf
platform-infra/modules/cluster/main.tf
```

Configuration describes the desired result.

### State

Terraform state is stored locally for this lab:

```text
platform-infra/environments/dev/terraform.tfstate
```

State records resource addresses, IDs, and provider attributes.

### Real infrastructure

In this project, real infrastructure includes:

- Generated local files.
- Random provider resources.
- A Kubernetes namespace.

---

## 2. Confirm the environment

From the repository root:

```bash
pwd
```

Expected directory:

```text
terraform-platform-fundamentals
```

Check the Terraform environment:

```bash
ls platform-infra/environments/dev
```

Expected files include:

```text
main.tf
variables.tf
terraform.tfvars
```

Check the Makefile:

```bash
make -f Makefile_TR_Workflow help
```

---

## 3. Initialize Terraform

Run:

```bash
make -f Makefile_TR_Workflow tf-init TF_ENV=dev
```

Initialization performs tasks such as:

- Loading the backend.
- Loading child modules.
- Installing providers.
- Reading the provider lock file.

If initialization succeeds, you can continue with validation.

---

## 4. Format and validate

Format all Terraform files:

```bash
make -f Makefile_TR_Workflow tf-fmt
```

Validate the selected environment:

```bash
make -f Makefile_TR_Workflow tf-validate TF_ENV=dev
```

Expected result:

```text
Success! The configuration is valid.
```

Formatting and validation are safe operations. They do not create, update, or destroy infrastructure.

---

## 5. Create the baseline

Run:

```bash
make -f Makefile_TR_Workflow tf-plan TF_ENV=dev
```

Review the proposed changes.

Apply the configuration:

```bash
make -f Makefile_TR_Workflow tf-apply TF_ENV=dev
```

The first apply may create resources such as:

```text
module.network.random_pet.vpc_name
module.network.random_id.vpc_id
module.network.local_file.network_manifest
module.cluster.random_pet.cluster_name
module.cluster.local_file.cluster_manifest
```

Verify the result:

```bash
make -f Makefile_TR_Workflow tf-verify-post-apply TF_ENV=dev
```

---

## 6. Inspect outputs

Show the root outputs:

```bash
make -f Makefile_TR_Workflow tf-output TF_ENV=dev
```

Expected outputs include:

```text
cluster_name
vpc_id
```

Root outputs are values intentionally exposed by the root module.

Terraform does not display every resource attribute through `terraform output`.

---

## 7. Inspect state

List state resources:

```bash
make -f Makefile_TR_Workflow tf-state-list TF_ENV=dev
```

Example addresses:

```text
module.network.random_pet.vpc_name
module.network.random_id.vpc_id
module.network.local_file.network_manifest
module.cluster.random_pet.cluster_name
module.cluster.local_file.cluster_manifest
```

Inspect one resource:

```bash
make -f Makefile_TR_Workflow tf-state-show \
  TF_ENV=dev \
  STATE_ADDRESS=module.cluster.local_file.cluster_manifest
```

Inspect the complete state:

```bash
make -f Makefile_TR_Workflow tf-show TF_ENV=dev
```

The state address is important. Terraform commands operate on resource addresses, not only on filenames.

---

## 8. Update a variable

Open:

```text
platform-infra/environments/dev/terraform.tfvars
```

Change:

```hcl
node_count = 3
```

to:

```hcl
node_count = 4
```

Run:

```bash
make -f Makefile_TR_Workflow tf-plan TF_ENV=dev
```

Terraform should show a change in:

```text
module.cluster.local_file.cluster_manifest
```

The generated file is:

```text
platform-infra/modules/cluster/cluster-dev.txt
```

Apply the update:

```bash
make -f Makefile_TR_Workflow tf-apply TF_ENV=dev
```

Verify:

```bash
cat platform-infra/modules/cluster/cluster-dev.txt
```

The file should contain:

```text
node_count         = 4
```

Run another plan:

```bash
make -f Makefile_TR_Workflow tf-plan TF_ENV=dev
```

Expected result:

```text
No changes. Your infrastructure matches the configuration.
```

---

## 9. Simulate drift

Drift means that the real object changes outside Terraform.

Apply the current configuration:

```bash
make -f Makefile_TR_Workflow tf-apply TF_ENV=dev
```

Edit this generated file:

```text
platform-infra/modules/cluster/cluster-dev.txt
```

Add or modify a value:

```text
node_count         = 999
```

Now run:

```bash
make -f Makefile_TR_Workflow tf-plan TF_ENV=dev
```

Terraform should report that the managed file changed outside Terraform.

The `local_file` provider may report the file as deleted and propose recreation rather than showing a traditional in-place content update. This behavior is specific to the provider and is useful for understanding drift handling.

Run a refresh-only plan:

```bash
make -f Makefile_TR_Workflow tf-plan-refresh-only TF_ENV=dev
```

A normal plan asks:

```text
What must change to make reality match configuration?
```

A refresh-only plan asks:

```text
What must change in state to reflect reality?
```

Restore the desired configuration:

```bash
make -f Makefile_TR_Workflow tf-apply TF_ENV=dev
```

Verify the generated file again:

```bash
cat platform-infra/modules/cluster/cluster-dev.txt
```

---

## 10. Use a saved plan

Create a saved plan:

```bash
make -f Makefile_TR_Workflow tf-plan-saved TF_ENV=dev
```

Review the plan.

Apply exactly that saved plan:

```bash
make -f Makefile_TR_Workflow tf-apply-saved TF_ENV=dev
```

This workflow is stronger than running separate plan and apply commands because the exact reviewed plan is applied.

Never commit saved plan files.

---

## 11. Demonstrate unsupported import

Create a local file:

```bash
mkdir -p platform-infra/environments/dev/import-lab

printf '%s\n' \
  'This file existed before Terraform state management.' \
  > platform-infra/environments/dev/import-lab/existing.txt
```

Attempt to import it:

```bash
make -f Makefile_TR_Workflow tf-import \
  TF_ENV=dev \
  IMPORT_ADDRESS=local_file.imported_file \
  IMPORT_ID=import-lab/existing.txt
```

Expected result:

```text
Error: Resource Import Not Implemented
```

This is expected. The `local_file` resource does not support Terraform import.

Do not interpret the file's existence as successful Terraform management. A local file can exist on disk without being associated with a Terraform state address.

---

## 12. Import a Kubernetes namespace

Start Minikube if necessary:

```bash
minikube start
kubectl config use-context minikube
```

Verify Kubernetes:

```bash
kubectl get nodes
```

Create a namespace outside Terraform:

```bash
kubectl create namespace import-lab
```

If it already exists:

```bash
kubectl get namespace import-lab
```

Confirm that the Terraform configuration contains:

```hcl
resource "kubernetes_namespace" "imported" {
  metadata {
    name = "import-lab"
  }
}
```

Import the existing namespace:

```bash
make -f Makefile_TR_Workflow tf-import \
  TF_ENV=dev \
  IMPORT_ADDRESS=kubernetes_namespace.imported \
  IMPORT_ID=import-lab
```

Inspect the imported resource:

```bash
make -f Makefile_TR_Workflow tf-state-show \
  TF_ENV=dev \
  STATE_ADDRESS=kubernetes_namespace.imported
```

Verify its presence in state:

```bash
make -f Makefile_TR_Workflow tf-state-list TF_ENV=dev
```

Run a plan:

```bash
make -f Makefile_TR_Workflow tf-plan TF_ENV=dev
```

The namespace should be managed without Terraform recreating it.

---

## 13. Run the automated workflow

Run:

```bash
make -f Makefile_TR_Workflow \
  tf-automated-stateinspection-update-drift-import \
  TF_ENV=dev
```

The script performs the following phases:

```text
Phase 2.1  Terraform baseline
Phase 2.2  State and output inspection
Phase 2.3  node_count update
Phase 2.4  Generated manifest drift
Phase 2.5  Drift reconciliation
Phase 2.6  Unsupported local_file import demonstration
Phase 2.7  Kubernetes namespace import
Phase 2.8  State verification
Phase 2.9  Final verification
```

Artifacts are written to:

```text
platform-infra/.artifacts/dev/
```

Review the artifacts:

```bash
find platform-infra/.artifacts/dev -type f -maxdepth 1 -print
```

Useful files include:

```text
plan-node-count-update.txt
plan-drift-detected.txt
plan-after-drift-reconciliation.txt
local-file-import-output.txt
kubernetes-import-output.txt
state-final.txt
outputs-final.txt
```

---

## 14. Troubleshooting

### Terraform says no configuration files exist

Run Terraform from the environment directory:

```bash
cd platform-infra/environments/dev
terraform plan
```

Or use:

```bash
terraform -chdir=platform-infra/environments/dev plan
```

### Provider is missing

Run:

```bash
make -f Makefile_TR_Workflow tf-init TF_ENV=dev
```

### Variable is undeclared

If `terraform.tfvars` contains:

```hcl
node_count = 4
```

the root module must declare:

```hcl
variable "node_count" {
  type = number
}
```

If a child module uses the variable, it must also declare the variable and receive it through the module block.

### Resource already managed by Terraform

Example:

```text
Error: Resource already managed by Terraform
```

Check state:

```bash
make -f Makefile_TR_Workflow tf-state-list TF_ENV=dev
```

If the resource is already listed, do not import it again.

To remove only the state binding:

```bash
cd platform-infra/environments/dev
terraform state rm kubernetes_namespace.imported
```

This does not delete the Kubernetes namespace.

### Generated manifest path cannot be found

The state may show a relative path such as:

```text
../../modules/cluster/cluster-dev.txt
```

That path is relative to:

```text
platform-infra/environments/dev
```

The actual repository path is:

```text
platform-infra/modules/cluster/cluster-dev.txt
```

### Terraform plans to recreate a local file

This can happen after manually modifying or deleting a Terraform-managed `local_file`.

Run:

```bash
make -f Makefile_TR_Workflow tf-plan TF_ENV=dev
```

Then apply if you want Terraform to restore the declared content:

```bash
make -f Makefile_TR_Workflow tf-apply TF_ENV=dev
```

---

## 15. Safe cleanup

Remove only the Terraform cache while preserving state:

```bash
make -f Makefile_TR_Workflow tf-clean-working-dir TF_ENV=dev
```

Then initialize again:

```bash
make -f Makefile_TR_Workflow tf-init TF_ENV=dev
```

Use destructive cleanup only for this disposable lab:

```bash
make -f Makefile_TR_Workflow tf-clean TF_ENV=dev
```

Never casually delete state for shared or production infrastructure.

---

## 16. Final verification checklist

Before considering the lab complete:

```bash
make -f Makefile_TR_Workflow tf-fmt
make -f Makefile_TR_Workflow tf-init TF_ENV=dev
make -f Makefile_TR_Workflow tf-validate TF_ENV=dev
make -f Makefile_TR_Workflow tf-plan TF_ENV=dev
make -f Makefile_TR_Workflow tf-verify-post-apply TF_ENV=dev
```

Confirm:

- Terraform initializes successfully.
- Terraform validation passes.
- No unexpected plan changes remain.
- Expected outputs exist.
- Expected state resources exist.
- Kubernetes namespace import is present.
- Generated artifacts are ignored by Git.
- `.terraform.lock.hcl` is available for commit.
- No secrets or state files are staged.