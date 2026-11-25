variable "servers" {
  description = "Cloud servers by name."
  type = map(object({
    server_type = string
    location    = string
    image       = string
  }))
}

variable "zones" {
  description = "DNS zones by name; record sets by \"<name> <type>\", each a list of values."
  type        = map(map(list(string)))
}
