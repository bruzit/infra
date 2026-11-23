terraform {
  required_version = "~> 1.15"

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    github = {
      source = "integrations/github"
    }
  }

  backend "s3" {
    workspace_key_prefix = ""
    key                  = "terraform.tfstate"
    use_lockfile         = true
    region               = "us-east-1"

    skip_credentials_validation = true
    skip_requesting_account_id  = true
  }
}

provider "cloudflare" {}

provider "github" {
  owner = "bruzit"
  app_auth {}
}
