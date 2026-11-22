output "ipv4_address" {
  value     = hcloud_server.cloud0.ipv4_address
  sensitive = true
}
