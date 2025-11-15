# bgp-simple

This configuration sets up a simple BGP test environment with two nodes.

Node a runs FRRouting (FRR) as a BGP speaker with IPv4 and IPv6 addresses on interface
eth1, while node b runs the BIRD routing daemon configured similarly. Both nodes establish
BGP peering over IPv4 and IPv6 with each other.
