resource "local_file" "imported_file" {
  filename = "${path.root}/import-lab/existing.txt"

  content = <<-EOT
    This file was imported into Terraform state.
  EOT
}