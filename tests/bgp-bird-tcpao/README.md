# bird-bgp-tcpap

This test sets up two nodes running BIRD, establishing BGP sessions secured
with the TCP Authentication Option (TCP-AO). TCP-AO provides a cryptographic
authentication layer for BGP’s TCP connections, safeguarding against spoofing,
session hijacking, and unauthorized route injections. By using TCP-AO with
HMAC-SHA256 keys, the test ensures that only trusted peers can form BGP sessions,
thereby improving the security and integrity of routing information exchange.

Note that TCP-AO requires a non-default kernel option; consequently, this test
rebuilds the kernel with the necessary TCP_AO support enabled.
