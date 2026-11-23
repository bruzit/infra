output "r2" {
  value = {
    for k, t in cloudflare_account_token.r2 : k => {
      access_key_id     = t.id
      secret_access_key = sha256(t.value)
    }
  }
  sensitive = true
}

output "api_tokens" {
  value     = { for k, t in cloudflare_account_token.api : k => t.value }
  sensitive = true
}
