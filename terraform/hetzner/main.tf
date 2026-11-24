data "http" "github_keys" {
  url = "https://github.com/bruzina.keys"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && length(compact(split("\n", self.response_body))) > 0
      error_message = "No SSH keys fetched from GitHub."
    }
  }
}

locals {
  ssh_keys = [for key in split("\n", data.http.github_keys.response_body) : trimspace(key) if trimspace(key) != ""]
  anywhere = ["0.0.0.0/0", "::/0"]
}

resource "hcloud_ssh_key" "github" {
  for_each = length(var.servers) > 0 ? toset(local.ssh_keys) : toset([])

  name       = "github-${substr(sha256(each.key), 0, 8)}"
  public_key = each.key
}

resource "hcloud_firewall" "cloud" {
  for_each = var.servers

  name = each.key

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = local.anywhere
  }

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = local.anywhere
  }
}

resource "hcloud_server" "cloud" {
  for_each = var.servers

  name         = each.key
  server_type  = each.value.server_type
  location     = each.value.location
  image        = each.value.image
  ssh_keys     = [for key in hcloud_ssh_key.github : key.id]
  firewall_ids = [hcloud_firewall.cloud[each.key].id]
  labels       = { role = "cloud", env = terraform.workspace }

  user_data = "#cloud-config\n${yamlencode({
    disable_root = true
    ssh_pwauth   = false
    users = [{
      name                = "mb"
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      ssh_authorized_keys = local.ssh_keys
    }]
  })}"
}

moved {
  from = hcloud_firewall.cloud0
  to   = hcloud_firewall.cloud["cloud0"]
}

moved {
  from = hcloud_server.cloud0
  to   = hcloud_server.cloud["cloud0"]
}
