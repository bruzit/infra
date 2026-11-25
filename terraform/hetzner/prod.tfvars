servers = {}

zones = {
  "bruzit.com" = {
    "@ MX"       = ["0 ."]
    "@ TXT"      = ["\"v=spf1 -all\""]
    "_dmarc TXT" = ["\"v=DMARC1; p=reject\""]
  }
}
