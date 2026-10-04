locals {
  project_name = "ecsp"
  environment  = "dev"

  common_tags = {
    project     = "enterprise-cloud-security-platform"
    environment = local.environment
    managed_by  = "terraform"
  }
}