resource "cloudflare_pages_project" "martin_bruzina_cz" {
  account_id        = var.account_id
  name              = "martin-bruzina-cz"
  production_branch = "main"
}
