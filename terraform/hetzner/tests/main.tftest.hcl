mock_provider "hcloud" {
  mock_resource "hcloud_firewall" {
    defaults = {
      id = "1"
    }
  }
}

variables {
  servers = {
    cloud0 = {
      server_type = "cx23"
      location    = "hel1"
      image       = "ubuntu-26.04"
    }
  }
  zones = {}
}

mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "ssh-ed25519 AAAAone\nssh-ed25519 AAAAtwo\n"
    }
  }
}

run "server" {
  assert {
    condition     = hcloud_server.cloud["cloud0"].firewall_ids == toset([1])
    error_message = "Server must have the firewall attached."
  }

  assert {
    condition     = length(hcloud_ssh_key.github) == 2 && length(hcloud_server.cloud["cloud0"].ssh_keys) == 2
    error_message = "Server must have every GitHub key."
  }

  assert {
    condition     = yamldecode(trimprefix(hcloud_server.cloud["cloud0"].user_data, "#cloud-config\n")).users[0].ssh_authorized_keys == ["ssh-ed25519 AAAAone", "ssh-ed25519 AAAAtwo"]
    error_message = "User mb must have every GitHub key."
  }

  assert {
    condition     = hcloud_server.cloud["cloud0"].labels == tomap({ role = "cloud", env = terraform.workspace })
    error_message = "Server must be labeled with role cloud and its workspace for the hcloud inventory groups."
  }
}

run "firewall" {
  command = plan

  assert {
    condition     = toset([for rule in hcloud_firewall.cloud["cloud0"].rule : "${rule.direction}/${rule.protocol}/${coalesce(rule.port, "-")}"]) == toset(["in/tcp/22", "in/icmp/-"])
    error_message = "Firewall must allow only 22/tcp and ICMP inbound."
  }
}

run "no_keys" {
  command = plan

  override_data {
    target = data.http.github_keys
    values = {
      status_code   = 200
      response_body = "\n"
    }
  }

  expect_failures = [data.http.github_keys]
}

run "prod" {
  command = plan

  variables {
    servers = {}
    zones = {
      "bruzit.com" = {
        "@ MX"       = ["0 ."]
        "@ TXT"      = ["\"v=spf1 -all\""]
        "_dmarc TXT" = ["\"v=DMARC1; p=reject\""]
      }
    }
  }

  assert {
    condition     = length(hcloud_server.cloud) == 0 && length(hcloud_firewall.cloud) == 0 && length(hcloud_ssh_key.github) == 0
    error_message = "prod has no servers, so no firewalls or SSH keys."
  }

  assert {
    condition     = hcloud_zone.zone["bruzit.com"].mode == "primary" && hcloud_zone.zone["bruzit.com"].delete_protection
    error_message = "Zones are primary and delete-protected."
  }

  assert {
    condition     = [for r in hcloud_zone_rrset.rrset["bruzit.com @ MX"].records : r.value] == ["0 ."] && hcloud_zone_rrset.rrset["bruzit.com _dmarc TXT"].name == "_dmarc"
    error_message = "Record sets are keyed by \"<name> <type>\" with their values."
  }
}
