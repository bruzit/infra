variables {
  account_id = "acct"
}

mock_provider "cloudflare" {
  mock_resource "cloudflare_account_token" {
    defaults = {
      id    = "token-id"
      value = "token-value"
    }
  }
}

mock_provider "github" {}

override_module {
  target = module.permission_groups
  outputs = {
    ids = {
      "Workers R2 Storage Bucket Item Read"  = ["r2-item-read"]
      "Workers R2 Storage Bucket Item Write" = ["r2-item-write"]
      "Workers R2 Storage Read"              = ["r2-read"]
      "Workers R2 Storage Write"             = ["r2-write"]
      "Pages Read"                           = ["pages-read"]
      "Pages Write"                          = ["pages-write"]
      "Account API Tokens Read"              = ["tokens-read"]
      "Account API Tokens Write"             = ["tokens-write"]
      "Account Settings Read"                = ["settings-read"]
    }
  }
}

run "buckets" {
  command = plan

  assert {
    condition     = toset([for b in cloudflare_r2_bucket.state : b.name]) == toset(["bruzit-terraform-github-prod", "bruzit-terraform-github-test", "bruzit-terraform-hetzner-test", "bruzit-terraform-hetzner-prod", "bruzit-terraform-cloudflare-prod"])
    error_message = "One state bucket per technology and tier."
  }

  assert {
    condition     = alltrue([for b in cloudflare_r2_bucket.state : b.jurisdiction == "eu"])
    error_message = "Every state bucket must be in the eu jurisdiction."
  }
}

run "r2_tokens" {
  command = plan

  assert {
    condition     = cloudflare_account_token.r2["Hetzner Test R"].policies[0].resources == jsonencode({ "com.cloudflare.edge.r2.bucket.acct_eu_bruzit-terraform-hetzner-test" = "*" })
    error_message = "R2 tokens must be scoped to their own eu bucket."
  }

  assert {
    condition     = cloudflare_account_token.r2["Hetzner Prod R"].policies[0].permission_groups[0].id == "r2-item-read" && cloudflare_account_token.r2["Hetzner Prod RW"].policies[0].permission_groups[0].id == "r2-item-write"
    error_message = "R tokens read objects, RW tokens write them."
  }
}

run "secrets" {
  assert {
    condition     = length(github_actions_environment_secret.r2_access_key_id) == 10 && length(github_actions_environment_secret.r2_secret_access_key) == 10
    error_message = "Every GitHub environment gets its R2 credentials, the Cloudflare root's own included."
  }

  assert {
    condition     = github_actions_environment_secret.r2_secret_access_key["GitHub Prod RW"].value == sha256("token-value") && github_actions_environment_secret.r2_access_key_id["GitHub Prod RW"].value == "token-id"
    error_message = "R2 S3 credentials are the token ID and the SHA-256 of the token value."
  }

  assert {
    condition     = toset([for s in github_actions_environment_secret.cloudflare_api_token : "${s.repository}/${s.environment}"]) == toset(["infra/cloudflare-prod-plan", "martin.bruzina.cz/prod", "martin.bruzina.cz/test"])
    error_message = "The Pages deploy tokens and the Cloudflare root's read token go to GitHub."
  }
}

run "pages" {
  command = plan

  assert {
    condition     = cloudflare_pages_project.martin_bruzina_cz.name == "martin-bruzina-cz" && cloudflare_pages_project.martin_bruzina_cz.production_branch == "main" && cloudflare_pages_project.martin_bruzina_cz.source == null
    error_message = "Pages project martin-bruzina-cz deploys main by direct upload."
  }

  assert {
    condition     = cloudflare_pages_domain.martin_bruzina_cz.name == "martin.bruzina.cz" && cloudflare_pages_domain.martin_bruzina_cz.project_name == "martin-bruzina-cz"
    error_message = "martin.bruzina.cz is the custom domain of martin-bruzina-cz."
  }
}

run "missing_permission_group" {
  command = plan

  override_module {
    target = module.permission_groups
    outputs = {
      ids = { "Workers R2 Storage Bucket Item Read" = ["r2-item-read"] }
    }
  }

  expect_failures = [cloudflare_account_token.r2, cloudflare_account_token.api]
}
