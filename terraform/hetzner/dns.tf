locals {
  rrsets = merge([
    for zone, sets in var.zones : {
      for key, values in sets : "${zone} ${key}" => {
        zone    = zone
        name    = split(" ", key)[0]
        type    = split(" ", key)[1]
        records = values
      }
    }
  ]...)
}

resource "hcloud_zone" "zone" {
  for_each = var.zones

  name              = each.key
  mode              = "primary"
  delete_protection = true
}

resource "hcloud_zone_rrset" "rrset" {
  for_each = local.rrsets

  zone    = hcloud_zone.zone[each.value.zone].name
  name    = each.value.name
  type    = each.value.type
  records = [for value in each.value.records : { value = value }]
}
