locals {
  buckets = toset(["github-prod", "github-test", "hetzner-test", "hetzner-prod", "cloudflare-prod"])

  r2_tokens = {
    "GitHub Prod R"      = { bucket = "github-prod", write = false, repository = ".github", environment = "plan" }
    "GitHub Prod RW"     = { bucket = "github-prod", write = true, repository = ".github", environment = "production" }
    "GitHub Test R"      = { bucket = "github-test", write = false, repository = "github-organization-as-code", environment = "plan" }
    "GitHub Test RW"     = { bucket = "github-test", write = true, repository = "github-organization-as-code", environment = "test" }
    "Hetzner Test R"     = { bucket = "hetzner-test", write = false, repository = "infra", environment = "test-plan" }
    "Hetzner Test RW"    = { bucket = "hetzner-test", write = true, repository = "infra", environment = "test" }
    "Hetzner Prod R"     = { bucket = "hetzner-prod", write = false, repository = "infra", environment = "prod-plan" }
    "Hetzner Prod RW"    = { bucket = "hetzner-prod", write = true, repository = "infra", environment = "prod" }
    "Cloudflare Prod R"  = { bucket = "cloudflare-prod", write = false, repository = null, environment = null }
    "Cloudflare Prod RW" = { bucket = "cloudflare-prod", write = true, repository = null, environment = null }
  }

  api_tokens = {
    "Cloudflare API Prod R"  = { permissions = ["Workers R2 Storage Read", "Pages Read", "Account API Tokens Read", "Account Settings Read"], repository = null, environment = null }
    "Cloudflare API Prod RW" = { permissions = ["Workers R2 Storage Write", "Pages Write", "Account API Tokens Write", "Account Settings Read"], repository = null, environment = null }
    "Pages Deploy Prod"      = { permissions = ["Pages Write"], repository = "martin.bruzina.cz", environment = "prod" }
    "Pages Deploy Test"      = { permissions = ["Pages Write"], repository = "martin.bruzina.cz", environment = "test" }
  }

  r2_permission = { false = "Workers R2 Storage Bucket Item Read", true = "Workers R2 Storage Bucket Item Write" }

  permission_ids = module.permission_groups.ids
}

module "permission_groups" {
  source = "./modules/permission_groups"

  account_id = var.account_id
}

resource "cloudflare_r2_bucket" "state" {
  for_each = local.buckets

  account_id   = var.account_id
  name         = "bruzit-terraform-${each.key}"
  jurisdiction = "eu"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_account_token" "r2" {
  for_each = local.r2_tokens

  account_id = var.account_id
  name       = "BruzIT Terraform ${each.key}"
  policies = [{
    effect            = "allow"
    permission_groups = [{ id = try(local.permission_ids[local.r2_permission[each.value.write]][0], "") }]
    resources         = jsonencode({ "com.cloudflare.edge.r2.bucket.${var.account_id}_eu_${cloudflare_r2_bucket.state[each.value.bucket].name}" = "*" })
  }]

  lifecycle {
    precondition {
      condition     = contains(keys(local.permission_ids), local.r2_permission[each.value.write])
      error_message = "R2 bucket item permission group not found; check the names the permission_groups module lists."
    }
  }
}

resource "cloudflare_account_token" "api" {
  for_each = local.api_tokens

  account_id = var.account_id
  name       = "BruzIT ${each.key}"
  policies = [{
    effect            = "allow"
    permission_groups = [for p in each.value.permissions : { id = try(local.permission_ids[p][0], "") }]
    resources         = jsonencode({ "com.cloudflare.api.account.${var.account_id}" = "*" })
  }]

  lifecycle {
    precondition {
      condition     = length(setsubtract(each.value.permissions, keys(local.permission_ids))) == 0
      error_message = "Permission groups not found: ${join(", ", setsubtract(each.value.permissions, keys(local.permission_ids)))}."
    }
  }
}

resource "github_actions_environment_secret" "r2_access_key_id" {
  for_each = { for k, v in local.r2_tokens : k => v if v.repository != null }

  repository  = each.value.repository
  environment = each.value.environment
  secret_name = "AWS_ACCESS_KEY_ID"
  value       = cloudflare_account_token.r2[each.key].id
}

resource "github_actions_environment_secret" "r2_secret_access_key" {
  for_each = { for k, v in local.r2_tokens : k => v if v.repository != null }

  repository  = each.value.repository
  environment = each.value.environment
  secret_name = "AWS_SECRET_ACCESS_KEY"
  value       = sha256(cloudflare_account_token.r2[each.key].value)
}

resource "github_actions_environment_secret" "cloudflare_api_token" {
  for_each = { for k, v in local.api_tokens : k => v if v.repository != null }

  repository  = each.value.repository
  environment = each.value.environment
  secret_name = "CLOUDFLARE_API_TOKEN"
  value       = cloudflare_account_token.api[each.key].value
}
