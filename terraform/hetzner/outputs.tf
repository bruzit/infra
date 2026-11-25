output "ipv4_address" {
  value     = { for name, server in hcloud_server.cloud : name => server.ipv4_address }
  sensitive = true
}

output "nameservers" {
  value = { for name, zone in hcloud_zone.zone : name => zone.authoritative_nameservers.assigned }
}
