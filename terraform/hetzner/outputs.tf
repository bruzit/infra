output "ipv4_address" {
  value     = { for name, server in hcloud_server.cloud : name => server.ipv4_address }
  sensitive = true
}
