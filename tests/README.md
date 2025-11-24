# Software Components

| Test Name                                 | Tested Software Components |
|-------------------------------------------|----------------------------|
| bgp-bird-tcpao                            | BIRD3                      | <!-- Add FRR when TCP-AO is supported -->
| bgp-extended-nexthop                      | FRR, BIRD3                 |
| bgp-frr-unnumbered                        | FRR                        | <!-- Add BIRD when unnumbered peerings are supported -->
| bgp-md5                                   | FRR, BIRD3                 |
| bgp-prefsource                            | FRR, BIRD3                 |
| bgp-simple                                | FRR, BIRD3                 |
| bgp-ttl-security                          | FRR, BIRD3                 |
| dhcpv4                                    | Kea DHCP Server, dhclient  | <!-- Extend by NetworkManager/systemd-networkd clients -->
| dns-knot                                  | Knot DNS Server            |
| dns-knot-dnssec                           | Knot DNS Server            |
| dns-knot-xfr                              | Knot DNS Server            |
| dns-knot-xfr-dnssec                       | Knot DNS Server            |
| dns-knot-xfr-tsig                         | Knot DNS Server            |
| dns-knot-xfr-tsig-explicit-notify         | Knot DNS Server            |
| nat64-dns64                               | Jool, BIND9                |
| ospf-ptp                                  | FRR, BIRD3                 |
| ping6-local-link                          |                            |
