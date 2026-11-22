terraform {
  required_version = "~> 1.15"

  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    http = {
      source = "hashicorp/http"
    }
  }

  backend "s3" {
    # bucket is supplied at init time via -backend-config
    workspace_key_prefix = ""
    key                  = "terraform.tfstate"
    use_lockfile         = true
    region               = "us-east-1"

    # Only for non-AWS S3 compatible APIs
    skip_credentials_validation = true
    skip_requesting_account_id  = true
  }
}

provider "hcloud" {}
