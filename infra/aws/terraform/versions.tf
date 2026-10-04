terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend parcial: bucket, key e region são informados no init com
  # -backend-config. Para validar sem backend: terraform init -backend=false
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
