# bgp-prefsource

This configuration extends the [bgp-extended-nexthop](../bgp-extended-nexthop/) test by
demonstrating how to set the preferred source address for routes installed in the kernel
routing table.

By applying route-maps and filters, it enforces the use of specific loopback addresses
as the source for BGP routes, ensuring the BGP speaker uses the correct address when
communicating with other hosts in the network.
