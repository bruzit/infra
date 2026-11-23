terraform {
  required_version = "~> 1.15"

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

data "cloudflare_account_api_token_permission_groups_list" "all" {
  account_id = var.account_id
}

output "ids" {
  description = "Permission group IDs by name."
  value       = { for g in data.cloudflare_account_api_token_permission_groups_list.all.result : g.name => g.id... }
}
