# frr-bgp-unnumbered

This configuration extends the [bgp-extended-nexthop](../bgp-extended-nexthop/) test by
introducing BGP unnumbered support, which removes the need to explicitly specify an IPv6 link-local address.

**Note:**
BGP unnumbered is not currently standardized by any RFC, so behavior and implementation may vary across
platforms; additionally, the BIRD routing daemon does not support BGP unnumbered interfaces at this time.

In BGP unnumbered, neighbors use IPv6 link-local addresses that are automatically configured via IPv6
Router Advertisements based on interface identifiers, eliminating the need to manually specify addresses.

Because sessions rely on dynamic link-local addresses rather than explicit IPs, traditional IP-based security
measures like access lists may not be effective, exposing the session to risks if the link is compromised.

Unlike some other vendors, FRR currently does not support features like allowas-in for additional session
filtering, so it is recommended to use extra protections such as TTL-Security and TCP MD5 or, hopefully
in the future, TCP-AO.
