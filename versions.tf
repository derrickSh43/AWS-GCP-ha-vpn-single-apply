terraform {
  required_version = ">= 1.11, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.28.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13.0"
    }
  }
}
provider "aws" {
  region = var.aws_region
}
provider "google" {
  project                     = var.project_id
  region                      = var.region
  zone                        = var.zone
  impersonate_service_account = var.gcp_deployment_service_account
}
provider "vault" {
  skip_child_token = true
}
