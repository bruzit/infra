resource "cloudflare_pages_project" "martin_bruzina_cz" {
  account_id        = var.account_id
  name              = "martin-bruzina-cz"
  production_branch = "main"
}

resource "cloudflare_pages_domain" "martin_bruzina_cz" {
  account_id   = var.account_id
  project_name = cloudflare_pages_project.martin_bruzina_cz.name
  name         = "martin.bruzina.cz"
}
