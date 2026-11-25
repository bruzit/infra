servers = {}

zones = {
  "bruzit.com" = {
    "@ MX"       = ["0 ."]
    "@ TXT"      = ["\"v=spf1 -all\""]
    "_dmarc TXT" = ["\"v=DMARC1; p=reject\""]
  }
  "bruzina.cz" = {
    "@ A"                              = ["168.119.167.224"]
    "@ AAAA"                           = ["2a01:4f8:c2c:d68f::1"]
    "@ MX"                             = ["1 wes1-mx1.wedos.net.", "1 wes1-mx2.wedos.net.", "10 wes1-mx-backup.wedos.net."]
    "@ TXT"                            = ["\"v=spf1 mx a include:_spf.we.wedos.net -all\""]
    "_dmarc TXT"                       = ["\"v=DMARC1; p=none; rua=mailto:martin@bruzina.cz\""]
    "martin CNAME"                     = ["martin-bruzina-cz.pages.dev."]
    "ftp CNAME"                        = ["174451.w51.wedos.net."]
    "imap CNAME"                       = ["wes1-imap.wedos.net."]
    "pop3 CNAME"                       = ["wes1-imap.wedos.net."]
    "smtp CNAME"                       = ["wes1-smtp.wedos.net."]
    "key1.wedos-dkim._domainkey CNAME" = ["key1.dkim-we.wedos.net."]
    "key2.wedos-dkim._domainkey CNAME" = ["key2.dkim-we.wedos.net."]
  }
}
