let
  name = "downstream1";
in
{
  virtualisation.interfaces.eth3 = {
    vlan = 3;
    assignIP = false;
  };

  networking = {
    iproute2 = {
      rttablesExtraConfig = ''
        20 ${name}
      '';
    };
    ifstate.settings.interfaces = {
      eth3 = {
        addresses = [
          "fe80::1/64"
        ];
        link = {
          state = "up";
          kind = "physical";
          master = name;
        };
      };
      "${name}" = {
        link = {
          state = "up";
          kind = "vrf";
          vrf_table = name;
        };
      };
    };
  };

  services.frr.config = ''
    ip prefix-list downstream1 seq 20 permit 198.51.100.0/24
    ipv6 prefix-list downstream1-6 seq 20 permit 2001:db8:beef::/48

    ! remove e.g. </24 prefixes from announcements to downstream
    ! in reality we would also add stuff like rfc1918 networks here
    ip prefix-list too-small seq 10 permit 0.0.0.0/0 ge 25
    route-map downstream-out deny 10
      match ip address prefix-list too-small
    exit
    route-map downstream-out permit 100
    exit

    router bgp 65550 vrf ${name}
      no bgp ebgp-requires-policy
      no bgp default ipv4-unicast
      bgp router-id 192.0.2.1

      neighbor fe80::2 remote-as 65536
      neighbor fe80::2 capability extended-nexthop
      neighbor fe80::2 interface eth3

      address-family ipv4 unicast
        neighbor fe80::2 activate
        neighbor fe80::2 soft-reconfiguration inbound
        neighbor fe80::2 prefix-list downstream1 in
        neighbor fe80::2 route-map downstream-out out

        rd vpn export 65550:20
        rt vpn export 65550:1020
        rt vpn import 65550:1020 65550:1010

        export vpn
        import vpn
      exit-address-family

      ! ipv4 example shows how to work with full table, this shows do
      address-family ipv6 unicast
        neighbor fe80::2 activate
        neighbor fe80::2 soft-reconfiguration inbound
        neighbor fe80::2 default-originate
        neighbor fe80::2 prefix-list downstream1-6 in

        rd vpn export 65550:20
        rt vpn both 65550:1020

        export vpn
        import vpn
      exit-address-family
    exit
  '';
}
