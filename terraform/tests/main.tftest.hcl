mock_provider "hcloud" {
  mock_resource "hcloud_firewall" {
    defaults = {
      id = "1"
    }
  }
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
    condition     = hcloud_server.cloud0.firewall_ids == toset([1])
    error_message = "Server must have the firewall attached."
  }

  assert {
    condition     = length(hcloud_ssh_key.github) == 2 && length(hcloud_server.cloud0.ssh_keys) == 2
    error_message = "Server must have every GitHub key."
  }

  assert {
    condition     = yamldecode(trimprefix(hcloud_server.cloud0.user_data, "#cloud-config\n")).users[0].ssh_authorized_keys == ["ssh-ed25519 AAAAone", "ssh-ed25519 AAAAtwo"]
    error_message = "User mb must have every GitHub key."
  }
}

run "firewall" {
  command = plan

  assert {
    condition     = toset([for rule in hcloud_firewall.cloud0.rule : "${rule.direction}/${rule.protocol}/${coalesce(rule.port, "-")}"]) == toset(["in/tcp/22", "in/icmp/-"])
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
