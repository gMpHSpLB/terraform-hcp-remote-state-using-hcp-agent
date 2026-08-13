// -----------------------------------------------------------------------------
// backend.tf (dev environment)
// -----------------------------------------------------------------------------
// Purpose:
//   Configure WHERE Terraform stores and reads state for the dev root module.
//   This tells "terraform init" which backend to use (local, S3, etc.).
//
// Role in the plan:
//   - On "terraform init", Terraform uses this block to connect to the state backend.
//   - On "terraform plan/apply", Terraform loads the current state from that backend
//     and compares it to the desired config in main.tf to compute the plan.
//
// Hard rule:
//   - ONLY root modules (environments/dev, staging, prod) define backends.
//   - Child modules under platform-infra/modules/* NEVER contain backend blocks.
//   - If you run "terraform apply" inside a module directory with its own state,
//     you create a second, conflicting source of truth for the same resources.
//
terraform {
  required_version = "1.15.8"

  cloud {
    organization = "hcrmapp-platform-lab"
    workspaces {
      name = "tf02-hcp-remote-state-dev-hcp-agent"
    }
  }
}