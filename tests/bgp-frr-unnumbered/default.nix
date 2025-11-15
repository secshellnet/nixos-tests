{ ... }:
{
  name = "frr-bgp-unnumbered";

  defaults = {
    networking = {
      useDHCP = false;
      firewall.allowedTCPPorts = [ 179 ];
    };
    services.frr.bgpd.enable = true;
  };

  nodes = {
    a = {
      services.frr.config = ''
        router bgp 65001
          no bgp ebgp-requires-policy
          no bgp default ipv4-unicast
          bgp router-id 192.0.2.10

          neighbor fabric peer-group
          neighbor fabric remote-as external
          neighbor fabric capability extended-nexthop
          neighbor eth1 interface peer-group fabric

          address-family ipv4 unicast
            neighbor fabric activate
          exit-address-family

          address-family ipv6 unicast
            neighbor fabric activate
          exit-address-family
      '';
    };
    b = {
      services.frr.config = ''
        router bgp 65002
          no bgp ebgp-requires-policy
          no bgp default ipv4-unicast
          bgp router-id 192.0.2.11

          neighbor fabric peer-group
          neighbor fabric remote-as external
          neighbor fabric capability extended-nexthop
          neighbor eth1 interface peer-group fabric

          address-family ipv4 unicast
            neighbor fabric activate
          exit-address-family

          address-family ipv6 unicast
            neighbor fabric activate
          exit-address-family
      '';
    };
  };

  testScript = ''
    start_all()

    for m in [a, b]:
      m.wait_for_unit("network.target")
      m.wait_for_unit("frr.service")

    a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep 'eth1.*0\\s*0\\s*N/A'")
    b.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep 'eth1.*0\\s*0\\s*N/A'")

    # IPv6 DAD might need some time to complete for the local link address
    a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep 'eth1.*0\\s*0\\s*N/A'")
    b.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep 'eth1.*0\\s*0\\s*N/A'")
  '';
}
