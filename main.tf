provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= v1.0.5"

  required_providers {
    archive = "~> 2.2.0"
    aws     = "~> 3.56.0"
    null    = "~> 3.1.0"
    random  = "~> 3.1.0"
  }

  backend "remote" {
    organization = "romainrbr"

    workspaces {
      name = "romainrbr"
    }
  }
}

