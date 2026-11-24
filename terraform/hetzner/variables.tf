variable "servers" {
  description = "Cloud servers by name."
  type = map(object({
    server_type = string
    location    = string
    image       = string
  }))
}
